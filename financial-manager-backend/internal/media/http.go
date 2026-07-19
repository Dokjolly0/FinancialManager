package media

import (
	"encoding/json"
	"io"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/reqctx"
)

type Handler struct {
	service        *Service
	maxUploadBytes int64
}

func NewHandler(service *Service, maxUploadBytes int64) *Handler {
	return &Handler{service: service, maxUploadBytes: maxUploadBytes}
}

// Mount registers /v1/media routes. r must already be behind the auth
// middleware (plan.md section 14.8).
func (h *Handler) Mount(r chi.Router) {
	r.Get("/v1/media", h.list)
	r.Get("/v1/media/search", h.search)
	r.Post("/v1/media/uploads", h.upload)
	r.Get("/v1/media/{id}", h.getContent)
	r.Patch("/v1/media/{id}", h.rename)
	r.Delete("/v1/media/{id}", h.delete)
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

	query := r.URL.Query()
	limit := 40
	if raw := query.Get("limit"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil {
			limit = parsed
		}
	}

	list, err := h.service.List(r.Context(), userID, query.Get("kind"), query.Get("sort") == "recent", limit, query.Get("q"))
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"media": list})
}

func (h *Handler) search(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}

	query := r.URL.Query()
	page, _ := strconv.Atoi(query.Get("page"))
	limit, _ := strconv.Atoi(query.Get("limit"))

	results, err := h.service.Search(r.Context(), SearchInput{UserID: userID, Query: query.Get("q"), Page: page, Limit: limit})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"results": results})
}

func parseCropForm(r *http.Request) *CropRect {
	x := r.FormValue("crop_x")
	y := r.FormValue("crop_y")
	width := r.FormValue("crop_width")
	height := r.FormValue("crop_height")
	if x == "" && y == "" && width == "" && height == "" {
		return nil
	}
	crop := &CropRect{}
	crop.X, _ = strconv.ParseFloat(x, 64)
	crop.Y, _ = strconv.ParseFloat(y, 64)
	crop.Width, _ = strconv.ParseFloat(width, 64)
	crop.Height, _ = strconv.ParseFloat(height, 64)
	crop.RotationDegrees, _ = strconv.ParseFloat(r.FormValue("crop_rotation_degrees"), 64)
	return crop
}

type selectFromSearchRequest struct {
	Kind       string `json:"kind"`
	Provider   string `json:"provider"`
	ExternalID string `json:"external_id"`
	Crop       *struct {
		X               float64 `json:"x"`
		Y               float64 `json:"y"`
		Width           float64 `json:"width"`
		Height          float64 `json:"height"`
		RotationDegrees float64 `json:"rotation_degrees"`
	} `json:"crop"`
}

// upload handles both direct file uploads (multipart/form-data) and
// selecting a search result (application/json) — plan.md section 14.8
// lists a single POST /v1/media/uploads endpoint for media creation, and
// both flows funnel into the same crop/resize/store pipeline.
func (h *Handler) upload(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}

	contentType := r.Header.Get("Content-Type")
	if strings.HasPrefix(contentType, "application/json") {
		h.uploadFromSearch(w, r, userID)
		return
	}
	h.uploadFromFile(w, r, userID)
}

func (h *Handler) uploadFromFile(w http.ResponseWriter, r *http.Request, userID uuid.UUID) {
	r.Body = http.MaxBytesReader(w, r.Body, h.maxUploadBytes+1<<20) // +1MiB slack for multipart overhead/other fields
	if err := r.ParseMultipartForm(h.maxUploadBytes + 1<<20); err != nil {
		apierror.Write(w, r, apierror.New(http.StatusRequestEntityTooLarge, "UPLOAD_TOO_LARGE", "The file exceeds the maximum allowed size."))
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{"file": apierror.FieldRequired}))
		return
	}
	defer file.Close()

	content, err := io.ReadAll(io.LimitReader(file, h.maxUploadBytes+1))
	if err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	asset, err := h.service.Upload(r.Context(), UploadInput{
		OwnerUserID: userID, Kind: r.FormValue("kind"), Content: content,
		OriginalFilename: header.Filename, Crop: parseCropForm(r),
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, asset)
}

func (h *Handler) uploadFromSearch(w http.ResponseWriter, r *http.Request, userID uuid.UUID) {
	var req selectFromSearchRequest
	if err := json.NewDecoder(io.LimitReader(r.Body, 1<<16)).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	var crop *CropRect
	if req.Crop != nil {
		crop = &CropRect{
			X: req.Crop.X, Y: req.Crop.Y, Width: req.Crop.Width, Height: req.Crop.Height,
			RotationDegrees: req.Crop.RotationDegrees,
		}
	}

	asset, err := h.service.SelectFromSearch(r.Context(), SelectFromSearchInput{
		OwnerUserID: userID, Kind: req.Kind, Provider: req.Provider, ExternalID: req.ExternalID, Crop: crop,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, asset)
}

func (h *Handler) getContent(w http.ResponseWriter, r *http.Request) {
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

	asset, content, err := h.service.GetContent(r.Context(), userID, id)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	defer content.Close()

	// plan.md section 16.7 MVP distribution: authenticated endpoint,
	// private cache, ownership already checked by GetContent.
	w.Header().Set("Content-Type", asset.MimeType)
	w.Header().Set("Cache-Control", "private, max-age=86400")
	_, _ = io.Copy(w, content)
}

type renameRequest struct {
	Name string `json:"name"`
}

func (h *Handler) rename(w http.ResponseWriter, r *http.Request) {
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

	var req renameRequest
	if err := json.NewDecoder(io.LimitReader(r.Body, 1<<16)).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	asset, err := h.service.Rename(r.Context(), RenameInput{OwnerUserID: userID, ID: id, Name: req.Name})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, asset)
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
