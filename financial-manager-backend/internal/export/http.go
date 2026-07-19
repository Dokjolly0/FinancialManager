package export

import (
	"encoding/json"
	"fmt"
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

// Mount registers /v1/me/export routes. r must already be behind the auth
// middleware.
func (h *Handler) Mount(r chi.Router) {
	r.Post("/v1/me/export", h.requestExport)
	r.Get("/v1/me/export/{export_id}", h.getExport)
	r.Get("/v1/me/export/{export_id}/download", h.downloadExport)
}

type recordResponse struct {
	ID           string  `json:"id"`
	Format       string  `json:"format"`
	Status       string  `json:"status"`
	ErrorMessage *string `json:"error_message,omitempty"`
	DownloadURL  *string `json:"download_url,omitempty"`
	CreatedAt    string  `json:"created_at"`
}

func toRecordResponse(rec Record) recordResponse {
	var url *string
	if rec.Status == StatusReady {
		u := fmt.Sprintf("/v1/me/export/%s/download", rec.ID)
		url = &u
	}
	return recordResponse{
		ID: rec.ID.String(), Format: rec.Format, Status: rec.Status,
		ErrorMessage: rec.ErrorMessage, DownloadURL: url,
		CreatedAt: rec.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
	}
}

type requestExportRequest struct {
	Format string `json:"format"`
}

func (h *Handler) requestExport(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}

	var req requestExportRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	record, err := h.service.RequestExport(r.Context(), userID, req.Format)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}

	writeJSON(w, http.StatusAccepted, toRecordResponse(record))
}

func (h *Handler) getExport(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}
	exportID, err := uuid.Parse(chi.URLParam(r, "export_id"))
	if err != nil {
		apierror.Write(w, r, apierror.ErrNotFound)
		return
	}

	record, err := h.service.GetExport(r.Context(), userID, exportID)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}

	writeJSON(w, http.StatusOK, toRecordResponse(record))
}

func (h *Handler) downloadExport(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}
	exportID, err := uuid.Parse(chi.URLParam(r, "export_id"))
	if err != nil {
		apierror.Write(w, r, apierror.ErrNotFound)
		return
	}

	record, content, err := h.service.DownloadContent(r.Context(), userID, exportID)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	defer content.Close()

	contentType := "text/csv"
	if record.Format == FormatJSON {
		contentType = "application/json"
	}
	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Content-Disposition", fmt.Sprintf(`attachment; filename="export-%s.%s"`, record.ID, record.Format))
	_, _ = io.Copy(w, content)
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}
