package transactions

import "testing"

func TestSignedDelta(t *testing.T) {
	if got := SignedDelta(DirectionCredit, 1000); got != 1000 {
		t.Errorf("SignedDelta(CREDIT, 1000) = %d, want 1000", got)
	}
	if got := SignedDelta(DirectionDebit, 1000); got != -1000 {
		t.Errorf("SignedDelta(DEBIT, 1000) = %d, want -1000", got)
	}
}

func TestNormalizeTitle(t *testing.T) {
	cases := map[string]string{
		"  Bar   Centrale ": "bar centrale",
		"CAFFÈ ROMA":        "caffè roma",
	}
	for input, want := range cases {
		if got := NormalizeTitle(input); got != want {
			t.Errorf("NormalizeTitle(%q) = %q, want %q", input, got, want)
		}
	}
}
