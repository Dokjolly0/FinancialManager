package auth

import (
	"testing"

	"github.com/google/uuid"
)

func validRegisterInput() RegisterInput {
	return RegisterInput{
		FirstName:             "Mario",
		LastName:              "Rossi",
		Username:              "mariorossi",
		Email:                 "mario@example.com",
		Password:              "supersecret1",
		ConfirmPassword:       "supersecret1",
		AvatarBackgroundColor: "#176B5B",
		AvatarTextColor:       "#FFFFFF",
		InitialBalanceMinor:   50000,
		Currency:              "EUR",
		AcceptedTerms:         true,
		IdempotencyKey:        uuid.New(),
	}
}

func TestValidateRegisterInput_AcceptsValidInput(t *testing.T) {
	if errs := validateRegisterInput(validRegisterInput()); len(errs) != 0 {
		t.Errorf("expected no field errors, got %v", errs)
	}
}

func TestValidateRegisterInput_RejectsMismatchedPasswords(t *testing.T) {
	in := validRegisterInput()
	in.ConfirmPassword = "somethingelse"

	errs := validateRegisterInput(in)
	if _, ok := errs["confirm_password"]; !ok {
		t.Error("expected a confirm_password field error")
	}
}

func TestValidateRegisterInput_RejectsNegativeBalance(t *testing.T) {
	in := validRegisterInput()
	in.InitialBalanceMinor = -1

	errs := validateRegisterInput(in)
	if _, ok := errs["initial_balance_minor"]; !ok {
		t.Error("expected an initial_balance_minor field error")
	}
}

func TestValidateRegisterInput_RejectsNonEURCurrency(t *testing.T) {
	in := validRegisterInput()
	in.Currency = "USD"

	errs := validateRegisterInput(in)
	if _, ok := errs["currency"]; !ok {
		t.Error("expected a currency field error")
	}
}

func TestValidateRegisterInput_RequiresAcceptedTerms(t *testing.T) {
	in := validRegisterInput()
	in.AcceptedTerms = false

	errs := validateRegisterInput(in)
	if _, ok := errs["accepted_terms"]; !ok {
		t.Error("expected an accepted_terms field error")
	}
}

func TestValidateRegisterInput_RequiresIdempotencyKey(t *testing.T) {
	in := validRegisterInput()
	in.IdempotencyKey = uuid.Nil

	errs := validateRegisterInput(in)
	if _, ok := errs["idempotency_key"]; !ok {
		t.Error("expected an idempotency_key field error")
	}
}

func TestValidateRegisterInput_RejectsShortPassword(t *testing.T) {
	in := validRegisterInput()
	in.Password = "short"
	in.ConfirmPassword = "short"

	errs := validateRegisterInput(in)
	if _, ok := errs["password"]; !ok {
		t.Error("expected a password field error")
	}
}
