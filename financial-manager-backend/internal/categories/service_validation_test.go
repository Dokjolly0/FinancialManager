package categories

import "testing"

func TestNormalizeName_TrimsAndCompactsSpaces(t *testing.T) {
	if got := NormalizeName("  Ristorazione   Fast Food  "); got != "ristorazione fast food" {
		t.Errorf("NormalizeName() = %q, want %q", got, "ristorazione fast food")
	}
}

func TestIsValidScope(t *testing.T) {
	for _, valid := range []string{ScopeDebit, ScopeCredit, ScopeBoth} {
		if !IsValidScope(valid) {
			t.Errorf("IsValidScope(%q) = false, want true", valid)
		}
	}
	if IsValidScope("SIDEWAYS") {
		t.Error("IsValidScope(\"SIDEWAYS\") = true, want false")
	}
}

func TestCategory_Matches(t *testing.T) {
	debit := Category{DirectionScope: ScopeDebit}
	if !debit.Matches(ScopeDebit) {
		t.Error("DEBIT category should match DEBIT direction")
	}
	if debit.Matches(ScopeCredit) {
		t.Error("DEBIT category should not match CREDIT direction")
	}

	both := Category{DirectionScope: ScopeBoth}
	if !both.Matches(ScopeDebit) || !both.Matches(ScopeCredit) {
		t.Error("BOTH category should match either direction")
	}
}

func TestValidateFields_RejectsBlankNameAndInvalidScope(t *testing.T) {
	errs := validateFields("   ", "SIDEWAYS")
	if _, ok := errs["name"]; !ok {
		t.Error("expected a name field error for blank name")
	}
	if _, ok := errs["direction_scope"]; !ok {
		t.Error("expected a direction_scope field error for invalid scope")
	}
}

func TestValidateFields_AcceptsValidInput(t *testing.T) {
	if errs := validateFields("Bollette", ScopeDebit); len(errs) != 0 {
		t.Errorf("expected no field errors, got %v", errs)
	}
}
