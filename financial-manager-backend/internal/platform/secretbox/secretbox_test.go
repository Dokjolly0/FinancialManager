package secretbox

import (
	"bytes"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"testing"
)

func randomKey(t *testing.T) []byte {
	t.Helper()
	k := make([]byte, KeySize)
	if _, err := rand.Read(k); err != nil {
		t.Fatal(err)
	}
	return k
}

func TestSealOpen_RoundTrip(t *testing.T) {
	box, err := New(randomKey(t))
	if err != nil {
		t.Fatal(err)
	}
	aad := []byte("user-1|openai|")
	sealed, err := box.Seal([]byte("sk-secret"), aad)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(sealed, []byte("sk-secret")) {
		t.Fatal("sealed value contains the plaintext")
	}
	got, err := box.Open(sealed, aad)
	if err != nil {
		t.Fatalf("Open() error = %v", err)
	}
	if string(got) != "sk-secret" {
		t.Fatalf("Open() = %q", got)
	}
}

func TestSeal_UsesFreshNonces(t *testing.T) {
	box, _ := New(randomKey(t))
	a, _ := box.Seal([]byte("same"), nil)
	b, _ := box.Seal([]byte("same"), nil)
	if bytes.Equal(a, b) {
		t.Fatal("two seals of the same plaintext are identical")
	}
}

func TestOpen_Failures(t *testing.T) {
	box, _ := New(randomKey(t))
	other, _ := New(randomKey(t))
	aad := []byte("user-1|openai|")
	sealed, _ := box.Seal([]byte("sk-secret"), aad)

	tampered := append([]byte(nil), sealed...)
	tampered[len(tampered)-1] ^= 0x01

	badVersion := append([]byte(nil), sealed...)
	badVersion[0] = 99

	cases := map[string]struct {
		box    *Box
		sealed []byte
		aad    []byte
	}{
		"wrong additional data": {box, sealed, []byte("user-2|openai|")},
		"tampered ciphertext":   {box, tampered, aad},
		"unknown key":           {other, sealed, aad},
		"truncated":             {box, sealed[:10], aad},
		"empty":                 {box, nil, aad},
		"unknown format":        {box, badVersion, aad},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			if _, err := c.box.Open(c.sealed, c.aad); !errors.Is(err, ErrOpen) {
				t.Fatalf("Open() error = %v, want ErrOpen", err)
			}
		})
	}
}

func TestRotation(t *testing.T) {
	oldKey, newKey := randomKey(t), randomKey(t)
	oldBox, _ := New(oldKey)
	sealedOld, _ := oldBox.Seal([]byte("sk-old"), nil)

	rotated, err := New(newKey, oldKey)
	if err != nil {
		t.Fatal(err)
	}
	got, err := rotated.Open(sealedOld, nil)
	if err != nil || string(got) != "sk-old" {
		t.Fatalf("Open(old) = %q, %v", got, err)
	}
	if !rotated.NeedsRotation(sealedOld) {
		t.Fatal("value sealed with the previous key should need rotation")
	}
	sealedNew, _ := rotated.Seal([]byte("sk-old"), nil)
	if rotated.NeedsRotation(sealedNew) {
		t.Fatal("value sealed with the current key should not need rotation")
	}
}

func TestParseKey(t *testing.T) {
	good := base64.StdEncoding.EncodeToString(make([]byte, KeySize))
	if _, err := ParseKey(good); err != nil {
		t.Fatalf("ParseKey(valid) error = %v", err)
	}
	for name, in := range map[string]string{
		"not base64": "%%%",
		"too short":  base64.StdEncoding.EncodeToString(make([]byte, 16)),
		"too long":   base64.StdEncoding.EncodeToString(make([]byte, 48)),
	} {
		if _, err := ParseKey(in); err == nil {
			t.Errorf("ParseKey(%s) = nil error", name)
		}
	}
}
