package identities

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"

	"financial-manager-backend/internal/platform/security"
)

// RegistrationTicket carries the verified Google identity across the two
// requests of the sign-up flow (plan.md section 8.2/12.2): the client
// posts the ID token once to /google/verify, gets a short-lived ticket
// back, then submits the remaining required fields (username, avatar,
// wallet) to /google/complete-registration. Storing this in Redis — not
// re-verifying the ID token a second time — is fine because the ticket
// itself is a high-entropy, single-use, short-TTL secret only the backend
// ever issued.
type RegistrationTicket struct {
	GoogleSubject string `json:"google_subject"`
	Email         string `json:"email"`
	EmailVerified bool   `json:"email_verified"`
	GivenName     string `json:"given_name"`
	FamilyName    string `json:"family_name"`
}

var ErrTicketNotFound = errors.New("registration ticket not found or expired")

const registrationTicketTTL = 10 * time.Minute

type TicketStore struct {
	redis *redis.Client
}

func NewTicketStore(redis *redis.Client) *TicketStore {
	return &TicketStore{redis: redis}
}

func ticketKey(rawTicket string) string {
	hash := security.HashToken(rawTicket)
	return "auth:google-registration:" + base64.RawURLEncoding.EncodeToString(hash)
}

// Issue creates a new ticket and returns the raw token to hand to the client.
func (s *TicketStore) Issue(ctx context.Context, claims GoogleClaims) (string, error) {
	rawTicket, err := security.NewOpaqueToken()
	if err != nil {
		return "", err
	}

	payload, err := json.Marshal(RegistrationTicket{
		GoogleSubject: claims.Subject,
		Email:         claims.Email,
		EmailVerified: claims.EmailVerified,
		GivenName:     claims.GivenName,
		FamilyName:    claims.FamilyName,
	})
	if err != nil {
		return "", fmt.Errorf("encode registration ticket: %w", err)
	}

	if err := s.redis.Set(ctx, ticketKey(rawTicket), payload, registrationTicketTTL).Err(); err != nil {
		return "", fmt.Errorf("store registration ticket: %w", err)
	}
	return rawTicket, nil
}

// Consume retrieves and immediately deletes the ticket (single use).
func (s *TicketStore) Consume(ctx context.Context, rawTicket string) (RegistrationTicket, error) {
	key := ticketKey(rawTicket)

	payload, err := s.redis.Get(ctx, key).Bytes()
	if errors.Is(err, redis.Nil) {
		return RegistrationTicket{}, ErrTicketNotFound
	}
	if err != nil {
		return RegistrationTicket{}, fmt.Errorf("fetch registration ticket: %w", err)
	}

	_ = s.redis.Del(ctx, key).Err()

	var ticket RegistrationTicket
	if err := json.Unmarshal(payload, &ticket); err != nil {
		return RegistrationTicket{}, fmt.Errorf("decode registration ticket: %w", err)
	}
	return ticket, nil
}
