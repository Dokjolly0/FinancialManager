package backup

import (
	"bytes"
	"crypto/rand"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func decrypt(t *testing.T, data []byte, passphrase string) []byte {
	t.Helper()
	var out bytes.Buffer
	if err := Decrypt(&out, bytes.NewReader(data), passphrase); err != nil {
		t.Fatal(err)
	}
	return out.Bytes()
}

func randomBytes(t *testing.T, n int) []byte {
	t.Helper()
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		t.Fatal(err)
	}
	return b
}

func encrypt(t *testing.T, plain []byte, passphrase string) []byte {
	t.Helper()
	var out bytes.Buffer
	if err := Encrypt(&out, bytes.NewReader(plain), passphrase); err != nil {
		t.Fatal(err)
	}
	return out.Bytes()
}

func TestEncrypt_RoundTrip(t *testing.T) {
	// Sizes straddle the block size and both functions' read buffers
	// (64 KiB for Encrypt, 64 KiB + one block for Decrypt).
	for _, size := range []int{
		0, 1, 15, 16, 17,
		64*1024 - 1, 64 * 1024, 64*1024 + 1, 64*1024 + 15, 64*1024 + 16, 64*1024 + 17,
		2 * (64*1024 + 16), 200_000,
	} {
		plain := randomBytes(t, size)
		if got := decrypt(t, encrypt(t, plain, "correct horse"), "correct horse"); !bytes.Equal(got, plain) {
			t.Fatalf("size %d: round trip mismatch", size)
		}
	}
}

func TestEncrypt_UsesFreshSalt(t *testing.T) {
	a := encrypt(t, []byte("same input"), "k")
	b := encrypt(t, []byte("same input"), "k")
	if bytes.Equal(a, b) {
		t.Fatal("two encryptions of the same input produced identical output")
	}
}

func TestDecrypt_WrongKeyNeverYieldsPlaintext(t *testing.T) {
	plain := randomBytes(t, 1000)
	var out bytes.Buffer
	err := Decrypt(&out, bytes.NewReader(encrypt(t, plain, "right")), "wrong")
	// Usually ErrBadDecrypt; padding can match by chance (~1/256), but the
	// output is then garbage — never the original data.
	if err == nil && bytes.Equal(out.Bytes(), plain) {
		t.Fatal("wrong key decrypted to the original plaintext")
	}
	if err != nil && !errors.Is(err, ErrBadDecrypt) {
		t.Fatalf("err = %v, want ErrBadDecrypt", err)
	}
}

func TestDecrypt_RejectsMalformedInput(t *testing.T) {
	enc := encrypt(t, randomBytes(t, 100), "k")
	cases := map[string]struct {
		data []byte
		want error
	}{
		"plaintext":      {[]byte("PGDMP plain pg_dump output"), ErrNotEncrypted},
		"empty":          {nil, ErrNotEncrypted},
		"header only":    {enc[:16], ErrBadDecrypt},
		"truncated body": {enc[:len(enc)-1], ErrBadDecrypt},
	}
	for name, tc := range cases {
		err := Decrypt(&bytes.Buffer{}, bytes.NewReader(tc.data), "k")
		if !errors.Is(err, tc.want) {
			t.Errorf("%s: err = %v, want %v", name, err, tc.want)
		}
	}
}

func TestDecryptFile_RemovesOutputOnFailure(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "x.enc")
	dst := filepath.Join(dir, "x")
	if err := os.WriteFile(src, []byte("not encrypted"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := DecryptFile(dst, src, "k"); !errors.Is(err, ErrNotEncrypted) {
		t.Fatalf("err = %v, want ErrNotEncrypted", err)
	}
	if _, err := os.Stat(dst); !os.IsNotExist(err) {
		t.Fatal("DecryptFile left its output behind after failing")
	}
}

// TestOpenSSLCompatibility proves both directions: scripts/restore.sh
// (openssl) can decrypt what the job uploads, and Decrypt can read files
// encrypted by scripts/backup.sh (openssl). Skipped without openssl.
func TestOpenSSLCompatibility(t *testing.T) {
	opensslPath, err := exec.LookPath("openssl")
	if err != nil {
		t.Skip("openssl not in PATH")
	}
	const pass = "s3cret passphrase"
	dir := t.TempDir()
	plain := randomBytes(t, 100_003)
	src := filepath.Join(dir, "plain.bin")
	if err := os.WriteFile(src, plain, 0o600); err != nil {
		t.Fatal(err)
	}
	openssl := func(args ...string) {
		t.Helper()
		args = append([]string{"enc", "-aes-256-cbc", "-pbkdf2", "-pass", "pass:" + pass}, args...)
		if out, err := exec.Command(opensslPath, args...).CombinedOutput(); err != nil {
			t.Fatalf("openssl %v: %v\n%s", args, err, out)
		}
	}
	assertFile := func(path string) {
		t.Helper()
		got, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		if !bytes.Equal(got, plain) {
			t.Fatalf("%s differs from the original", filepath.Base(path))
		}
	}

	// Go encrypts, openssl decrypts.
	goEnc := filepath.Join(dir, "go.enc")
	if err := EncryptFile(goEnc, src, pass); err != nil {
		t.Fatal(err)
	}
	opensslDec := filepath.Join(dir, "openssl-decrypted.bin")
	openssl("-d", "-in", goEnc, "-out", opensslDec)
	assertFile(opensslDec)

	// openssl encrypts, Go decrypts.
	opensslEnc := filepath.Join(dir, "openssl.enc")
	openssl("-salt", "-in", src, "-out", opensslEnc)
	goDec := filepath.Join(dir, "go-decrypted.bin")
	if err := DecryptFile(goDec, opensslEnc, pass); err != nil {
		t.Fatal(err)
	}
	assertFile(goDec)
}
