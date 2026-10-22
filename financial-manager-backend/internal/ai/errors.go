package ai

import (
	"errors"
	"net/http"

	"github.com/jackc/pgx/v5/pgconn"

	"financial-manager-backend/internal/ai/provider"
	"financial-manager-backend/internal/platform/apierror"
)

// Feature-level errors (plan.md section 32.4).
var (
	ErrDisabled = apierror.New(http.StatusServiceUnavailable, "AI_DISABLED",
		"AI analysis is not enabled on this server.")
	ErrNotConfigured = apierror.New(http.StatusConflict, "AI_NOT_CONFIGURED",
		"Choose a provider, an API key and a model first.")
	ErrConsentRequired = apierror.New(http.StatusForbidden, "AI_CONSENT_REQUIRED",
		"Accept the AI analysis disclosure first.")
)

// Field codes used by the AI endpoints.
const (
	FieldProviderInvalid       = "AI_PROVIDER_INVALID"
	FieldBaseURLInvalid        = "AI_BASE_URL_INVALID"
	FieldBaseURLNotAllowed     = "AI_BASE_URL_NOT_ALLOWED"
	FieldTextTooLong           = "AI_TEXT_TOO_LONG"
	FieldOutOfRange            = "VALUE_OUT_OF_RANGE"
	FieldInvalidValue          = "INVALID_VALUE"
	FieldConsentVersionInvalid = "AI_CONSENT_VERSION_INVALID"
)

// providerAPIError maps a provider failure to the AI_PROVIDER_* error the
// client localizes. The provider's own (sanitized) explanation travels in
// the message, which only the key owner sees.
func providerAPIError(err error) *apierror.Error {
	var pe *provider.Error
	if !errors.As(err, &pe) {
		if errors.Is(err, provider.ErrBaseURLNotAllowed) {
			return apierror.NewValidation(map[string]string{"base_url": FieldBaseURLNotAllowed})
		}
		if errors.Is(err, provider.ErrBaseURLInvalid) {
			return apierror.NewValidation(map[string]string{"base_url": FieldBaseURLInvalid})
		}
		return apierror.New(http.StatusBadGateway, "AI_PROVIDER_ERROR", "The AI provider could not be reached.")
	}
	status, code := http.StatusBadGateway, "AI_PROVIDER_ERROR"
	switch pe.Kind {
	case provider.ErrInvalidKey:
		code = "AI_PROVIDER_INVALID_KEY"
	case provider.ErrRateLimited:
		status, code = http.StatusTooManyRequests, "AI_PROVIDER_RATE_LIMITED"
	case provider.ErrQuotaExceeded:
		code = "AI_PROVIDER_QUOTA_EXCEEDED"
	case provider.ErrContextTooLong:
		code = "AI_PROVIDER_CONTEXT_TOO_LONG"
	case provider.ErrModelNotFound:
		code = "AI_PROVIDER_MODEL_NOT_FOUND"
	case provider.ErrContentBlocked:
		code = "AI_PROVIDER_CONTENT_BLOCKED"
	case provider.ErrUnavailable:
		code = "AI_PROVIDER_UNAVAILABLE"
	case provider.ErrTimeout:
		status, code = http.StatusGatewayTimeout, "AI_PROVIDER_TIMEOUT"
	case provider.ErrNetwork:
		code = "AI_PROVIDER_UNREACHABLE"
	}
	message := pe.Message
	if message == "" {
		message = "The AI provider returned an error."
	}
	return apierror.New(status, code, message)
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}
