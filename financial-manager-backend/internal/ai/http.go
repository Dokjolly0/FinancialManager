package ai

import (
	"encoding/json"
	"io"
	"net/http"
	"strconv"

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
	r.Put("/v1/ai/mode", h.setMode)
	r.Put("/v1/ai/consent", h.acceptConsent)
	r.Delete("/v1/ai/consent", h.revokeConsent)
	r.Get("/v1/ai/context", h.getUserContext)
	r.Put("/v1/ai/context", h.saveUserContext)
	r.Get("/v1/ai/presets", h.presets)
	r.Post("/v1/ai/analyses/preview", h.preview)
	r.Get("/v1/ai/analyses", h.listAnalyses)
	r.Delete("/v1/ai/analyses", h.deleteAllAnalyses)
	r.Get("/v1/ai/analyses/{id}", h.getAnalysis)
	r.Patch("/v1/ai/analyses/{id}", h.renameAnalysis)
	r.Delete("/v1/ai/analyses/{id}", h.deleteAnalysis)

	// On-device analyses (plan.md section 33): the phone generates, these
	// only store and replay, so they keep the normal request timeout.
	r.Post("/v1/ai/local/analyses", h.prepareLocalAnalysis)
	r.Post("/v1/ai/local/analyses/{id}/messages", h.prepareLocalFollowUp)
	r.Put("/v1/ai/analyses/{id}/messages/{messageId}/result", h.submitLocalResult)
}

// MountStreaming registers the two Server-Sent Events routes. r must be
// behind the auth middleware but NOT the normal request timeout: streams
// are bounded by AI_STREAM_MAX_DURATION instead (plan.md section 32.4).
func (h *Handler) MountStreaming(r chi.Router) {
	r.Post("/v1/ai/analyses", h.runAnalysis)
	r.Post("/v1/ai/analyses/{id}/messages", h.askFollowUp)
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

// decodeJSON reads a bounded JSON body into dst.
func decodeJSON(r *http.Request, dst any) error {
	return decodeJSONLimit(r, dst, maxJSONBody)
}

// maxResultBody fits a 200 KB answer plus JSON escaping.
const maxResultBody = 512 << 10

func decodeJSONLimit(r *http.Request, dst any, limit int64) error {
	if err := json.NewDecoder(io.LimitReader(r.Body, limit)).Decode(dst); err != nil {
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
		ConsentVersion int    `json:"consent_version"`
		Scope          string `json:"scope"`
	}
	if err := decodeJSON(r, &req); err != nil {
		apierror.Write(w, r, err)
		return
	}
	if err := h.service.AcceptConsent(r.Context(), userID, req.Scope, req.ConsentVersion); err != nil {
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
	if err := h.service.RevokeConsent(r.Context(), userID, r.URL.Query().Get("scope")); err != nil {
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

func (h *Handler) presets(w http.ResponseWriter, r *http.Request) {
	userID, ok := userFrom(w, r)
	if !ok {
		return
	}
	list, err := h.service.Presets(r.Context(), userID)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"presets": list})
}

func (h *Handler) preview(w http.ResponseWriter, r *http.Request) {
	userID, ok := userFrom(w, r)
	if !ok {
		return
	}
	var req AnalysisRequest
	if err := decodeJSON(r, &req); err != nil {
		apierror.Write(w, r, err)
		return
	}
	resp, err := h.service.Preview(r.Context(), userID, req)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (h *Handler) runAnalysis(w http.ResponseWriter, r *http.Request) {
	userID, ok := userFrom(w, r)
	if !ok {
		return
	}
	var req RunRequest
	if err := decodeJSON(r, &req); err != nil {
		apierror.Write(w, r, err)
		return
	}
	turn, err := h.service.PrepareAnalysis(r.Context(), userID, req)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	sse := NewSSEWriter(w)
	defer sse.Close()
	h.service.StreamTurn(r.Context(), sse, turn)
}

func (h *Handler) askFollowUp(w http.ResponseWriter, r *http.Request) {
	userID, id, ok := h.analysisID(w, r)
	if !ok {
		return
	}
	var req struct {
		Content string `json:"content"`
	}
	if err := decodeJSON(r, &req); err != nil {
		apierror.Write(w, r, err)
		return
	}
	turn, err := h.service.PrepareFollowUp(r.Context(), userID, id, req.Content)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	sse := NewSSEWriter(w)
	defer sse.Close()
	h.service.StreamTurn(r.Context(), sse, turn)
}

func (h *Handler) listAnalyses(w http.ResponseWriter, r *http.Request) {
	userID, ok := userFrom(w, r)
	if !ok {
		return
	}
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	page, err := h.service.ListAnalyses(r.Context(), userID, r.URL.Query().Get("cursor"), limit)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, page)
}

func (h *Handler) analysisID(w http.ResponseWriter, r *http.Request) (uuid.UUID, uuid.UUID, bool) {
	userID, ok := userFrom(w, r)
	if !ok {
		return uuid.Nil, uuid.Nil, false
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		apierror.Write(w, r, apierror.ErrNotFound)
		return uuid.Nil, uuid.Nil, false
	}
	return userID, id, true
}

func (h *Handler) getAnalysis(w http.ResponseWriter, r *http.Request) {
	userID, id, ok := h.analysisID(w, r)
	if !ok {
		return
	}
	detail, err := h.service.GetAnalysis(r.Context(), userID, id)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, detail)
}

func (h *Handler) renameAnalysis(w http.ResponseWriter, r *http.Request) {
	userID, id, ok := h.analysisID(w, r)
	if !ok {
		return
	}
	var req struct {
		Title string `json:"title"`
	}
	if err := decodeJSON(r, &req); err != nil {
		apierror.Write(w, r, err)
		return
	}
	detail, err := h.service.RenameAnalysis(r.Context(), userID, id, req.Title)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, detail)
}

func (h *Handler) deleteAnalysis(w http.ResponseWriter, r *http.Request) {
	userID, id, ok := h.analysisID(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteAnalysis(r.Context(), userID, id); err != nil {
		apierror.Write(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) deleteAllAnalyses(w http.ResponseWriter, r *http.Request) {
	userID, ok := userFrom(w, r)
	if !ok {
		return
	}
	if err := h.service.DeleteAllAnalyses(r.Context(), userID); err != nil {
		apierror.Write(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) setMode(w http.ResponseWriter, r *http.Request) {
	userID, ok := userFrom(w, r)
	if !ok {
		return
	}
	var req struct {
		Mode       string  `json:"mode"`
		LocalModel *string `json:"local_model"`
		Version    int64   `json:"version"`
	}
	if err := decodeJSON(r, &req); err != nil {
		apierror.Write(w, r, err)
		return
	}
	resp, err := h.service.SetMode(r.Context(), userID, req.Mode, req.LocalModel, req.Version)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (h *Handler) prepareLocalAnalysis(w http.ResponseWriter, r *http.Request) {
	userID, ok := userFrom(w, r)
	if !ok {
		return
	}
	var req LocalRunRequest
	if err := decodeJSON(r, &req); err != nil {
		apierror.Write(w, r, err)
		return
	}
	resp, created, err := h.service.PrepareLocalAnalysis(r.Context(), userID, req)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	status := http.StatusOK
	if created {
		status = http.StatusCreated
	}
	writeJSON(w, status, resp)
}

func (h *Handler) prepareLocalFollowUp(w http.ResponseWriter, r *http.Request) {
	userID, id, ok := h.analysisID(w, r)
	if !ok {
		return
	}
	var req struct {
		Content string `json:"content"`
	}
	if err := decodeJSON(r, &req); err != nil {
		apierror.Write(w, r, err)
		return
	}
	resp, err := h.service.PrepareLocalFollowUp(r.Context(), userID, id, req.Content)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, resp)
}

func (h *Handler) submitLocalResult(w http.ResponseWriter, r *http.Request) {
	userID, id, ok := h.analysisID(w, r)
	if !ok {
		return
	}
	messageID, err := uuid.Parse(chi.URLParam(r, "messageId"))
	if err != nil {
		apierror.Write(w, r, apierror.ErrNotFound)
		return
	}
	var req LocalResult
	if err := decodeJSONLimit(r, &req, maxResultBody); err != nil {
		apierror.Write(w, r, err)
		return
	}
	resp, err := h.service.SubmitLocalResult(r.Context(), userID, id, messageID, req)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}
