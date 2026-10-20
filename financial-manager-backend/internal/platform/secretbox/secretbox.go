// Package secretbox encrypts small secrets stored in the database, such as
// the users' AI provider API keys (plan.md section 32.2), with AES-256-GCM.
//
// It is deliberately separate from internal/backup's encryption, which is
// unauthenticated AES-CBC with a per-call PBKDF2 to stay compatible with
// the openssl file format: fine for backup files, wrong for secrets at
// rest, where tampering must be detected and a ciphertext must not be
// movable to another row.
//
// A sealed value is one self-describing blob:
//
//	version (1 byte) | key ID (4 bytes) | nonce (12 bytes) | ciphertext+tag
//
// The key ID is the first 4 bytes of SHA-256(key), so Open can pick the
// right key after a rotation without a separate column.
package secretbox

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
)

// KeySize is the required key length in bytes (AES-256).
const KeySize = 32

const (
	formatVersion = 1
	keyIDSize     = 4
	nonceSize     = 12
	headerSize    = 1 + keyIDSize + nonceSize
)

// ErrOpen is returned for every failure to decrypt: unknown key, wrong
// additional data, truncated or tampered blob. The causes are not told
// apart on purpose.
var ErrOpen = errors.New("secretbox: cannot open sealed value")

type keyEntry struct {
	id   [keyIDSize]byte
	aead cipher.AEAD
}

// Box seals with the current key and opens with the current or any
// previous key.
type Box struct {
	current  keyEntry
	previous []keyEntry
}

// ParseKey decodes a standard base64 key (as printed by
// `openssl rand -base64 32`) and checks its length.
func ParseKey(encoded string) ([]byte, error) {
	key, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return nil, fmt.Errorf("key is not valid base64: %w", err)
	}
	if len(key) != KeySize {
		return nil, fmt.Errorf("key must decode to %d bytes, got %d", KeySize, len(key))
	}
	return key, nil
}

// New builds a Box. previous keys are only used to open values sealed
// before a rotation.
func New(current []byte, previous ...[]byte) (*Box, error) {
	cur, err := newKeyEntry(current)
	if err != nil {
		return nil, err
	}
	b := &Box{current: cur}
	for _, k := range previous {
		entry, err := newKeyEntry(k)
		if err != nil {
			return nil, fmt.Errorf("previous key: %w", err)
		}
		b.previous = append(b.previous, entry)
	}
	return b, nil
}

func newKeyEntry(key []byte) (keyEntry, error) {
	if len(key) != KeySize {
		return keyEntry{}, fmt.Errorf("secretbox: key must be %d bytes, got %d", KeySize, len(key))
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return keyEntry{}, fmt.Errorf("secretbox: %w", err)
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		return keyEntry{}, fmt.Errorf("secretbox: %w", err)
	}
	sum := sha256.Sum256(key)
	var id [keyIDSize]byte
	copy(id[:], sum[:keyIDSize])
	return keyEntry{id: id, aead: aead}, nil
}

// Seal encrypts plaintext bound to additionalData: Open must be given the
// same additionalData (e.g. the owning user and provider) or it fails.
func (b *Box) Seal(plaintext, additionalData []byte) ([]byte, error) {
	out := make([]byte, headerSize, headerSize+len(plaintext)+b.current.aead.Overhead())
	out[0] = formatVersion
	copy(out[1:1+keyIDSize], b.current.id[:])
	nonce := out[1+keyIDSize : headerSize]
	if _, err := rand.Read(nonce); err != nil {
		return nil, fmt.Errorf("secretbox: read nonce: %w", err)
	}
	return b.current.aead.Seal(out, nonce, plaintext, additionalData), nil
}

// Open decrypts a value produced by Seal with the current or a previous key.
func (b *Box) Open(sealed, additionalData []byte) ([]byte, error) {
	entry, ok := b.entryFor(sealed)
	if !ok {
		return nil, ErrOpen
	}
	nonce := sealed[1+keyIDSize : headerSize]
	plaintext, err := entry.aead.Open(nil, nonce, sealed[headerSize:], additionalData)
	if err != nil {
		return nil, ErrOpen
	}
	return plaintext, nil
}

// NeedsRotation reports whether a sealed value was produced with a key
// other than the current one, so the caller can re-seal it.
func (b *Box) NeedsRotation(sealed []byte) bool {
	return len(sealed) < headerSize || !bytes.Equal(sealed[1:1+keyIDSize], b.current.id[:])
}

func (b *Box) entryFor(sealed []byte) (keyEntry, bool) {
	if len(sealed) < headerSize+b.current.aead.Overhead() || sealed[0] != formatVersion {
		return keyEntry{}, false
	}
	id := sealed[1 : 1+keyIDSize]
	if bytes.Equal(id, b.current.id[:]) {
		return b.current, true
	}
	for _, p := range b.previous {
		if bytes.Equal(id, p.id[:]) {
			return p, true
		}
	}
	return keyEntry{}, false
}
