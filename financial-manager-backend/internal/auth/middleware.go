package auth

import (
	"net/http"
	"strings"

	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/reqctx"
	"financial-manager-backend/internal/platform/security"
)

// Middleware validates the Authorization: Bearer <access token> header and
// injects the authenticated user/session into request context (plan.md
// section 19.1: every protected endpoint resolves identity from the
// session, never from a client-supplied ID). It does not hit the database
// — access tokens are stateless JWTs, valid until they expire or the
// signing key rotates.
func Middleware(jwtSigningKey string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			header := r.Header.Get("Authorization")
			const prefix = "Bearer "
			if !strings.HasPrefix(header, prefix) {
				apierror.Write(w, r, apierror.ErrUnauthorized)
				return
			}

			claims, err := security.ParseAccessToken(jwtSigningKey, strings.TrimPrefix(header, prefix))
			if err != nil {
				apierror.Write(w, r, apierror.ErrUnauthorized)
				return
			}

			ctx := reqctx.WithUser(r.Context(), claims.UserID, claims.SessionID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
