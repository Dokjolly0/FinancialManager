package users

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"

	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/reqctx"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// Mount registers /v1/me routes. r must already be behind the auth
// middleware (plan.md section 19.1: every endpoint using an ID must
// resolve it from the authenticated session, never trust a client-supplied id).
func (h *Handler) Mount(r chi.Router) {
	r.Get("/v1/me", h.getMe)
	r.Patch("/v1/me", h.updateMe)
}

type userResponse struct {
	ID                   string  `json:"id"`
	FirstName            string  `json:"first_name"`
	LastName             string  `json:"last_name"`
	Username             string  `json:"username"`
	Email                string  `json:"email"`
	EmailVerified        bool    `json:"email_verified"`
	AvatarMode           string  `json:"avatar_mode"`
	AvatarMediaID        *string `json:"avatar_media_id,omitempty"`
	AvatarBgColor        string  `json:"avatar_background_color"`
	AvatarTxtColor       string  `json:"avatar_text_color"`
	Locale               string  `json:"locale"`
	Timezone             string  `json:"timezone"`
	Theme                string  `json:"theme"`
	BalanceHiddenDefault bool    `json:"balance_hidden_default"`
	FirstDayOfWeek       string  `json:"first_day_of_week"`
	Version              int64   `json:"version"`
	CreatedAt            string  `json:"created_at"`
}

func toUserResponse(u User) userResponse {
	var mediaID *string
	if u.AvatarMediaID != nil {
		s := u.AvatarMediaID.String()
		mediaID = &s
	}
	return userResponse{
		ID:                   u.ID.String(),
		FirstName:            u.FirstName,
		LastName:             u.LastName,
		Username:             u.Username,
		Email:                u.Email,
		EmailVerified:        u.EmailVerified(),
		AvatarMode:           u.AvatarMode,
		AvatarMediaID:        mediaID,
		AvatarBgColor:        u.AvatarBackgroundColor,
		AvatarTxtColor:       u.AvatarTextColor,
		Locale:               u.Locale,
		Timezone:             u.Timezone,
		Theme:                u.Theme,
		BalanceHiddenDefault: u.BalanceHiddenDefault,
		FirstDayOfWeek:       u.FirstDayOfWeek,
		Version:              u.Version,
		CreatedAt:            u.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
	}
}

func (h *Handler) getMe(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}

	user, err := h.service.GetProfile(r.Context(), userID)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}

	writeJSON(w, http.StatusOK, toUserResponse(user))
}

type updateMeRequest struct {
	FirstName            string `json:"first_name"`
	LastName             string `json:"last_name"`
	Timezone             string `json:"timezone"`
	Locale               string `json:"locale"`
	Theme                string `json:"theme"`
	BalanceHiddenDefault bool   `json:"balance_hidden_default"`
	FirstDayOfWeek       string `json:"first_day_of_week"`
	ExpectedVersion      int64  `json:"version"`
}

func (h *Handler) updateMe(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}

	var req updateMeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	fieldErrors := map[string]string{}
	if req.FirstName == "" {
		fieldErrors["first_name"] = "Campo obbligatorio."
	}
	if req.LastName == "" {
		fieldErrors["last_name"] = "Campo obbligatorio."
	}
	if req.Theme != "system" && req.Theme != "light" && req.Theme != "dark" {
		fieldErrors["theme"] = "Deve essere system, light o dark."
	}
	if req.FirstDayOfWeek != FirstDayOfWeekMonday && req.FirstDayOfWeek != FirstDayOfWeekSunday {
		fieldErrors["first_day_of_week"] = "Deve essere monday o sunday."
	}
	if len(fieldErrors) > 0 {
		apierror.Write(w, r, apierror.NewValidation(fieldErrors))
		return
	}

	updated, err := h.service.UpdateProfile(r.Context(), userID, UpdateProfileInput{
		FirstName:            req.FirstName,
		LastName:             req.LastName,
		Timezone:             req.Timezone,
		Locale:               req.Locale,
		Theme:                req.Theme,
		BalanceHiddenDefault: req.BalanceHiddenDefault,
		FirstDayOfWeek:       req.FirstDayOfWeek,
		ExpectedVersion:      req.ExpectedVersion,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}

	writeJSON(w, http.StatusOK, toUserResponse(updated))
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}
