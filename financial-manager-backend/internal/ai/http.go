package ai

import (
	"encoding/json"
	"io"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/reqctx"
)

// maxJSONBody bounds every AI request body (instructions and context are
// at most a few KB).
const maxJSONBody = 64 << 10

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// Mount registers the JSON routes. r must already be behind the auth
// middleware and the normal request timeout.
func (h *Handler) Mount(r chi.Router) {
	r.Get("/v1/ai/settings", h.getSettings)
	r.Put("/v1/ai/settings", h.saveSettings)
	r.Post("/v1/ai/settings/test", h.testConnection)
	r.Post("/v1/ai/models", h.listModels)
	r.Delete("/v1/ai/credentials/{id}", h.deleteCredential)
	r.Put("/v1/ai/consent", h.acceptConsent)
	r.Delete("/v1/ai/consent", h.revokeConsent)
	r.Get("/v1/ai/context", h.getUserContext)
	r.Put("/v1/ai/context", h.saveUserContext)
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

// decodeJSON reads a bounded JSON body into dst.
func decodeJSON(r *http.Request, dst any) error {
	if err := json.NewDecoder(io.LimitReader(r.Body, maxJSONBody)).Decode(dst); err != nil {
		return apierror.ErrBadRequest
	}
	return nil
}

func userFrom(w http.ResponseWriter, r *http.Request) (uuid.UUID, bool) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
	}
	return userID, ok
}

func (h *Handler) getSettings(w http.ResponseWriter, r *http.Request) {
	userID, ok := userFrom(w, r)
	if !ok {
		return
	}
	resp, err := h.service.GetSettings(r.Context(), userID)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

type saveSettingsRequest struct {
	Provider           string   `json:"provider"`
	BaseURL            string   `json:"base_url"`
	Model              string   `json:"model"`
	APIKey             *string  `json:"api_key"`
	MaxOutputTokens    int      `json:"max_output_tokens"`
	InputPricePerMTok  *float64 `json:"input_price_per_mtok"`
	OutputPricePerMTok *float64 `json:"output_price_per_mtok"`
	Defaults           struct {
		IncludeTransactions bool `json:"include_transactions"`
		AnonymizeTitles     bool `json:"anonymize_titles"`
	} `json:"defaults"`
	Version int64 `json:"version"`
}

func (h *Handler) saveSettings(w http.ResponseWriter, r *http.Request) {
	userID, ok := userFrom(w, r)
	if !ok {
		return
	}
	var req saveSettingsRequest
	if err := decodeJSON(r, &req); err != nil {
		apierror.Write(w, r, err)
		return
	}
	resp, err := h.service.SaveSettings(r.Context(), SaveSettingsInput{
		UserID: userID, Provider: req.Provider, BaseURL: req.BaseURL, Model: req.Model, APIKey: req.APIKey,
		MaxOutputTokens: req.MaxOutputTokens, InputPricePerMTok: req.InputPricePerMTok,
		OutputPricePerMTok: req.OutputPricePerMTok, DefaultIncludeTransactions: req.Defaults.IncludeTransactions,
		DefaultAnonymizeTitles: req.Defaults.AnonymizeTitles, ExpectedVersion: req.Version,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

type probeRequest struct {
	Provider string `json:"provider"`
	BaseURL  string `json:"base_url"`
	APIKey   string `json:"api_key"`
	Model    string `json:"model"`
}

func (h *Handler) readProbe(w http.ResponseWriter, r *http.Request) (ProbeInput, bool) {
	userID, ok := userFrom(w, r)
	if !ok {
		return ProbeInput{}, false
	}
	var req probeRequest
	if r.ContentLength != 0 {
		if err := decodeJSON(r, &req); err != nil {
			apierror.Write(w, r, err)
			return ProbeInput{}, false
		}
	}
	return ProbeInput{UserID: userID, Provider: req.Provider, BaseURL: req.BaseURL, APIKey: req.APIKey, Model: req.Model}, true
}

func (h *Handler) testConnection(w http.ResponseWriter, r *http.Request) {
	in, ok := h.readProbe(w, r)
	if !ok {
		return
	}
	resp, err := h.service.TestConnection(r.Context(), in)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (h *Handler) listModels(w http.ResponseWriter, r *http.Request) {
	in, ok := h.readProbe(w, r)
	if !ok {
		return
	}
	models, err := h.service.ListModels(r.Context(), in)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"models": models})
}

func (h *Handler) deleteCredential(w http.ResponseWriter, r *http.Request) {
	userID, ok := userFrom(w, r)
	if !ok {
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		apierror.Write(w, r, apierror.ErrNotFound)
		return
	}
	if err := h.service.DeleteCredential(r.Context(), userID, id); err != nil {
		apierror.Write(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) acceptConsent(w http.ResponseWriter, r *http.Request) {
	userID, ok := userFrom(w, r)
	if !ok {
		return
	}
	var req struct {
		ConsentVersion int `json:"consent_version"`
	}
	if err := decodeJSON(r, &req); err != nil {
		apierror.Write(w, r, err)
		return
	}
	if err := h.service.AcceptConsent(r.Context(), userID, req.ConsentVersion); err != nil {
		apierror.Write(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) revokeConsent(w http.ResponseWriter, r *http.Request) {
	userID, ok := userFrom(w, r)
	if !ok {
		return
	}
	if err := h.service.RevokeConsent(r.Context(), userID); err != nil {
		apierror.Write(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) getUserContext(w http.ResponseWriter, r *http.Request) {
	userID, ok := userFrom(w, r)
	if !ok {
		return
	}
	resp, err := h.service.GetUserContext(r.Context(), userID)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

type saveUserContextRequest struct {
	HouseholdSize *int    `json:"household_size"`
	IncomeType    *string `json:"income_type"`
	AboutMe       *string `json:"about_me"`
	Goals         *string `json:"goals"`
	IgnoreNotes   *string `json:"ignore_notes"`
	ResponseStyle *string `json:"response_style"`
	Version       int64   `json:"version"`
}

func (h *Handler) saveUserContext(w http.ResponseWriter, r *http.Request) {
	userID, ok := userFrom(w, r)
	if !ok {
		return
	}
	var req saveUserContextRequest
	if err := decodeJSON(r, &req); err != nil {
		apierror.Write(w, r, err)
		return
	}
	resp, err := h.service.SaveUserContext(r.Context(), SaveUserContextInput{
		UserID: userID, HouseholdSize: req.HouseholdSize, IncomeType: req.IncomeType, AboutMe: req.AboutMe,
		Goals: req.Goals, IgnoreNotes: req.IgnoreNotes, ResponseStyle: req.ResponseStyle, ExpectedVersion: req.Version,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}
