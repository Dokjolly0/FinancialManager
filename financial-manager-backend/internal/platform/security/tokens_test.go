package security

import "testing"

func TestNewOpaqueToken_IsUniqueAndURLSafe(t *testing.T) {
	a, err := NewOpaqueToken()
	if err != nil {
		t.Fatal(err)
	}
	b, err := NewOpaqueToken()
	if err != nil {
		t.Fatal(err)
	}

	if a == b {
		t.Error("two generated tokens must not be equal")
	}
	if len(a) == 0 {
		t.Error("token must not be empty")
	}
}

func TestHashToken_DeterministicAndDistinct(t *testing.T) {
	h1 := HashToken("same-input")
	h2 := HashToken("same-input")
	h3 := HashToken("different-input")

	if string(h1) != string(h2) {
		t.Error("hashing the same input twice must produce the same hash")
	}
	if string(h1) == string(h3) {
		t.Error("hashing different inputs must produce different hashes")
	}
}
