package security

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// AccessTokenClaims are the claims carried by short-lived access tokens
// (plan.md section 15.6: 10-20 minutes, here configurable via
// ACCESS_TOKEN_TTL). The token is stateless — validity is the signature
// and expiry, not a database lookup — so revocation happens by expiring
// quickly and by session revocation blocking the *refresh* path, not by
// blacklisting individual access tokens.
type AccessTokenClaims struct {
	UserID    uuid.UUID `json:"uid"`
	SessionID uuid.UUID `json:"sid"`
	jwt.RegisteredClaims
}

func IssueAccessToken(signingKey string, userID, sessionID uuid.UUID, ttl time.Duration, now time.Time) (string, error) {
	claims := AccessTokenClaims{
		UserID:    userID,
		SessionID: sessionID,
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(ttl)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(signingKey))
}

// ParseAccessToken validates the signature and expiry and returns the claims.
func ParseAccessToken(signingKey string, tokenString string) (*AccessTokenClaims, error) {
	claims := &AccessTokenClaims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return []byte(signingKey), nil
	})
	if err != nil {
		return nil, err
	}
	if !token.Valid {
		return nil, fmt.Errorf("invalid token")
	}
	return claims, nil
}
