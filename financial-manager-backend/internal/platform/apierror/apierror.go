// Package apierror implements the uniform error envelope from plan.md
// section 10.6 so every handler returns errors the same shape:
//
//	{"error": {"code": "...", "message": "...", "field_errors": {...}, "request_id": "..."}}
package apierror

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5/middleware"
)

// Error is a domain error carrying everything needed to render the
// section 10.6 envelope. Handlers return *Error (or wrap one) instead of
// writing HTTP responses directly.
type Error struct {
	Status      int
	Code        string
	Message     string
	FieldErrors map[string]string
}

func (e *Error) Error() string { return e.Message }

func New(status int, code, message string) *Error {
	return &Error{Status: status, Code: code, Message: message}
}

func NewValidation(fieldErrors map[string]string) *Error {
	return &Error{
		Status:      http.StatusUnprocessableEntity,
		Code:        "VALIDATION_ERROR",
		Message:     "The request contains invalid data.",
		FieldErrors: fieldErrors,
	}
}

var (
	ErrBadRequest    = New(http.StatusBadRequest, "BAD_REQUEST", "Malformed request.")
	ErrUnauthorized  = New(http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required or invalid.")
	ErrForbidden     = New(http.StatusForbidden, "FORBIDDEN", "Operation not allowed.")
	ErrNotFound      = New(http.StatusNotFound, "NOT_FOUND", "Resource not found.")
	ErrConflict      = New(http.StatusConflict, "CONFLICT", "The resource has changed from what was expected.")
	ErrRateLimited   = New(http.StatusTooManyRequests, "RATE_LIMITED", "Too many attempts. Try again later.")
	ErrInternal      = New(http.StatusInternalServerError, "INTERNAL_ERROR", "An internal error occurred.")
	ErrEmailInUse    = New(http.StatusConflict, "EMAIL_IN_USE", "Email already registered.")
	ErrUsernameInUse = New(http.StatusConflict, "USERNAME_IN_USE", "Username already in use.")
	ErrInvalidLogin  = New(http.StatusUnauthorized, "INVALID_CREDENTIALS", "Invalid credentials.")
)

// Field-error codes: reusable, machine-readable identifiers for
// FieldErrors values. Clients (e.g. the Flutter app) localize these
// instead of displaying server-generated text, so the code — not any
// message — is the stable contract. Reuse one constant across every call
// site that reports the same validation failure; add a one-off inline
// string only for a message so specific to a single field that sharing a
// code would lose meaning (e.g. "CATEGORY_NOT_FOUND").
const (
	FieldRequired              = "REQUIRED_FIELD"
	FieldUsernameLength        = "USERNAME_LENGTH_INVALID"
	FieldInvalidEmail          = "INVALID_EMAIL"
	FieldPasswordTooShort      = "PASSWORD_TOO_SHORT"
	FieldPasswordMismatch      = "PASSWORDS_DO_NOT_MATCH"
	FieldInvalidColorFormat    = "INVALID_COLOR_FORMAT"
	FieldNegativeNotAllowed    = "NEGATIVE_NOT_ALLOWED"
	FieldCurrencyNotSupported  = "CURRENCY_NOT_SUPPORTED"
	FieldTermsNotAccepted      = "TERMS_NOT_ACCEPTED"
	FieldInvalidUUID           = "INVALID_UUID"
	FieldInvalidDirection      = "INVALID_DIRECTION"
	FieldAmountNotPositive     = "AMOUNT_NOT_POSITIVE"
	FieldAmountImplausible     = "AMOUNT_IMPLAUSIBLE"
	FieldTitleLength           = "TITLE_LENGTH_INVALID"
	FieldCurrencyMismatch      = "CURRENCY_MISMATCH"
	FieldMustBeInteger         = "MUST_BE_INTEGER"
	FieldInvalidRFC3339Date    = "INVALID_RFC3339_DATE"
	FieldInvalidCategoryScope  = "INVALID_CATEGORY_SCOPE"
	FieldCategoryNameLength    = "CATEGORY_NAME_LENGTH_INVALID"
	FieldInvalidTheme          = "INVALID_THEME"
	FieldInvalidFirstDayOfWeek = "INVALID_FIRST_DAY_OF_WEEK"
	FieldInvalidExportFormat   = "INVALID_EXPORT_FORMAT"
	FieldInvalidTimezone       = "INVALID_TIMEZONE"
	FieldInvalidPreset         = "INVALID_PRESET"
	FieldCustomRangeRequired   = "CUSTOM_RANGE_REQUIRED"
	FieldInvalidGroupBy        = "INVALID_GROUP_BY"
	FieldInvalidMediaKind      = "INVALID_MEDIA_KIND"
	FieldProviderNotSupported  = "PROVIDER_NOT_SUPPORTED"
)

// Write renders err as the section 10.6 JSON envelope. Any error that is
// not an *Error is logged by the caller and rendered as a generic 500 —
// internal details are never leaked to the client.
func Write(w http.ResponseWriter, r *http.Request, err error) {
	var apiErr *Error
	if !errors.As(err, &apiErr) {
		apiErr = ErrInternal
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(apiErr.Status)

	_ = json.NewEncoder(w).Encode(map[string]any{
		"error": map[string]any{
			"code":         apiErr.Code,
			"message":      apiErr.Message,
			"field_errors": apiErr.FieldErrors,
			"request_id":   middleware.GetReqID(r.Context()),
		},
	})
}
