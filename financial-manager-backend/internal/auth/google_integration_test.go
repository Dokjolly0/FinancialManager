package auth_test

import (
	"context"
	"encoding/json"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/auth"
	"financial-manager-backend/internal/email"
	"financial-manager-backend/internal/identities"
	"financial-manager-backend/internal/platform/clock"
	"financial-manager-backend/internal/platform/database"
	"financial-manager-backend/internal/platform/ratelimit"
	"financial-manager-backend/internal/platform/redisclient"
	"financial-manager-backend/internal/transactions"
	"financial-manager-backend/internal/users"
	"financial-manager-backend/internal/wallets"
)

func decodeUserID(t *testing.T, responseBody []byte) uuid.UUID {
	t.Helper()
	var decoded struct {
		User struct {
			ID string `json:"id"`
		} `json:"user"`
	}
	if err := json.Unmarshal(responseBody, &decoded); err != nil {
		t.Fatalf("decode response body: %v", err)
	}
	id, err := uuid.Parse(decoded.User.ID)
	if err != nil {
		t.Fatalf("parse user id: %v", err)
	}
	return id
}

// This test exercises the whole Google sign-in flow (plan.md section 8.2)
// against a real PostgreSQL and Redis — the same dev stack from
// `docker compose -f compose.yaml -f compose.dev.yaml up`. It cannot use a
// real Google ID token (only an actual Google sign-in can produce one that
// verifies), so it substitutes identities.FakeGoogleIDTokenVerifier; every
// step downstream of "the token was valid" — ticket issuance, registration
// completion, session issuance, subsequent login, linking, unlinking — is
// exercised for real.
//
// Skips automatically if the dev stack isn't reachable, so `go test ./...`
// stays green without Docker running.

type noopEmailSender struct{}

func (noopEmailSender) Send(ctx context.Context, msg email.Message) error { return nil }

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// testHarness bundles the service under test with the fake Google token
// that resolves to known claims, and a fresh, unique username generator so
// repeated test runs against the same database don't collide.
type testHarness struct {
	service   *auth.Service
	fakeToken string
	claims    identities.GoogleClaims
}

func newTestHarness(t *testing.T) testHarness {
	t.Helper()

	databaseURL := envOrDefault("TEST_DATABASE_URL", "postgres://financial_manager:financial_manager@localhost:10001/financial_manager?sslmode=disable")
	redisAddr := envOrDefault("TEST_REDIS_ADDR", "localhost:10002")
	redisPassword := envOrDefault("TEST_REDIS_PASSWORD", "financial_manager")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	dbPool, err := database.Connect(ctx, databaseURL)
	if err != nil {
		t.Skipf("skipping: dev Postgres not reachable at %s: %v", databaseURL, err)
	}
	t.Cleanup(dbPool.Close)

	redisClient, err := redisclient.Connect(ctx, redisAddr, redisPassword)
	if err != nil {
		t.Skipf("skipping: dev Redis not reachable at %s: %v", redisAddr, err)
	}
	t.Cleanup(func() { _ = redisClient.Close() })

	usersRepo := users.NewRepository(dbPool)
	walletsRepo := wallets.NewRepository(dbPool)
	transactionsRepo := transactions.NewRepository(dbPool)
	identitiesRepo := identities.NewRepository(dbPool)

	fakeToken := "fake-google-token-" + uuid.NewString()
	claims := identities.GoogleClaims{
		Subject:       "google-subject-" + uuid.NewString(),
		Email:         "googleuser-" + uuid.NewString()[:8] + "@example.com",
		EmailVerified: true,
		GivenName:     "Giorgia",
		FamilyName:    "Verdi",
	}

	service := auth.NewService(auth.Deps{
		DB:            dbPool,
		Users:         usersRepo,
		Credentials:   auth.NewCredentialsRepository(dbPool),
		Sessions:      auth.NewSessionRepository(dbPool),
		EmailVerify:   auth.NewEmailVerificationTokenRepository(dbPool),
		PasswordReset: auth.NewPasswordResetTokenRepository(dbPool),
		Wallets:       walletsRepo,
		Transactions:  transactionsRepo,
		Identities:    identitiesRepo,
		GoogleVerifier: identities.FakeGoogleIDTokenVerifier{
			Claims: map[string]identities.GoogleClaims{fakeToken: claims},
		},
		TicketStore:     identities.NewTicketStore(redisClient),
		RateLimiter:     ratelimit.New(redisClient),
		EmailSender:     noopEmailSender{},
		Clock:           clock.System{},
		JWTSigningKey:   "test-signing-key",
		AccessTokenTTL:  15 * time.Minute,
		RefreshTokenTTL: 720 * time.Hour,
	})

	return testHarness{service: service, fakeToken: fakeToken, claims: claims}
}

func TestGoogleSignIn_NewUserGetsRegistrationTicket(t *testing.T) {
	h := newTestHarness(t)

	result, err := h.service.GoogleVerify(context.Background(), auth.GoogleVerifyInput{IDToken: h.fakeToken})
	if err != nil {
		t.Fatalf("GoogleVerify() error = %v", err)
	}
	if result.Authenticated {
		t.Fatal("expected a registration ticket for a never-seen Google subject, got an authenticated session")
	}
	if result.Ticket.Email != h.claims.Email {
		t.Errorf("ticket email = %q, want %q", result.Ticket.Email, h.claims.Email)
	}
	if result.Ticket.Ticket == "" {
		t.Error("expected a non-empty ticket")
	}
}

func TestGoogleSignIn_CompleteRegistrationThenLoginAgain(t *testing.T) {
	h := newTestHarness(t)
	ctx := context.Background()

	verifyResult, err := h.service.GoogleVerify(ctx, auth.GoogleVerifyInput{IDToken: h.fakeToken})
	if err != nil {
		t.Fatalf("GoogleVerify() error = %v", err)
	}

	username := "googleuser" + uuid.NewString()[:8]
	authResp, err := h.service.CompleteGoogleRegistration(ctx, auth.CompleteGoogleRegistrationInput{
		Ticket:                verifyResult.Ticket.Ticket,
		Username:              username,
		AvatarBackgroundColor: "#176B5B",
		AvatarTextColor:       "#FFFFFF",
		InitialBalanceMinor:   1000,
		Currency:              "EUR",
		AcceptedTerms:         true,
	})
	if err != nil {
		t.Fatalf("CompleteGoogleRegistration() error = %v", err)
	}
	if authResp.User.Username != username {
		t.Errorf("username = %q, want %q", authResp.User.Username, username)
	}
	if !authResp.User.EmailVerified {
		t.Error("expected email_verified = true (Google already verified it)")
	}
	if authResp.Wallet.CurrentBalanceMinor != 1000 {
		t.Errorf("balance = %d, want 1000", authResp.Wallet.CurrentBalanceMinor)
	}
	if authResp.AccessToken == "" || authResp.RefreshToken == "" {
		t.Error("expected both tokens to be issued")
	}

	// The ticket is single-use.
	_, err = h.service.CompleteGoogleRegistration(ctx, auth.CompleteGoogleRegistrationInput{
		Ticket:                verifyResult.Ticket.Ticket,
		Username:              "shouldnotmatter",
		AvatarBackgroundColor: "#176B5B",
		AvatarTextColor:       "#FFFFFF",
		Currency:              "EUR",
		AcceptedTerms:         true,
	})
	if err == nil {
		t.Error("expected reusing a consumed ticket to fail")
	}

	// The same Google identity signing in again logs in directly instead
	// of issuing another ticket.
	secondVerify, err := h.service.GoogleVerify(ctx, auth.GoogleVerifyInput{IDToken: h.fakeToken})
	if err != nil {
		t.Fatalf("second GoogleVerify() error = %v", err)
	}
	if !secondVerify.Authenticated {
		t.Fatal("expected the second sign-in with the same Google subject to authenticate directly")
	}
	if secondVerify.Auth.User.Username != username {
		t.Errorf("second login username = %q, want %q", secondVerify.Auth.User.Username, username)
	}
}

func TestGoogleLink_RequiresCorrectPassword(t *testing.T) {
	h := newTestHarness(t)
	ctx := context.Background()

	username := "manualuser" + uuid.NewString()[:8]
	regBody, status, err := h.service.Register(ctx, auth.RegisterInput{
		FirstName:             "Manuale",
		LastName:              "Utente",
		Username:              username,
		Email:                 username + "@example.com",
		Password:              "supersecret1",
		ConfirmPassword:       "supersecret1",
		AvatarBackgroundColor: "#176B5B",
		AvatarTextColor:       "#FFFFFF",
		Currency:              "EUR",
		AcceptedTerms:         true,
		IdempotencyKey:        uuid.New(),
		RequestBody:           []byte("{}"),
	})
	if err != nil {
		t.Fatalf("Register() error = %v", err)
	}
	if status != 201 {
		t.Fatalf("Register() status = %d, want 201", status)
	}

	userID := decodeUserID(t, regBody)

	if err := h.service.LinkGoogle(ctx, userID, h.fakeToken, "wrong-password"); err == nil {
		t.Error("expected LinkGoogle to fail with the wrong password")
	}

	if err := h.service.LinkGoogle(ctx, userID, h.fakeToken, "supersecret1"); err != nil {
		t.Fatalf("LinkGoogle() with correct password error = %v", err)
	}

	list, err := h.service.ListIdentities(ctx, userID)
	if err != nil {
		t.Fatalf("ListIdentities() error = %v", err)
	}
	if len(list) != 1 || list[0].Provider != identities.ProviderGoogle {
		t.Fatalf("expected exactly one linked google identity, got %+v", list)
	}

	// Unlinking is allowed: this user has a password too.
	if err := h.service.UnlinkGoogle(ctx, userID); err != nil {
		t.Fatalf("UnlinkGoogle() error = %v", err)
	}
}
