package ai

import "testing"

func TestKeyHint(t *testing.T) {
	cases := map[string]string{
		"sk-proj-abcdefgh1234":  "sk-…1234",
		"AIzaSyA-0123456789xyz": "AIz…9xyz",
		"short1":                "…t1",
		"abc":                   "…",
	}
	for in, want := range cases {
		if got := keyHint(in); got != want {
			t.Errorf("keyHint(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestHasCurrentConsent(t *testing.T) {
	old, current := ConsentVersion-1, ConsentVersion
	if (Settings{}).HasCurrentConsent() {
		t.Error("no consent recorded")
	}
	if (Settings{ConsentVersion: &old}).HasCurrentConsent() {
		t.Error("an older consent version must be asked again")
	}
	if !(Settings{ConsentVersion: &current}).HasCurrentConsent() {
		t.Error("current consent not recognized")
	}
}
