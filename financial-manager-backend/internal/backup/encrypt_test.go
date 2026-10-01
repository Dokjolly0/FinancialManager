package backup

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

// decrypt is the inverse of Encrypt, kept test-only: restores go through
// openssl (scripts/restore.sh), never through the Go code.
func decrypt(t *testing.T, data []byte, passphrase string) []byte {
	t.Helper()
	if !bytes.HasPrefix(data, []byte(opensslMagic)) {
		t.Fatal("missing Salted__ header")
	}
	salt := data[len(opensslMagic) : len(opensslMagic)+opensslSaltLen]
	body := append([]byte(nil), data[len(opensslMagic)+opensslSaltLen:]...)
	if len(body) == 0 || len(body)%aes.BlockSize != 0 {
		t.Fatalf("ciphertext length %d is not a positive multiple of the block size", len(body))
	}
	key, iv, err := deriveKeyIV(passphrase, salt)
	if err != nil {
		t.Fatal(err)
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		t.Fatal(err)
	}
	cipher.NewCBCDecrypter(block, iv).CryptBlocks(body, body)
	padLen := int(body[len(body)-1])
	if padLen < 1 || padLen > aes.BlockSize {
		t.Fatalf("invalid padding %d", padLen)
	}
	return body[:len(body)-padLen]
}

func randomBytes(t *testing.T, n int) []byte {
	t.Helper()
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		t.Fatal(err)
	}
	return b
}

func TestEncrypt_RoundTrip(t *testing.T) {
	// Sizes straddle the block size and the internal 64 KiB read buffer.
	for _, size := range []int{0, 1, 15, 16, 17, 64*1024 - 1, 64 * 1024, 64*1024 + 1, 200_000} {
		plain := randomBytes(t, size)
		var out bytes.Buffer
		if err := Encrypt(&out, bytes.NewReader(plain), "correct horse"); err != nil {
			t.Fatalf("size %d: %v", size, err)
		}
		if got := decrypt(t, out.Bytes(), "correct horse"); !bytes.Equal(got, plain) {
			t.Fatalf("size %d: round trip mismatch", size)
		}
	}
}

func TestEncrypt_UsesFreshSalt(t *testing.T) {
	var a, b bytes.Buffer
	_ = Encrypt(&a, bytes.NewReader([]byte("same input")), "k")
	_ = Encrypt(&b, bytes.NewReader([]byte("same input")), "k")
	if bytes.Equal(a.Bytes(), b.Bytes()) {
		t.Fatal("two encryptions of the same input produced identical output")
	}
}

// TestEncryptFile_OpenSSLCompatible proves scripts/restore.sh can decrypt
// what the job uploads. Skipped when openssl is not installed.
func TestEncryptFile_OpenSSLCompatible(t *testing.T) {
	opensslPath, err := exec.LookPath("openssl")
	if err != nil {
		t.Skip("openssl not in PATH")
	}
	dir := t.TempDir()
	plain := randomBytes(t, 100_003)
	src := filepath.Join(dir, "plain.bin")
	enc := filepath.Join(dir, "plain.bin.enc")
	dec := filepath.Join(dir, "decrypted.bin")
	if err := os.WriteFile(src, plain, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := EncryptFile(enc, src, "s3cret passphrase"); err != nil {
		t.Fatal(err)
	}

	cmd := exec.Command(opensslPath, "enc", "-d", "-aes-256-cbc", "-pbkdf2",
		"-pass", "pass:s3cret passphrase", "-in", enc, "-out", dec)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("openssl decrypt failed: %v\n%s", err, out)
	}
	got, err := os.ReadFile(dec)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(got, plain) {
		t.Fatal("openssl decrypted content differs from the original")
	}
}
