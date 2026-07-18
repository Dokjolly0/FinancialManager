package transactions

import "testing"

func TestValidateTransactionFields_AcceptsValidInput(t *testing.T) {
	if errs := validateTransactionFields(DirectionDebit, 1000, "Bar Centrale"); len(errs) != 0 {
		t.Errorf("expected no field errors, got %v", errs)
	}
}

func TestValidateTransactionFields_RejectsInvalidDirection(t *testing.T) {
	errs := validateTransactionFields("SIDEWAYS", 1000, "Title")
	if _, ok := errs["direction"]; !ok {
		t.Error("expected a direction field error")
	}
}

func TestValidateTransactionFields_RejectsNonPositiveAmount(t *testing.T) {
	errs := validateTransactionFields(DirectionCredit, 0, "Title")
	if _, ok := errs["amount_minor"]; !ok {
		t.Error("expected an amount_minor field error for zero amount")
	}
}

func TestValidateTransactionFields_RejectsImplausibleAmount(t *testing.T) {
	errs := validateTransactionFields(DirectionCredit, maxAmountMinor+1, "Title")
	if _, ok := errs["amount_minor"]; !ok {
		t.Error("expected an amount_minor field error for an implausible amount")
	}
}

func TestValidateTransactionFields_RejectsEmptyTitle(t *testing.T) {
	errs := validateTransactionFields(DirectionCredit, 1000, "   ")
	if _, ok := errs["title"]; !ok {
		t.Error("expected a title field error for blank title")
	}
}
