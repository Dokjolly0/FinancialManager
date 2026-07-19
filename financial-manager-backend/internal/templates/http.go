package templates

import (
	"encoding/json"
	"net/http"
	"strconv"

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

// Mount registers /v1/transaction-templates routes. r must already be
// behind the auth middleware (plan.md section 14.6).
func (h *Handler) Mount(r chi.Router) {
	r.Get("/v1/transaction-templates", h.search)
	r.Post("/v1/transaction-templates", h.create)
	r.Patch("/v1/transaction-templates/{id}", h.update)
	r.Delete("/v1/transaction-templates/{id}", h.delete)
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

func parseOptionalUUID(raw string) (*uuid.UUID, bool) {
	if raw == "" {
		return nil, true
	}
	id, err := uuid.Parse(raw)
	if err != nil {
		return nil, false
	}
	return &id, true
}

func (h *Handler) search(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}

	query := r.URL.Query()
	limit := 10
	if raw := query.Get("limit"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil {
			limit = parsed
		}
	}

	list, err := h.service.Search(r.Context(), SearchInput{
		UserID: userID, Direction: query.Get("direction"), Query: query.Get("q"), Limit: limit,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"templates": list})
}

type templateRequest struct {
	Direction          string  `json:"direction"`
	Title              string  `json:"title"`
	DefaultCategoryID  string  `json:"default_category_id"`
	DefaultDescription *string `json:"default_description"`
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}

	var req templateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}
	categoryID, ok := parseOptionalUUID(req.DefaultCategoryID)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{"default_category_id": apierror.FieldInvalidUUID}))
		return
	}

	created, err := h.service.Create(r.Context(), CreateServiceInput{
		UserID: userID, Direction: req.Direction, Title: req.Title,
		DefaultCategoryID: categoryID, DefaultDescription: req.DefaultDescription,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, created)
}

func (h *Handler) update(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		apierror.Write(w, r, apierror.ErrNotFound)
		return
	}

	var req templateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}
	categoryID, ok := parseOptionalUUID(req.DefaultCategoryID)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{"default_category_id": apierror.FieldInvalidUUID}))
		return
	}

	updated, err := h.service.Update(r.Context(), UpdateServiceInput{
		UserID: userID, TemplateID: id, Title: req.Title,
		DefaultCategoryID: categoryID, DefaultDescription: req.DefaultDescription,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, updated)
}

func (h *Handler) delete(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		apierror.Write(w, r, apierror.ErrNotFound)
		return
	}

	if err := h.service.Delete(r.Context(), userID, id); err != nil {
		apierror.Write(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
