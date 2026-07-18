package categories

import (
	"encoding/json"
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

// Mount registers /v1/categories routes. r must already be behind the auth
// middleware (plan.md section 14.7).
func (h *Handler) Mount(r chi.Router) {
	r.Get("/v1/categories", h.list)
	r.Post("/v1/categories", h.create)
	r.Patch("/v1/categories/{id}", h.update)
	r.Delete("/v1/categories/{id}", h.delete)
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}

	list, err := h.service.List(r.Context(), userID)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"categories": list})
}

type categoryRequest struct {
	Name           string  `json:"name"`
	DirectionScope string  `json:"direction_scope"`
	Color          *string `json:"color"`
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}

	var req categoryRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	created, err := h.service.Create(r.Context(), CreateServiceInput{
		UserID: userID, Name: req.Name, DirectionScope: req.DirectionScope, Color: req.Color,
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

	var req categoryRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	updated, err := h.service.Update(r.Context(), UpdateServiceInput{
		UserID: userID, CategoryID: id, Name: req.Name, DirectionScope: req.DirectionScope, Color: req.Color,
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
