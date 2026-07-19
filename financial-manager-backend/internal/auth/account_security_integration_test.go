package auth_test

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/google/uuid"

	"financial-manager-backend/internal/auth"
)

const testUserPassword = "correct-horse-1"

// registerTestUser creates a fresh password-based account via the real
// Register flow (same harness/dev stack as google_integration_test.go) and
// returns its user ID and email — used both directly and to log in
// additional sessions.
func registerTestUser(t *testing.T, h testHarness) (userID uuid.UUID, email string) {
	t.Helper()

	email = "sara-" + uuid.NewString()[:8] + "@example.com"
	responseBody, status, err := h.service.Register(context.Background(), auth.RegisterInput{
		FirstName:             "Sara",
		LastName:              "Bianchi",
		Username:              "sarabianchi" + uuid.NewString()[:8],
		Email:                 email,
		Password:              testUserPassword,
		ConfirmPassword:       testUserPassword,
		AvatarBackgroundColor: "#336699",
		AvatarTextColor:       "#FFFFFF",
		InitialBalanceMinor:   0,
		Currency:              "EUR",
		Timezone:              "Europe/Rome",
		Locale:                "it-IT",
		AcceptedTerms:         true,
		IdempotencyKey:        uuid.New(),
		RequestBody:           []byte(`{}`),
	})
	if err != nil {
		t.Fatalf("Register() error = %v", err)
	}
	if status != 201 {
		t.Fatalf("Register() status = %d, want 201", status)
	}

	var decoded struct {
		User struct {
			ID string `json:"id"`
		} `json:"user"`
	}
	if err := json.Unmarshal(responseBody, &decoded); err != nil {
		t.Fatalf("decode register response: %v", err)
	}
	id, err := uuid.Parse(decoded.User.ID)
	if err != nil {
		t.Fatalf("parse user id: %v", err)
	}
	return id, email
}

func TestChangePassword_WrongCurrentPasswordIsRejected(t *testing.T) {
	h := newTestHarness(t)
	ctx := context.Background()
	userID, _ := registerTestUser(t, h)

	sessions, err := h.service.ListSessions(ctx, userID)
	if err != nil {
		t.Fatalf("ListSessions() error = %v", err)
	}
	if len(sessions) != 1 {
		t.Fatalf("got %d sessions after register, want 1", len(sessions))
	}

	err = h.service.ChangePassword(ctx, userID, sessions[0].ID, "totally-wrong", "brand-new-password")
	if err == nil {
		t.Fatal("expected an error for a wrong current password")
	}

	stillOnlyOne, err := h.service.ListSessions(ctx, userID)
	if err != nil {
		t.Fatalf("ListSessions() error = %v", err)
	}
	if len(stillOnlyOne) != 1 {
		t.Errorf("a rejected change must not revoke any session; got %d active", len(stillOnlyOne))
	}
}

func TestChangePassword_RevokesOtherSessionsButKeepsCurrent(t *testing.T) {
	h := newTestHarness(t)
	ctx := context.Background()
	userID, email := registerTestUser(t, h)

	// Simulate a second device logging in.
	if _, err := h.service.Login(ctx, auth.LoginInput{
		UsernameOrEmail: email,
		Password:        testUserPassword,
	}); err != nil {
		t.Fatalf("second-device Login() error = %v", err)
	}

	sessionsBefore, err := h.service.ListSessions(ctx, userID)
	if err != nil {
		t.Fatalf("ListSessions() error = %v", err)
	}
	if len(sessionsBefore) != 2 {
		t.Fatalf("got %d sessions before change, want 2 (register + login)", len(sessionsBefore))
	}
	currentSessionID := sessionsBefore[0].ID

	if err := h.service.ChangePassword(ctx, userID, currentSessionID, testUserPassword, "a-brand-new-password"); err != nil {
		t.Fatalf("ChangePassword() error = %v", err)
	}

	sessionsAfter, err := h.service.ListSessions(ctx, userID)
	if err != nil {
		t.Fatalf("ListSessions() error = %v", err)
	}
	if len(sessionsAfter) != 1 {
		t.Fatalf("got %d sessions after change, want 1 (only the current one survives)", len(sessionsAfter))
	}
	if sessionsAfter[0].ID != currentSessionID {
		t.Errorf("the surviving session is %v, want the one used to make the change (%v)", sessionsAfter[0].ID, currentSessionID)
	}

	// The old password must no longer work; the new one must.
	if _, err := h.service.Login(ctx, auth.LoginInput{UsernameOrEmail: email, Password: testUserPassword}); err == nil {
		t.Error("old password still works after ChangePassword")
	}
	if _, err := h.service.Login(ctx, auth.LoginInput{UsernameOrEmail: email, Password: "a-brand-new-password"}); err != nil {
		t.Errorf("new password login failed: %v", err)
	}
}

func TestRevokeSession_CannotRevokeAnotherUsersSession(t *testing.T) {
	h := newTestHarness(t)
	ctx := context.Background()
	userA, _ := registerTestUser(t, h)
	userB, _ := registerTestUser(t, h)

	sessionsA, err := h.service.ListSessions(ctx, userA)
	if err != nil {
		t.Fatalf("ListSessions() error = %v", err)
	}
	if len(sessionsA) != 1 {
		t.Fatalf("got %d sessions for user A, want 1", len(sessionsA))
	}

	if err := h.service.RevokeSession(ctx, userB, sessionsA[0].ID); err == nil {
		t.Fatal("expected an error when user B tries to revoke user A's session")
	}

	stillActive, err := h.service.ListSessions(ctx, userA)
	if err != nil {
		t.Fatalf("ListSessions() error = %v", err)
	}
	if len(stillActive) != 1 {
		t.Errorf("user A's session must survive a cross-user revoke attempt; got %d active", len(stillActive))
	}
}
