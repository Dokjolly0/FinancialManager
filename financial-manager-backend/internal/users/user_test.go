package users

import "testing"

func TestNormalizeUsername(t *testing.T) {
	cases := map[string]string{
		"  Mario   Rossi  ": "mario rossi",
		"MarioRossi":        "mariorossi",
		"mario":             "mario",
	}
	for input, want := range cases {
		if got := NormalizeUsername(input); got != want {
			t.Errorf("NormalizeUsername(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestNormalizeEmail(t *testing.T) {
	if got := NormalizeEmail("  Mario.Rossi@Example.COM "); got != "mario.rossi@example.com" {
		t.Errorf("NormalizeEmail() = %q, want %q", got, "mario.rossi@example.com")
	}
}
