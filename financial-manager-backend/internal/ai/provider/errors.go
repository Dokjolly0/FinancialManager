package provider

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"unicode/utf8"
)

// ErrorKind is the provider-independent category of a failure, mapped to
// the AI_PROVIDER_* error codes by the ai package.
type ErrorKind string

const (
	ErrInvalidKey     ErrorKind = "INVALID_KEY"
	ErrRateLimited    ErrorKind = "RATE_LIMITED"
	ErrQuotaExceeded  ErrorKind = "QUOTA_EXCEEDED"
	ErrContextTooLong ErrorKind = "CONTEXT_TOO_LONG"
	ErrModelNotFound  ErrorKind = "MODEL_NOT_FOUND"
	ErrContentBlocked ErrorKind = "CONTENT_BLOCKED"
	ErrUnavailable    ErrorKind = "UNAVAILABLE"
	ErrTimeout        ErrorKind = "TIMEOUT"
	ErrNetwork        ErrorKind = "NETWORK"
	ErrBadResponse    ErrorKind = "BAD_RESPONSE"
)

// Error is a classified provider failure. Message is the provider's own
// explanation, truncated and with anything key-shaped redacted, safe to
// log and to show to the user who owns the key.
type Error struct {
	Kind    ErrorKind
	Status  int
	Message string
}

func (e *Error) Error() string {
	if e.Status != 0 {
		return fmt.Sprintf("provider error %s (HTTP %d): %s", e.Kind, e.Status, e.Message)
	}
	return fmt.Sprintf("provider error %s: %s", e.Kind, e.Message)
}

const maxErrorMessageRunes = 300

var secretPattern = regexp.MustCompile(`(sk-[A-Za-z0-9_\-]{6,}|AIza[0-9A-Za-z_\-]{10,}|gsk_[A-Za-z0-9]{10,})`)

// sanitizeMessage truncates and redacts provider text before it is logged
// or returned.
func sanitizeMessage(s string) string {
	s = strings.TrimSpace(secretPattern.ReplaceAllString(s, "[redacted]"))
	if utf8.RuneCountInString(s) > maxErrorMessageRunes {
		s = string([]rune(s)[:maxErrorMessageRunes]) + "…"
	}
	return s
}

// providerMessage extracts error.message (OpenAI, Anthropic, Gemini and
// most compatible servers), falling back to the raw body.
func providerMessage(body []byte) string {
	var envelope struct {
		Error json.RawMessage `json:"error"`
	}
	if json.Unmarshal(body, &envelope) == nil && len(envelope.Error) > 0 {
		var obj struct {
			Message string `json:"message"`
		}
		if json.Unmarshal(envelope.Error, &obj) == nil && obj.Message != "" {
			return obj.Message
		}
		var str string
		if json.Unmarshal(envelope.Error, &str) == nil && str != "" {
			return str
		}
	}
	return string(body)
}

// classifyHTTP turns a non-2xx response into an *Error.
func classifyHTTP(status int, body []byte) *Error {
	message := providerMessage(body)
	lower := strings.ToLower(string(body))
	kind := ErrBadResponse

	switch {
	case containsAny(lower, "insufficient_quota", "credit balance", "billing", "exceeded your current quota", "quota exceeded"):
		kind = ErrQuotaExceeded
	case containsAny(lower, "context_length_exceeded", "prompt is too long", "maximum context length",
		"context window", "too many tokens", "exceeds the maximum number of tokens", "input is too long"):
		kind = ErrContextTooLong
	case containsAny(lower, "api key not valid", "api_key_invalid", "invalid api key", "invalid x-api-key", "incorrect api key"):
		kind = ErrInvalidKey
	case status == http.StatusUnauthorized || status == http.StatusForbidden:
		kind = ErrInvalidKey
	case status == http.StatusPaymentRequired:
		kind = ErrQuotaExceeded
	case status == http.StatusTooManyRequests:
		if containsAny(lower, "resource_exhausted") && containsAny(lower, "quota") {
			kind = ErrQuotaExceeded
		} else {
			kind = ErrRateLimited
		}
	case status == http.StatusNotFound || containsAny(lower, "model_not_found", "does not exist", "unknown model", "not found for api version"):
		kind = ErrModelNotFound
	case status == http.StatusRequestTimeout:
		kind = ErrTimeout
	case status >= 500:
		kind = ErrUnavailable
	}
	return &Error{Kind: kind, Status: status, Message: sanitizeMessage(message)}
}

func containsAny(s string, needles ...string) bool {
	for _, n := range needles {
		if strings.Contains(s, n) {
			return true
		}
	}
	return false
}

// errIdle is the cancellation cause set by the idle watchdog.
var errIdle = errors.New("provider stream idle")

// classifyTransport maps a transport failure. Cancellation by the caller
// is returned as ctx.Err() so the caller can tell it apart from a failure.
func classifyTransport(ctx context.Context, err error) error {
	if errors.Is(context.Cause(ctx), errIdle) {
		return &Error{Kind: ErrTimeout, Message: "the provider stopped sending data"}
	}
	if ctxErr := ctx.Err(); ctxErr != nil {
		if errors.Is(ctxErr, context.DeadlineExceeded) {
			return &Error{Kind: ErrTimeout, Message: "the request took too long"}
		}
		return ctxErr
	}
	var pe *Error
	if errors.As(err, &pe) {
		return pe
	}
	var blocked *blockedAddressError
	if errors.As(err, &blocked) {
		return blocked
	}
	if isTimeout(err) {
		return &Error{Kind: ErrTimeout, Message: "the provider did not answer in time"}
	}
	return &Error{Kind: ErrNetwork, Message: sanitizeMessage(err.Error())}
}

func isTimeout(err error) bool {
	var t interface{ Timeout() bool }
	return errors.As(err, &t) && t.Timeout()
}
