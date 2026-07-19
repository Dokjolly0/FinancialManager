package auth

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"financial-manager-backend/internal/identities"
	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/passwordhash"
	"financial-manager-backend/internal/platform/security"
	"financial-manager-backend/internal/transactions"
	"financial-manager-backend/internal/users"
	"financial-manager-backend/internal/wallets"
)

// GoogleVerifyInput is the request to POST /v1/auth/google/verify
// (plan.md section 14.1, flow in section 8.2).
type GoogleVerifyInput struct {
	IDToken    string
	DeviceName *string
	Platform   *string
}

// GoogleVerifyResult carries exactly one of the two branches of the
// flowchart in plan.md section 8.2: either the identity was already
// linked (Authenticated, Auth populated — same shape login/register
// return) or it wasn't (a Ticket the client must complete registration
// with).
type GoogleVerifyResult struct {
	Authenticated bool
	Auth          AuthResponse
	Ticket        GoogleTicketResponse
}

type GoogleTicketResponse struct {
	Ticket             string `json:"ticket"`
	Email              string `json:"email"`
	EmailVerified      bool   `json:"email_verified"`
	SuggestedFirstName string `json:"suggested_first_name"`
	SuggestedLastName  string `json:"suggested_last_name"`
}

func (s *Service) GoogleVerify(ctx context.Context, in GoogleVerifyInput) (GoogleVerifyResult, error) {
	claims, err := s.googleVerifier.Verify(ctx, in.IDToken)
	if err != nil {
		return GoogleVerifyResult{}, apierror.New(http.StatusUnauthorized, "INVALID_GOOGLE_TOKEN", "Token Google non valido.")
	}

	identity, err := s.identities.GetByProviderSubject(ctx, identities.ProviderGoogle, claims.Subject)
	if err == nil {
		return s.googleLogin(ctx, identity, in)
	}
	if !errors.Is(err, identities.ErrNotFound) {
		return GoogleVerifyResult{}, err
	}

	rawTicket, err := s.ticketStore.Issue(ctx, claims)
	if err != nil {
		return GoogleVerifyResult{}, fmt.Errorf("issue registration ticket: %w", err)
	}

	return GoogleVerifyResult{
		Authenticated: false,
		Ticket: GoogleTicketResponse{
			Ticket:             rawTicket,
			Email:              claims.Email,
			EmailVerified:      claims.EmailVerified,
			SuggestedFirstName: claims.GivenName,
			SuggestedLastName:  claims.FamilyName,
		},
	}, nil
}

func (s *Service) googleLogin(ctx context.Context, identity identities.ExternalIdentity, in GoogleVerifyInput) (GoogleVerifyResult, error) {
	user, err := s.users.GetByID(ctx, identity.UserID)
	if err != nil {
		return GoogleVerifyResult{}, fmt.Errorf("load user for linked google identity: %w", err)
	}
	wallet, err := s.wallets.GetByUserID(ctx, identity.UserID)
	if err != nil {
		return GoogleVerifyResult{}, fmt.Errorf("load wallet for linked google identity: %w", err)
	}

	now := s.clock.Now()
	_, accessToken, rawRefreshToken, err := s.issueSession(ctx, s.sessions, user.ID, in.DeviceName, in.Platform, now)
	if err != nil {
		return GoogleVerifyResult{}, err
	}

	_ = s.identities.TouchLastUsed(ctx, identity.ID)

	return GoogleVerifyResult{Authenticated: true, Auth: buildAuthResponse(user, wallet, accessToken, rawRefreshToken, s.accessTokenTTL)}, nil
}

// issueSession centralizes refresh-token generation, session creation, and
// access-token issuance so both the plain-login and Google-login paths
// stay in sync (plan.md section 15.6). sessionsRepo may be pool-bound or
// tx-bound depending on the caller's transactional context.
func (s *Service) issueSession(ctx context.Context, sessionsRepo *SessionRepository, userID uuid.UUID, deviceName, platform *string, now time.Time) (Session, string, string, error) {
	rawRefreshToken, err := security.NewOpaqueToken()
	if err != nil {
		return Session{}, "", "", err
	}
	session, err := sessionsRepo.Create(ctx, CreateSessionInput{
		UserID:           userID,
		RefreshTokenHash: security.HashToken(rawRefreshToken),
		DeviceName:       deviceName,
		Platform:         platform,
		ExpiresAt:        now.Add(s.refreshTokenTTL),
	})
	if err != nil {
		return Session{}, "", "", fmt.Errorf("create session: %w", err)
	}

	accessToken, err := security.IssueAccessToken(s.jwtSigningKey, userID, session.ID, s.accessTokenTTL, now)
	if err != nil {
		return Session{}, "", "", fmt.Errorf("issue access token: %w", err)
	}

	return session, accessToken, rawRefreshToken, nil
}

// buildAuthResponse assembles the same response shape Register/Login use,
// so the client handles Google sign-in results identically to any other
// authentication method.
func buildAuthResponse(user users.User, wallet wallets.Wallet, accessToken, refreshToken string, accessTokenTTL time.Duration) AuthResponse {
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
	resp.RefreshToken = refreshToken
	resp.ExpiresIn = int64(accessTokenTTL.Seconds())
	return resp
}

// --- Complete registration after a Google ticket ---------------------------

type CompleteGoogleRegistrationInput struct {
	Ticket                string
	Username              string
	Password              string // optional: plan.md section 7.4 allows Google-only accounts
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
}

func validateGoogleCompletionInput(in CompleteGoogleRegistrationInput) map[string]string {
	fieldErrors := map[string]string{}

	if len(users.NormalizeUsername(in.Username)) < 3 || len(in.Username) > 40 {
		fieldErrors["username"] = "Deve avere tra 3 e 40 caratteri."
	}
	if in.Password != "" {
		if len(in.Password) < 8 {
			fieldErrors["password"] = "Deve avere almeno 8 caratteri."
		}
		if in.Password != in.ConfirmPassword {
			fieldErrors["confirm_password"] = "Le password non coincidono."
		}
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
	if strings.TrimSpace(in.Ticket) == "" {
		fieldErrors["ticket"] = "Campo obbligatorio."
	}

	return fieldErrors
}

func (s *Service) CompleteGoogleRegistration(ctx context.Context, in CompleteGoogleRegistrationInput) (AuthResponse, error) {
	if fieldErrors := validateGoogleCompletionInput(in); len(fieldErrors) > 0 {
		return AuthResponse{}, apierror.NewValidation(fieldErrors)
	}

	ticket, err := s.ticketStore.Consume(ctx, in.Ticket)
	if errors.Is(err, identities.ErrTicketNotFound) {
		return AuthResponse{}, apierror.New(http.StatusUnprocessableEntity, "INVALID_OR_EXPIRED_TOKEN",
			"Il ticket di registrazione non è valido o è scaduto. Accedi di nuovo con Google.")
	}
	if err != nil {
		return AuthResponse{}, err
	}

	usernameNorm := users.NormalizeUsername(in.Username)
	emailNorm := users.NormalizeEmail(ticket.Email)
	timezone := in.Timezone
	if timezone == "" {
		timezone = "Europe/Rome"
	}
	locale := in.Locale
	if locale == "" {
		locale = "it-IT"
	}

	var resp AuthResponse
	err = s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
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

		txUsers := s.users.WithQuerier(tx)
		user, createErr := txUsers.Create(ctx, users.CreateInput{
			FirstName:             firstNonEmpty(ticket.GivenName, "Utente"),
			LastName:              firstNonEmpty(ticket.FamilyName, "Google"),
			Username:              in.Username,
			Email:                 ticket.Email,
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

		if ticket.EmailVerified {
			if err := txUsers.MarkEmailVerified(ctx, user.ID); err != nil {
				return fmt.Errorf("mark email verified: %w", err)
			}
			verifiedAt := s.clock.Now()
			user.EmailVerifiedAt = &verifiedAt
		}

		wallet, walletErr := s.wallets.WithQuerier(tx).Create(ctx, user.ID, in.Currency, in.InitialBalanceMinor)
		if walletErr != nil {
			return fmt.Errorf("create wallet: %w", walletErr)
		}

		now := s.clock.Now()
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

		providerEmail := ticket.Email
		providerEmailVerified := ticket.EmailVerified
		if _, idErr := s.identities.WithQuerier(tx).Create(ctx, identities.CreateInput{
			UserID:                user.ID,
			Provider:              identities.ProviderGoogle,
			ProviderSubject:       ticket.GoogleSubject,
			ProviderEmail:         &providerEmail,
			ProviderEmailVerified: &providerEmailVerified,
		}); idErr != nil {
			return fmt.Errorf("link google identity: %w", idErr)
		}

		if in.Password != "" {
			hashed, hashErr := passwordhash.Hash(in.Password)
			if hashErr != nil {
				return hashErr
			}
			if credErr := s.credentials.WithQuerier(tx).Create(ctx, user.ID, hashed); credErr != nil {
				return fmt.Errorf("create password credentials: %w", credErr)
			}
		}

		_, accessToken, rawRefreshToken, sessionErr := s.issueSession(ctx, s.sessions.WithQuerier(tx), user.ID, in.DeviceName, in.Platform, now)
		if sessionErr != nil {
			return sessionErr
		}

		resp = buildAuthResponse(user, wallet, accessToken, rawRefreshToken, s.accessTokenTTL)
		return nil
	})

	return resp, err
}

// --- Link / unlink / list identities ---------------------------------------

func (s *Service) LinkGoogle(ctx context.Context, userID uuid.UUID, idToken, currentPassword string) error {
	if err := s.checkPasswordReauthLimit(ctx, userID); err != nil {
		return err
	}

	creds, err := s.credentials.GetByUserID(ctx, userID)
	if err != nil {
		return apierror.ErrUnauthorized
	}
	ok, verifyErr := passwordhash.Verify(creds.PasswordHash, currentPassword)
	if verifyErr != nil || !ok {
		return apierror.New(http.StatusUnauthorized, "REAUTH_REQUIRED", "Conferma la password per collegare un account Google.")
	}

	claims, err := s.googleVerifier.Verify(ctx, idToken)
	if err != nil {
		return apierror.New(http.StatusUnauthorized, "INVALID_GOOGLE_TOKEN", "Token Google non valido.")
	}

	existing, err := s.identities.GetByProviderSubject(ctx, identities.ProviderGoogle, claims.Subject)
	if err == nil {
		if existing.UserID != userID {
			return apierror.New(http.StatusConflict, "GOOGLE_ACCOUNT_ALREADY_LINKED",
				"Questo account Google è già collegato a un altro utente.")
		}
		return nil
	}
	if !errors.Is(err, identities.ErrNotFound) {
		return err
	}

	providerEmail := claims.Email
	providerEmailVerified := claims.EmailVerified
	_, err = s.identities.Create(ctx, identities.CreateInput{
		UserID:                userID,
		Provider:              identities.ProviderGoogle,
		ProviderSubject:       claims.Subject,
		ProviderEmail:         &providerEmail,
		ProviderEmailVerified: &providerEmailVerified,
	})
	return err
}

// UnlinkGoogle only succeeds if the user has a local password set (plan.md
// section 15.4: never leave an account with zero access methods).
func (s *Service) UnlinkGoogle(ctx context.Context, userID uuid.UUID) error {
	if _, err := s.credentials.GetByUserID(ctx, userID); err != nil {
		if errors.Is(err, ErrCredentialsNotFound) {
			return apierror.New(http.StatusConflict, "NO_ALTERNATIVE_LOGIN_METHOD",
				"Imposta prima una password per poter scollegare Google.")
		}
		return err
	}

	return s.identities.DeleteByUserIDAndProvider(ctx, userID, identities.ProviderGoogle)
}

func (s *Service) ListIdentities(ctx context.Context, userID uuid.UUID) ([]identities.ExternalIdentity, error) {
	return s.identities.ListByUserID(ctx, userID)
}

func firstNonEmpty(a, b string) string {
	if strings.TrimSpace(a) != "" {
		return a
	}
	return b
}
