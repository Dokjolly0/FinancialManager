package auth

import (
	"crypto/sha256"
	"encoding/json"
	"io"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/reqctx"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// MountPublic registers routes that do not require an access token.
func (h *Handler) MountPublic(r chi.Router) {
	r.Post("/v1/auth/register", h.register)
	r.Post("/v1/auth/login", h.login)
	r.Post("/v1/auth/refresh", h.refresh)
	r.Post("/v1/auth/password/forgot", h.forgotPassword)
	r.Post("/v1/auth/password/reset", h.resetPassword)
	r.Post("/v1/auth/email/verify", h.verifyEmail)
}

// MountProtected registers routes that require the auth middleware.
func (h *Handler) MountProtected(r chi.Router) {
	r.Post("/v1/auth/logout", h.logout)
	r.Post("/v1/auth/logout-all", h.logoutAll)
	r.Post("/v1/auth/email/resend-verification", h.resendVerification)
}

func clientIPHash(r *http.Request) []byte {
	sum := sha256.Sum256([]byte(r.RemoteAddr))
	return sum[:]
}

func stringPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

type registerRequest struct {
	FirstName             string `json:"first_name"`
	LastName              string `json:"last_name"`
	Username              string `json:"username"`
	Email                 string `json:"email"`
	Password              string `json:"password"`
	ConfirmPassword       string `json:"confirm_password"`
	AvatarBackgroundColor string `json:"avatar_background_color"`
	AvatarTextColor       string `json:"avatar_text_color"`
	InitialBalanceMinor   int64  `json:"initial_balance_minor"`
	Currency              string `json:"currency"`
	Timezone              string `json:"timezone"`
	Locale                string `json:"locale"`
	AcceptedTerms         bool   `json:"accepted_terms"`
	DeviceName            string `json:"device_name"`
	Platform              string `json:"platform"`
}

func (h *Handler) register(w http.ResponseWriter, r *http.Request) {
	idempotencyKey, err := uuid.Parse(r.Header.Get("Idempotency-Key"))
	if err != nil {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{
			"Idempotency-Key": "Header obbligatorio, deve essere un UUID.",
		}))
		return
	}

	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	var req registerRequest
	if err := json.Unmarshal(body, &req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	responseBody, status, err := h.service.Register(r.Context(), RegisterInput{
		FirstName:             req.FirstName,
		LastName:              req.LastName,
		Username:              req.Username,
		Email:                 req.Email,
		Password:              req.Password,
		ConfirmPassword:       req.ConfirmPassword,
		AvatarBackgroundColor: req.AvatarBackgroundColor,
		AvatarTextColor:       req.AvatarTextColor,
		InitialBalanceMinor:   req.InitialBalanceMinor,
		Currency:              req.Currency,
		Timezone:              req.Timezone,
		Locale:                req.Locale,
		AcceptedTerms:         req.AcceptedTerms,
		DeviceName:            stringPtr(req.DeviceName),
		Platform:              stringPtr(req.Platform),
		IdempotencyKey:        idempotencyKey,
		RequestBody:           body,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = w.Write(responseBody)
}

type loginRequest struct {
	UsernameOrEmail string `json:"username_or_email"`
	Password        string `json:"password"`
	DeviceName      string `json:"device_name"`
	Platform        string `json:"platform"`
}

func (h *Handler) login(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	resp, err := h.service.Login(r.Context(), LoginInput{
		UsernameOrEmail: req.UsernameOrEmail,
		Password:        req.Password,
		DeviceName:      stringPtr(req.DeviceName),
		Platform:        stringPtr(req.Platform),
		ClientIPHash:    clientIPHash(r),
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

func (h *Handler) refresh(w http.ResponseWriter, r *http.Request) {
	var req refreshRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.RefreshToken == "" {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	result, err := h.service.Refresh(r.Context(), req.RefreshToken)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"access_token":       result.AccessToken,
		"refresh_token":      result.RefreshToken,
		"expires_in_seconds": result.ExpiresIn,
	})
}

func (h *Handler) logout(w http.ResponseWriter, r *http.Request) {
	sessionID, ok := reqctx.SessionID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}
	if err := h.service.Logout(r.Context(), sessionID); err != nil {
		apierror.Write(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) logoutAll(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}
	if err := h.service.LogoutAll(r.Context(), userID); err != nil {
		apierror.Write(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type forgotPasswordRequest struct {
	Email string `json:"email"`
}

func (h *Handler) forgotPassword(w http.ResponseWriter, r *http.Request) {
	var req forgotPasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}
	if err := h.service.ForgotPassword(r.Context(), req.Email); err != nil {
		apierror.Write(w, r, err)
		return
	}
	// Always 202: never reveal whether the account exists.
	w.WriteHeader(http.StatusAccepted)
}

type resetPasswordRequest struct {
	Token       string `json:"token"`
	NewPassword string `json:"new_password"`
}

func (h *Handler) resetPassword(w http.ResponseWriter, r *http.Request) {
	var req resetPasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}
	if err := h.service.ResetPassword(r.Context(), req.Token, req.NewPassword); err != nil {
		apierror.Write(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type verifyEmailRequest struct {
	Token string `json:"token"`
}

func (h *Handler) verifyEmail(w http.ResponseWriter, r *http.Request) {
	var req verifyEmailRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}
	if err := h.service.VerifyEmail(r.Context(), req.Token); err != nil {
		apierror.Write(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) resendVerification(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}
	if err := h.service.ResendVerification(r.Context(), userID); err != nil {
		apierror.Write(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}
