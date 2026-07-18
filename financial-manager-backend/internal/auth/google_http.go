package auth

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/reqctx"
)

// MountGooglePublic registers the unauthenticated Google sign-in routes.
func (h *Handler) MountGooglePublic(r chi.Router) {
	r.Post("/v1/auth/google/verify", h.googleVerify)
	r.Post("/v1/auth/google/complete-registration", h.completeGoogleRegistration)
}

// MountGoogleProtected registers the authenticated linked-identity routes
// (plan.md section 14.3).
func (h *Handler) MountGoogleProtected(r chi.Router) {
	r.Get("/v1/me/identities", h.listIdentities)
	r.Post("/v1/me/identities/google/link", h.linkGoogle)
	r.Delete("/v1/me/identities/google", h.unlinkGoogle)
}

type googleVerifyRequest struct {
	IDToken    string `json:"id_token"`
	DeviceName string `json:"device_name"`
	Platform   string `json:"platform"`
}

func (h *Handler) googleVerify(w http.ResponseWriter, r *http.Request) {
	var req googleVerifyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.IDToken == "" {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	result, err := h.service.GoogleVerify(r.Context(), GoogleVerifyInput{
		IDToken:    req.IDToken,
		DeviceName: stringPtr(req.DeviceName),
		Platform:   stringPtr(req.Platform),
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}

	if result.Authenticated {
		writeJSON(w, http.StatusOK, struct {
			Status string `json:"status"`
			AuthResponse
		}{Status: "authenticated", AuthResponse: result.Auth})
		return
	}

	writeJSON(w, http.StatusOK, struct {
		Status string `json:"status"`
		GoogleTicketResponse
	}{Status: "registration_required", GoogleTicketResponse: result.Ticket})
}

type completeGoogleRegistrationRequest struct {
	Ticket                string `json:"ticket"`
	Username              string `json:"username"`
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

func (h *Handler) completeGoogleRegistration(w http.ResponseWriter, r *http.Request) {
	var req completeGoogleRegistrationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	resp, err := h.service.CompleteGoogleRegistration(r.Context(), CompleteGoogleRegistrationInput{
		Ticket:                req.Ticket,
		Username:              req.Username,
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
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}

	writeJSON(w, http.StatusCreated, resp)
}

func (h *Handler) listIdentities(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}

	list, err := h.service.ListIdentities(r.Context(), userID)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}

	type identityResponse struct {
		Provider   string  `json:"provider"`
		LinkedAt   string  `json:"linked_at"`
		LastUsedAt *string `json:"last_used_at,omitempty"`
	}

	out := make([]identityResponse, 0, len(list))
	for _, identity := range list {
		var lastUsed *string
		if identity.LastUsedAt != nil {
			s := identity.LastUsedAt.Format("2006-01-02T15:04:05Z07:00")
			lastUsed = &s
		}
		out = append(out, identityResponse{
			Provider:   identity.Provider,
			LinkedAt:   identity.LinkedAt.Format("2006-01-02T15:04:05Z07:00"),
			LastUsedAt: lastUsed,
		})
	}

	writeJSON(w, http.StatusOK, map[string]any{"identities": out})
}

type linkGoogleRequest struct {
	IDToken         string `json:"id_token"`
	CurrentPassword string `json:"current_password"`
}

func (h *Handler) linkGoogle(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}

	var req linkGoogleRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	if err := h.service.LinkGoogle(r.Context(), userID, req.IDToken, req.CurrentPassword); err != nil {
		apierror.Write(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) unlinkGoogle(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}

	if err := h.service.UnlinkGoogle(r.Context(), userID); err != nil {
		apierror.Write(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
