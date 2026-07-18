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
		Message:     "La richiesta contiene dati non validi.",
		FieldErrors: fieldErrors,
	}
}

var (
	ErrBadRequest    = New(http.StatusBadRequest, "BAD_REQUEST", "Richiesta malformata.")
	ErrUnauthorized  = New(http.StatusUnauthorized, "UNAUTHORIZED", "Autenticazione richiesta o non valida.")
	ErrForbidden     = New(http.StatusForbidden, "FORBIDDEN", "Operazione non consentita.")
	ErrNotFound      = New(http.StatusNotFound, "NOT_FOUND", "Risorsa non trovata.")
	ErrConflict      = New(http.StatusConflict, "CONFLICT", "La risorsa è cambiata rispetto a quanto atteso.")
	ErrRateLimited   = New(http.StatusTooManyRequests, "RATE_LIMITED", "Troppi tentativi. Riprova più tardi.")
	ErrInternal      = New(http.StatusInternalServerError, "INTERNAL_ERROR", "Si è verificato un errore interno.")
	ErrEmailInUse    = New(http.StatusConflict, "EMAIL_IN_USE", "Email già registrata.")
	ErrUsernameInUse = New(http.StatusConflict, "USERNAME_IN_USE", "Nome utente già in uso.")
	ErrInvalidLogin  = New(http.StatusUnauthorized, "INVALID_CREDENTIALS", "Credenziali non valide.")
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
