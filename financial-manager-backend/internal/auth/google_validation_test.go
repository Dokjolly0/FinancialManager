package auth

import "testing"

func validGoogleCompletionInput() CompleteGoogleRegistrationInput {
	return CompleteGoogleRegistrationInput{
		Ticket:                "some-ticket",
		Username:              "mariorossi",
		AvatarBackgroundColor: "#176B5B",
		AvatarTextColor:       "#FFFFFF",
		InitialBalanceMinor:   0,
		Currency:              "EUR",
		AcceptedTerms:         true,
	}
}

func TestValidateGoogleCompletionInput_AcceptsValidInputWithoutPassword(t *testing.T) {
	if errs := validateGoogleCompletionInput(validGoogleCompletionInput()); len(errs) != 0 {
		t.Errorf("expected no field errors, got %v", errs)
	}
}

func TestValidateGoogleCompletionInput_PasswordOptionalButValidatedIfPresent(t *testing.T) {
	in := validGoogleCompletionInput()
	in.Password = "short"
	in.ConfirmPassword = "short"

	errs := validateGoogleCompletionInput(in)
	if _, ok := errs["password"]; !ok {
		t.Error("expected a password field error for a too-short password")
	}
}

func TestValidateGoogleCompletionInput_RequiresTicket(t *testing.T) {
	in := validGoogleCompletionInput()
	in.Ticket = ""

	errs := validateGoogleCompletionInput(in)
	if _, ok := errs["ticket"]; !ok {
		t.Error("expected a ticket field error")
	}
}

func TestValidateGoogleCompletionInput_RequiresAcceptedTerms(t *testing.T) {
	in := validGoogleCompletionInput()
	in.AcceptedTerms = false

	errs := validateGoogleCompletionInput(in)
	if _, ok := errs["accepted_terms"]; !ok {
		t.Error("expected an accepted_terms field error")
	}
}
