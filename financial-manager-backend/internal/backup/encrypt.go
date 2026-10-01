package backup

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/pbkdf2"
	"crypto/rand"
	"crypto/sha256"
	"fmt"
	"io"
	"os"
)

// The on-disk format is exactly what `openssl enc -aes-256-cbc -pbkdf2`
// produces (OpenSSL 1.1.1+ defaults: PBKDF2-HMAC-SHA256, 10000 iterations),
// so scripts/restore.sh — and a plain openssl call — can decrypt a file
// downloaded from Drive with the same BACKUP_ENCRYPTION_KEY used by
// scripts/backup.sh:
//
//	"Salted__" | 8-byte salt | AES-256-CBC(PKCS#7-padded plaintext)
//
// with key and IV both derived from the passphrase and salt.
const (
	opensslMagic      = "Salted__"
	opensslSaltLen    = 8
	opensslIterations = 10000
	opensslKeyLen     = 32
)

// encryptedExt is appended to every uploaded file name, matching the
// suffix scripts/restore.sh looks for.
const encryptedExt = ".enc"

func deriveKeyIV(passphrase string, salt []byte) (key, iv []byte, err error) {
	material, err := pbkdf2.Key(sha256.New, passphrase, salt, opensslIterations, opensslKeyLen+aes.BlockSize)
	if err != nil {
		return nil, nil, err
	}
	return material[:opensslKeyLen], material[opensslKeyLen:], nil
}

// Encrypt streams r into w in the OpenSSL-compatible format described above.
func Encrypt(w io.Writer, r io.Reader, passphrase string) error {
	salt := make([]byte, opensslSaltLen)
	if _, err := rand.Read(salt); err != nil {
		return fmt.Errorf("generate salt: %w", err)
	}
	key, iv, err := deriveKeyIV(passphrase, salt)
	if err != nil {
		return fmt.Errorf("derive key: %w", err)
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return err
	}
	mode := cipher.NewCBCEncrypter(block, iv)

	if _, err := w.Write(append([]byte(opensslMagic), salt...)); err != nil {
		return err
	}

	// buf always holds a whole number of blocks once encrypted; the
	// remainder (< one block) is carried over to the next read and padded
	// at EOF, so the padding block is never emitted mid-stream.
	buf := make([]byte, 64*1024)
	pending := 0
	for {
		n, readErr := io.ReadFull(r, buf[pending:])
		pending += n
		if readErr == io.EOF || readErr == io.ErrUnexpectedEOF {
			padLen := aes.BlockSize - pending%aes.BlockSize
			final := append(buf[:pending:pending], bytes.Repeat([]byte{byte(padLen)}, padLen)...)
			mode.CryptBlocks(final, final)
			_, err := w.Write(final)
			return err
		}
		if readErr != nil {
			return readErr
		}
		full := pending - pending%aes.BlockSize
		mode.CryptBlocks(buf[:full], buf[:full])
		if _, err := w.Write(buf[:full]); err != nil {
			return err
		}
		pending = copy(buf, buf[full:pending])
	}
}

// EncryptFile encrypts src into dst (created or truncated).
func EncryptFile(dst, src, passphrase string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	if err := Encrypt(out, in, passphrase); err != nil {
		_ = out.Close()
		return fmt.Errorf("encrypt %s: %w", src, err)
	}
	return out.Close()
}
