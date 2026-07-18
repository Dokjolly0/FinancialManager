package passwordhash

import "testing"

func TestHashAndVerify_RoundTrip(t *testing.T) {
	hash, err := Hash("correct horse battery staple")
	if err != nil {
		t.Fatalf("Hash() error = %v", err)
	}

	ok, err := Verify(hash, "correct horse battery staple")
	if err != nil {
		t.Fatalf("Verify() error = %v", err)
	}
	if !ok {
		t.Error("Verify() = false, want true for the correct password")
	}
}

func TestVerify_WrongPassword(t *testing.T) {
	hash, err := Hash("correct horse battery staple")
	if err != nil {
		t.Fatalf("Hash() error = %v", err)
	}

	ok, err := Verify(hash, "wrong password")
	if err != nil {
		t.Fatalf("Verify() error = %v", err)
	}
	if ok {
		t.Error("Verify() = true, want false for an incorrect password")
	}
}

func TestHash_SaltIsRandomized(t *testing.T) {
	a, err := Hash("same password")
	if err != nil {
		t.Fatal(err)
	}
	b, err := Hash("same password")
	if err != nil {
		t.Fatal(err)
	}

	if a == b {
		t.Error("two hashes of the same password must differ (random salt)")
	}
}

func TestVerify_RejectsUnrecognizedFormat(t *testing.T) {
	_, err := Verify("not-a-real-hash", "anything")
	if err == nil {
		t.Error("expected an error for an unrecognized hash format")
	}
}
