// Package security provides opaque token generation/hashing (refresh
// tokens, email verification, password reset — plan.md sections 11.5,
// 15.5, 15.6) and access-token JWTs. Every long-lived secret token is
// stored only as a hash, never in plaintext (plan.md section 11.5: "Non
// salvare refresh token in chiaro").
package security

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
)

// NewOpaqueToken returns a URL-safe random token with ~256 bits of entropy,
// suitable for refresh tokens, email verification links, and password
// reset links.
func NewOpaqueToken() (string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(buf), nil
}

// HashToken returns the SHA-256 hash of a raw token, for storage/lookup.
// SHA-256 (not a slow KDF) is appropriate here: unlike passwords, these
// tokens already have high entropy and are single-use/short-lived.
func HashToken(raw string) []byte {
	sum := sha256.Sum256([]byte(raw))
	return sum[:]
}
