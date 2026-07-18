package templates

import "testing"

func TestNormalizeTitle_TrimsAndCompactsSpaces(t *testing.T) {
	if got := NormalizeTitle("  Bar   Centrale  "); got != "bar centrale" {
		t.Errorf("NormalizeTitle() = %q, want %q", got, "bar centrale")
	}
}

func TestValidateFields_RejectsInvalidDirectionAndBlankTitle(t *testing.T) {
	errs := validateFields("SIDEWAYS", "   ")
	if _, ok := errs["direction"]; !ok {
		t.Error("expected a direction field error")
	}
	if _, ok := errs["title"]; !ok {
		t.Error("expected a title field error for blank title")
	}
}

func TestValidateFields_AcceptsValidInput(t *testing.T) {
	if errs := validateFields("DEBIT", "Bar Centrale"); len(errs) != 0 {
		t.Errorf("expected no field errors, got %v", errs)
	}
}
