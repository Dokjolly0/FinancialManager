package identities

import (
	"context"
	"fmt"

	"google.golang.org/api/idtoken"
)

// GoogleClaims are the fields of a verified Google ID token this app cares
// about (plan.md section 15.2).
type GoogleClaims struct {
	Subject       string
	Email         string
	EmailVerified bool
	GivenName     string
	FamilyName    string
}

// GoogleIDTokenVerifier abstracts Google ID token verification so it can
// be substituted with a fake in tests — a real signed Google token can only
// be produced by an actual Google sign-in, which unit tests cannot do.
type GoogleIDTokenVerifier interface {
	Verify(ctx context.Context, idToken string) (GoogleClaims, error)
}

// RealGoogleIDTokenVerifier validates signature, issuer, audience, and
// expiry against Google's published keys (plan.md section 15.2). audiences
// is the allowlist from GOOGLE_CLIENT_IDS — an unlisted audience is
// rejected even if the signature is otherwise valid.
type RealGoogleIDTokenVerifier struct {
	Audiences []string
}

func (v RealGoogleIDTokenVerifier) Verify(ctx context.Context, rawToken string) (GoogleClaims, error) {
	if len(v.Audiences) == 0 {
		return GoogleClaims{}, fmt.Errorf("no Google client IDs configured (GOOGLE_CLIENT_IDS)")
	}

	var lastErr error
	for _, audience := range v.Audiences {
		payload, err := idtoken.Validate(ctx, rawToken, audience)
		if err != nil {
			lastErr = err
			continue
		}
		return claimsFromPayload(payload)
	}
	return GoogleClaims{}, fmt.Errorf("google id token validation failed: %w", lastErr)
}

// FakeGoogleIDTokenVerifier is a test double: a real signed Google ID
// token can only come from an actual Google sign-in, which nothing in
// this codebase's test suite can produce. It maps raw token strings to
// pre-baked claims (or a forced error) so the surrounding login/link/
// registration-ticket logic can be exercised without a real Google
// round-trip.
type FakeGoogleIDTokenVerifier struct {
	Claims map[string]GoogleClaims
	Err    error
}

func (v FakeGoogleIDTokenVerifier) Verify(ctx context.Context, idToken string) (GoogleClaims, error) {
	if v.Err != nil {
		return GoogleClaims{}, v.Err
	}
	claims, ok := v.Claims[idToken]
	if !ok {
		return GoogleClaims{}, fmt.Errorf("fake verifier: no claims registered for token %q", idToken)
	}
	return claims, nil
}

func claimsFromPayload(payload *idtoken.Payload) (GoogleClaims, error) {
	subject := payload.Subject
	if subject == "" {
		return GoogleClaims{}, fmt.Errorf("google id token missing subject")
	}

	email, _ := payload.Claims["email"].(string)
	emailVerified, _ := payload.Claims["email_verified"].(bool)
	givenName, _ := payload.Claims["given_name"].(string)
	familyName, _ := payload.Claims["family_name"].(string)

	return GoogleClaims{
		Subject:       subject,
		Email:         email,
		EmailVerified: emailVerified,
		GivenName:     givenName,
		FamilyName:    familyName,
	}, nil
}
