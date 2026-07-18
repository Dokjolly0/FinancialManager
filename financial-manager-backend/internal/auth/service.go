package auth

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"financial-manager-backend/internal/email"
	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/clock"
	"financial-manager-backend/internal/platform/database"
	"financial-manager-backend/internal/platform/idempotency"
	"financial-manager-backend/internal/platform/passwordhash"
	"financial-manager-backend/internal/platform/ratelimit"
	"financial-manager-backend/internal/platform/security"
	"financial-manager-backend/internal/transactions"
	"financial-manager-backend/internal/users"
	"financial-manager-backend/internal/wallets"
)

const (
	registerEndpoint = "POST /v1/auth/register"

	loginRateLimitPerWindow = 5
	loginRateLimitWindow    = 15 * time.Minute
	lockoutThreshold        = 8
	lockoutDuration         = 15 * time.Minute

	emailVerificationTTL = 24 * time.Hour
	passwordResetTTL     = 30 * time.Minute
	idempotencyTTL       = 24 * time.Hour
)

var hexColorPattern = regexp.MustCompile(`^#[0-9A-Fa-f]{6}$`)

type Service struct {
	db                *database.Pool
	users             *users.Repository
	credentials       *CredentialsRepository
	sessions          *SessionRepository
	emailVerification *EmailVerificationTokenRepository
	passwordReset     *PasswordResetTokenRepository
	wallets           *wallets.Repository
	transactions      *transactions.Repository
	rateLimiter       *ratelimit.Limiter
	emailSender       email.Sender
	clock             clock.Clock
	jwtSigningKey     string
	accessTokenTTL    time.Duration
	refreshTokenTTL   time.Duration
}

type Deps struct {
	DB              *database.Pool
	Users           *users.Repository
	Credentials     *CredentialsRepository
	Sessions        *SessionRepository
	EmailVerify     *EmailVerificationTokenRepository
	PasswordReset   *PasswordResetTokenRepository
	Wallets         *wallets.Repository
	Transactions    *transactions.Repository
	RateLimiter     *ratelimit.Limiter
	EmailSender     email.Sender
	Clock           clock.Clock
	JWTSigningKey   string
	AccessTokenTTL  time.Duration
	RefreshTokenTTL time.Duration
}

func NewService(d Deps) *Service {
	return &Service{
		db:                d.DB,
		users:             d.Users,
		credentials:       d.Credentials,
		sessions:          d.Sessions,
		emailVerification: d.EmailVerify,
		passwordReset:     d.PasswordReset,
		wallets:           d.Wallets,
		transactions:      d.Transactions,
		rateLimiter:       d.RateLimiter,
		emailSender:       d.EmailSender,
		clock:             d.Clock,
		jwtSigningKey:     d.JWTSigningKey,
		accessTokenTTL:    d.AccessTokenTTL,
		refreshTokenTTL:   d.RefreshTokenTTL,
	}
}

// --- Register ---------------------------------------------------------

type RegisterInput struct {
	FirstName             string
	LastName              string
	Username              string
	Email                 string
	Password              string
	ConfirmPassword       string
	AvatarBackgroundColor string
	AvatarTextColor       string
	InitialBalanceMinor   int64
	Currency              string
	Timezone              string
	Locale                string
	AcceptedTerms         bool
	DeviceName            *string
	Platform              *string
	IdempotencyKey        uuid.UUID
	RequestBody           []byte // raw request body, for idempotency request-hash comparison
}

// AuthResponse is what both registration and login return: the freshly
// authenticated principal plus a token pair. Kept JSON-serializable
// end-to-end (rather than a typed result the handler re-encodes) so
// register's idempotency replay can store and resend the exact original
// bytes (plan.md section 10.7).
type AuthResponse struct {
	User struct {
		ID            string `json:"id"`
		FirstName     string `json:"first_name"`
		LastName      string `json:"last_name"`
		Username      string `json:"username"`
		Email         string `json:"email"`
		EmailVerified bool   `json:"email_verified"`
	} `json:"user"`
	Wallet struct {
		ID                  string `json:"id"`
		Currency            string `json:"currency"`
		CurrentBalanceMinor int64  `json:"current_balance_minor"`
	} `json:"wallet"`
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int64  `json:"expires_in_seconds"`
}

func validateRegisterInput(in RegisterInput) map[string]string {
	fieldErrors := map[string]string{}

	if strings.TrimSpace(in.FirstName) == "" {
		fieldErrors["first_name"] = "Campo obbligatorio."
	}
	if strings.TrimSpace(in.LastName) == "" {
		fieldErrors["last_name"] = "Campo obbligatorio."
	}
	if len(users.NormalizeUsername(in.Username)) < 3 || len(in.Username) > 40 {
		fieldErrors["username"] = "Deve avere tra 3 e 40 caratteri."
	}
	if !strings.Contains(in.Email, "@") || len(in.Email) > 320 {
		fieldErrors["email"] = "Email non valida."
	}
	if len(in.Password) < 8 {
		fieldErrors["password"] = "Deve avere almeno 8 caratteri."
	}
	if in.Password != in.ConfirmPassword {
		fieldErrors["confirm_password"] = "Le password non coincidono."
	}
	if !hexColorPattern.MatchString(in.AvatarBackgroundColor) {
		fieldErrors["avatar_background_color"] = "Formato colore non valido."
	}
	if !hexColorPattern.MatchString(in.AvatarTextColor) {
		fieldErrors["avatar_text_color"] = "Formato colore non valido."
	}
	if in.InitialBalanceMinor < 0 {
		fieldErrors["initial_balance_minor"] = "Non può essere negativo."
	}
	if in.Currency != "EUR" {
		fieldErrors["currency"] = "Solo EUR è supportato in questa versione."
	}
	if !in.AcceptedTerms {
		fieldErrors["accepted_terms"] = "Devi accettare i termini per procedere."
	}
	if in.IdempotencyKey == uuid.Nil {
		fieldErrors["idempotency_key"] = "Campo obbligatorio."
	}

	return fieldErrors
}

// Register creates the user, their single wallet, its OPENING_BALANCE
// transaction, password credentials, and an initial session — all in one
// DB transaction (plan.md section 7.3, 8.1, 13.2) — and sends a
// verification email. Retrying with the same Idempotency-Key replays the
// original response instead of creating a second account.
func (s *Service) Register(ctx context.Context, in RegisterInput) ([]byte, int, error) {
	if fieldErrors := validateRegisterInput(in); len(fieldErrors) > 0 {
		return nil, 0, apierror.NewValidation(fieldErrors)
	}

	usernameNorm := users.NormalizeUsername(in.Username)
	emailNorm := users.NormalizeEmail(in.Email)
	requestHash := sha256Sum(in.RequestBody)

	passwordHashed, err := passwordhash.Hash(in.Password)
	if err != nil {
		return nil, 0, fmt.Errorf("hash password: %w", err)
	}

	var (
		responseBody []byte
		verifyToken  string
		newUserEmail string
	)

	err = s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		idemStore := idempotency.NewStore(tx)
		claimed, existing, claimErr := idemStore.Claim(ctx, emailNorm, registerEndpoint, in.IdempotencyKey, requestHash, idempotencyTTL)
		if claimErr != nil {
			if errors.Is(claimErr, idempotency.ErrKeyReusedWithDifferentPayload) {
				return apierror.New(http.StatusUnprocessableEntity, "IDEMPOTENCY_KEY_REUSED",
					"La chiave di idempotenza è già stata usata con dati diversi.")
			}
			return claimErr
		}
		if !claimed {
			responseBody = existing.ResponseBody
			return nil
		}

		usernameTaken, emailTaken, checkErr := s.users.WithQuerier(tx).UsernameOrEmailTaken(ctx, usernameNorm, emailNorm)
		if checkErr != nil {
			return checkErr
		}
		if usernameTaken {
			return conflictWithField(apierror.ErrUsernameInUse, "username")
		}
		if emailTaken {
			return conflictWithField(apierror.ErrEmailInUse, "email")
		}

		timezone := in.Timezone
		if timezone == "" {
			timezone = "Europe/Rome"
		}
		locale := in.Locale
		if locale == "" {
			locale = "it-IT"
		}

		txUsers := s.users.WithQuerier(tx)
		user, createErr := txUsers.Create(ctx, users.CreateInput{
			FirstName:             in.FirstName,
			LastName:              in.LastName,
			Username:              in.Username,
			Email:                 in.Email,
			AvatarBackgroundColor: in.AvatarBackgroundColor,
			AvatarTextColor:       in.AvatarTextColor,
			Locale:                locale,
			Timezone:              timezone,
		})
		if createErr != nil {
			if isUniqueViolation(createErr, "users_username_normalized_key") {
				return conflictWithField(apierror.ErrUsernameInUse, "username")
			}
			if isUniqueViolation(createErr, "users_email_normalized_key") {
				return conflictWithField(apierror.ErrEmailInUse, "email")
			}
			return createErr
		}

		wallet, walletErr := s.wallets.WithQuerier(tx).Create(ctx, user.ID, in.Currency, in.InitialBalanceMinor)
		if walletErr != nil {
			return fmt.Errorf("create wallet: %w", walletErr)
		}

		now := s.clock.Now()
		// amount_minor must be > 0 per the transactions table constraint.
		// A zero initial balance is valid (section 3.1: "non negativo") but
		// simply has no OPENING_BALANCE ledger row — the wallet's balance
		// is already 0 from creation.
		if in.InitialBalanceMinor > 0 {
			_, txErr := s.transactions.WithQuerier(tx).Create(ctx, transactions.CreateInput{
				WalletID:    wallet.ID,
				UserID:      user.ID,
				Direction:   transactions.DirectionCredit,
				Kind:        transactions.KindOpeningBalance,
				AmountMinor: in.InitialBalanceMinor,
				Currency:    in.Currency,
				Title:       "Saldo iniziale",
				OccurredAt:  now,
			})
			if txErr != nil {
				return fmt.Errorf("create opening balance transaction: %w", txErr)
			}
		}

		if credErr := s.credentials.WithQuerier(tx).Create(ctx, user.ID, passwordHashed); credErr != nil {
			return fmt.Errorf("create password credentials: %w", credErr)
		}

		rawRefreshToken, tokenErr := security.NewOpaqueToken()
		if tokenErr != nil {
			return tokenErr
		}
		session, sessionErr := s.sessions.WithQuerier(tx).Create(ctx, CreateSessionInput{
			UserID:           user.ID,
			RefreshTokenHash: security.HashToken(rawRefreshToken),
			DeviceName:       in.DeviceName,
			Platform:         in.Platform,
			ExpiresAt:        now.Add(s.refreshTokenTTL),
		})
		if sessionErr != nil {
			return fmt.Errorf("create session: %w", sessionErr)
		}

		accessToken, jwtErr := security.IssueAccessToken(s.jwtSigningKey, user.ID, session.ID, s.accessTokenTTL, now)
		if jwtErr != nil {
			return fmt.Errorf("issue access token: %w", jwtErr)
		}

		rawVerifyToken, vtErr := security.NewOpaqueToken()
		if vtErr != nil {
			return vtErr
		}
		if evErr := s.emailVerification.WithQuerier(tx).Create(ctx, user.ID, security.HashToken(rawVerifyToken), emailVerificationTTL); evErr != nil {
			return fmt.Errorf("create email verification token: %w", evErr)
		}
		verifyToken = rawVerifyToken
		newUserEmail = user.Email

		var resp AuthResponse
		resp.User.ID = user.ID.String()
		resp.User.FirstName = user.FirstName
		resp.User.LastName = user.LastName
		resp.User.Username = user.Username
		resp.User.Email = user.Email
		resp.User.EmailVerified = false
		resp.Wallet.ID = wallet.ID.String()
		resp.Wallet.Currency = wallet.Currency
		resp.Wallet.CurrentBalanceMinor = in.InitialBalanceMinor
		resp.AccessToken = accessToken
		resp.RefreshToken = rawRefreshToken
		resp.ExpiresIn = int64(s.accessTokenTTL.Seconds())

		encoded, encErr := json.Marshal(resp)
		if encErr != nil {
			return fmt.Errorf("encode register response: %w", encErr)
		}
		responseBody = encoded

		return idemStore.Fill(ctx, emailNorm, registerEndpoint, in.IdempotencyKey, http.StatusCreated, encoded)
	})
	if err != nil {
		return nil, 0, err
	}

	// Best-effort: a failed verification email must not fail registration.
	if verifyToken != "" {
		s.sendVerificationEmail(ctx, newUserEmail, verifyToken)
	}

	return responseBody, http.StatusCreated, nil
}

func (s *Service) sendVerificationEmail(ctx context.Context, to string, rawToken string) {
	_ = s.emailSender.Send(ctx, email.Message{
		To:      to,
		Subject: "Conferma la tua email",
		Body:    fmt.Sprintf("Usa questo codice per verificare la tua email: %s", rawToken),
	})
}

// --- Login --------------------------------------------------------------

type LoginInput struct {
	UsernameOrEmail string
	Password        string
	DeviceName      *string
	Platform        *string
	ClientIPHash    []byte
}

func (s *Service) Login(ctx context.Context, in LoginInput) (AuthResponse, error) {
	normalized := users.NormalizeEmail(in.UsernameOrEmail)
	if !strings.Contains(normalized, "@") {
		normalized = users.NormalizeUsername(in.UsernameOrEmail)
	}

	if s.rateLimiter != nil {
		result, rlErr := s.rateLimiter.Allow(ctx, "ratelimit:login:user:"+normalized, loginRateLimitPerWindow, loginRateLimitWindow)
		if rlErr == nil && !result.Allowed {
			return AuthResponse{}, apierror.ErrRateLimited
		}
	}

	var user users.User
	var err error
	if strings.Contains(in.UsernameOrEmail, "@") {
		user, err = s.users.GetByEmailNormalized(ctx, users.NormalizeEmail(in.UsernameOrEmail))
	} else {
		user, err = s.users.GetByUsernameNormalized(ctx, users.NormalizeUsername(in.UsernameOrEmail))
	}
	if err != nil {
		// Same generic error whether the account doesn't exist or the
		// password is wrong (plan.md section 15.5: avoid enumeration).
		return AuthResponse{}, apierror.ErrInvalidLogin
	}

	creds, err := s.credentials.GetByUserID(ctx, user.ID)
	if err != nil {
		return AuthResponse{}, apierror.ErrInvalidLogin
	}

	now := s.clock.Now()
	if creds.LockedUntil != nil && now.Before(*creds.LockedUntil) {
		return AuthResponse{}, apierror.New(http.StatusTooManyRequests, "ACCOUNT_LOCKED",
			"Account temporaneamente bloccato per troppi tentativi falliti.")
	}

	ok, verifyErr := passwordhash.Verify(creds.PasswordHash, in.Password)
	if verifyErr != nil || !ok {
		_ = s.credentials.RecordFailedAttempt(ctx, user.ID, lockoutThreshold, lockoutDuration)
		return AuthResponse{}, apierror.ErrInvalidLogin
	}
	_ = s.credentials.ResetFailedAttempts(ctx, user.ID)

	wallet, err := s.wallets.GetByUserID(ctx, user.ID)
	if err != nil {
		return AuthResponse{}, fmt.Errorf("load wallet: %w", err)
	}

	rawRefreshToken, err := security.NewOpaqueToken()
	if err != nil {
		return AuthResponse{}, err
	}
	session, err := s.sessions.Create(ctx, CreateSessionInput{
		UserID:           user.ID,
		RefreshTokenHash: security.HashToken(rawRefreshToken),
		DeviceName:       in.DeviceName,
		Platform:         in.Platform,
		ExpiresAt:        now.Add(s.refreshTokenTTL),
	})
	if err != nil {
		return AuthResponse{}, fmt.Errorf("create session: %w", err)
	}

	accessToken, err := security.IssueAccessToken(s.jwtSigningKey, user.ID, session.ID, s.accessTokenTTL, now)
	if err != nil {
		return AuthResponse{}, fmt.Errorf("issue access token: %w", err)
	}

	var resp AuthResponse
	resp.User.ID = user.ID.String()
	resp.User.FirstName = user.FirstName
	resp.User.LastName = user.LastName
	resp.User.Username = user.Username
	resp.User.Email = user.Email
	resp.User.EmailVerified = user.EmailVerified()
	resp.Wallet.ID = wallet.ID.String()
	resp.Wallet.Currency = wallet.Currency
	resp.Wallet.CurrentBalanceMinor = wallet.CurrentBalanceMinor
	resp.AccessToken = accessToken
	resp.RefreshToken = rawRefreshToken
	resp.ExpiresIn = int64(s.accessTokenTTL.Seconds())
	return resp, nil
}

// --- Refresh / logout -----------------------------------------------------

type RefreshResult struct {
	AccessToken  string
	RefreshToken string
	ExpiresIn    int64
}

func (s *Service) Refresh(ctx context.Context, rawRefreshToken string) (RefreshResult, error) {
	hash := security.HashToken(rawRefreshToken)
	session, err := s.sessions.GetByRefreshTokenHash(ctx, hash)
	if errors.Is(err, ErrSessionNotFound) {
		return RefreshResult{}, apierror.ErrUnauthorized
	}
	if err != nil {
		return RefreshResult{}, err
	}

	now := s.clock.Now()

	// Reuse detection: this token was already rotated away. Someone is
	// replaying an old refresh token — revoke every session for the user
	// (plan.md section 15.6: "revoca della famiglia").
	if session.RevokedAt != nil {
		_ = s.sessions.RevokeAllForUser(ctx, session.UserID)
		return RefreshResult{}, apierror.ErrUnauthorized
	}

	if !session.Active(now) {
		return RefreshResult{}, apierror.ErrUnauthorized
	}

	newRawRefreshToken, err := security.NewOpaqueToken()
	if err != nil {
		return RefreshResult{}, err
	}

	newSession, err := s.sessions.Rotate(ctx, session.ID, CreateSessionInput{
		UserID:           session.UserID,
		RefreshTokenHash: security.HashToken(newRawRefreshToken),
		DeviceName:       session.DeviceName,
		Platform:         session.Platform,
		ExpiresAt:        now.Add(s.refreshTokenTTL),
	})
	if err != nil {
		return RefreshResult{}, fmt.Errorf("rotate session: %w", err)
	}

	accessToken, err := security.IssueAccessToken(s.jwtSigningKey, session.UserID, newSession.ID, s.accessTokenTTL, now)
	if err != nil {
		return RefreshResult{}, fmt.Errorf("issue access token: %w", err)
	}

	return RefreshResult{
		AccessToken:  accessToken,
		RefreshToken: newRawRefreshToken,
		ExpiresIn:    int64(s.accessTokenTTL.Seconds()),
	}, nil
}

func (s *Service) Logout(ctx context.Context, sessionID uuid.UUID) error {
	return s.sessions.Revoke(ctx, sessionID)
}

func (s *Service) LogoutAll(ctx context.Context, userID uuid.UUID) error {
	return s.sessions.RevokeAllForUser(ctx, userID)
}

// --- Password reset -------------------------------------------------------

func (s *Service) ForgotPassword(ctx context.Context, emailOrUsername string) error {
	if s.rateLimiter != nil {
		key := "ratelimit:password-forgot:" + users.NormalizeEmail(emailOrUsername)
		if result, err := s.rateLimiter.Allow(ctx, key, 3, time.Hour); err == nil && !result.Allowed {
			return apierror.ErrRateLimited
		}
	}

	user, err := s.users.GetByEmailNormalized(ctx, users.NormalizeEmail(emailOrUsername))
	if err != nil {
		// Always behave as if it succeeded — do not reveal whether the
		// account exists (plan.md section 15.5).
		return nil
	}

	rawToken, err := security.NewOpaqueToken()
	if err != nil {
		return err
	}
	if err := s.passwordReset.Create(ctx, user.ID, security.HashToken(rawToken), passwordResetTTL); err != nil {
		return fmt.Errorf("create password reset token: %w", err)
	}

	_ = s.emailSender.Send(ctx, email.Message{
		To:      user.Email,
		Subject: "Reimposta la tua password",
		Body:    fmt.Sprintf("Usa questo codice per reimpostare la password: %s", rawToken),
	})
	return nil
}

func (s *Service) ResetPassword(ctx context.Context, rawToken, newPassword string) error {
	if len(newPassword) < 8 {
		return apierror.NewValidation(map[string]string{"password": "Deve avere almeno 8 caratteri."})
	}

	userID, err := s.passwordReset.ConsumeValid(ctx, security.HashToken(rawToken))
	if errors.Is(err, ErrTokenNotFound) {
		return apierror.New(http.StatusUnprocessableEntity, "INVALID_OR_EXPIRED_TOKEN", "Il link non è valido o è scaduto.")
	}
	if err != nil {
		return err
	}

	hashed, err := passwordhash.Hash(newPassword)
	if err != nil {
		return err
	}
	if err := s.credentials.UpdatePassword(ctx, userID, hashed); err != nil {
		return err
	}

	// Resetting the password invalidates every existing session
	// (plan.md section 15: a leaked password shouldn't leave old sessions
	// valid).
	return s.sessions.RevokeAllForUser(ctx, userID)
}

// --- Email verification ---------------------------------------------------

func (s *Service) VerifyEmail(ctx context.Context, rawToken string) error {
	userID, err := s.emailVerification.ConsumeValid(ctx, security.HashToken(rawToken))
	if errors.Is(err, ErrTokenNotFound) {
		return apierror.New(http.StatusUnprocessableEntity, "INVALID_OR_EXPIRED_TOKEN", "Il link non è valido o è scaduto.")
	}
	if err != nil {
		return err
	}
	return s.users.MarkEmailVerified(ctx, userID)
}

func (s *Service) ResendVerification(ctx context.Context, userID uuid.UUID) error {
	if s.rateLimiter != nil {
		key := "ratelimit:email-resend:" + userID.String()
		if result, err := s.rateLimiter.Allow(ctx, key, 3, time.Hour); err == nil && !result.Allowed {
			return apierror.ErrRateLimited
		}
	}

	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	if user.EmailVerified() {
		return nil
	}

	rawToken, err := security.NewOpaqueToken()
	if err != nil {
		return err
	}
	if err := s.emailVerification.Create(ctx, userID, security.HashToken(rawToken), emailVerificationTTL); err != nil {
		return err
	}

	s.sendVerificationEmail(ctx, user.Email, rawToken)
	return nil
}

// --- helpers ---------------------------------------------------------------

func sha256Sum(b []byte) []byte {
	sum := sha256.Sum256(b)
	return sum[:]
}

func conflictWithField(base *apierror.Error, field string) *apierror.Error {
	return &apierror.Error{
		Status:      base.Status,
		Code:        base.Code,
		Message:     base.Message,
		FieldErrors: map[string]string{field: base.Message},
	}
}

func isUniqueViolation(err error, constraintName string) bool {
	var pgErr *pgconn.PgError
	if !errors.As(err, &pgErr) {
		return false
	}
	return pgErr.Code == "23505" && pgErr.ConstraintName == constraintName
}
