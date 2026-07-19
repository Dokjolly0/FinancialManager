package media

import (
	"bytes"
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"io"
	"net/http"
	"path"
	"strings"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/metrics"
	"financial-manager-backend/internal/platform/ratelimit"
	"financial-manager-backend/internal/platform/storage"
)

// Rate limits for search/upload (plan.md section 19.5: "upload e ricerca
// immagini") — search hits an external provider per call, upload runs the
// decode/resize/re-encode pipeline, so both are worth bounding per user
// beyond just the shared decompression-bomb/size guards.
const (
	searchPerWindow = 30
	searchWindow    = time.Minute
	uploadPerWindow = 20
	uploadWindow    = time.Hour
)

type Service struct {
	repo        *Repository
	store       storage.Store
	search      ImageSearchProvider
	maxBytes    int64
	allowlist   map[string]bool
	rateLimiter *ratelimit.Limiter
}

type Deps struct {
	Repo              *Repository
	Store             storage.Store
	Search            ImageSearchProvider
	MaxUploadBytes    int64
	AllowedImageTypes []string
	RateLimiter       *ratelimit.Limiter
}

func NewService(d Deps) *Service {
	allowlist := make(map[string]bool, len(d.AllowedImageTypes))
	for _, t := range d.AllowedImageTypes {
		allowlist[t] = true
	}
	return &Service{
		repo: d.Repo, store: d.Store, search: d.Search, maxBytes: d.MaxUploadBytes,
		allowlist: allowlist, rateLimiter: d.RateLimiter,
	}
}

func (s *Service) checkRateLimit(ctx context.Context, scope string, ownerUserID uuid.UUID, limit int, window time.Duration) error {
	if s.rateLimiter == nil {
		return nil
	}
	result, err := s.rateLimiter.Allow(ctx, "ratelimit:media-"+scope+":user:"+ownerUserID.String(), limit, window)
	if err == nil && !result.Allowed {
		metrics.RateLimitTriggered.WithLabelValues("media-" + scope).Inc()
		if scope == "upload" {
			metrics.UploadsRejected.WithLabelValues("rate-limit").Inc()
		}
		return apierror.ErrRateLimited
	}
	return nil
}

type assetResponse struct {
	ID          string  `json:"id"`
	Kind        string  `json:"kind"`
	Source      string  `json:"source"`
	Attribution *string `json:"attribution,omitempty"`
	MimeType    string  `json:"mime_type"`
	Width       int     `json:"width"`
	Height      int     `json:"height"`
	URL         string  `json:"url"`
	CreatedAt   string  `json:"created_at"`
}

const timeLayout = "2006-01-02T15:04:05Z07:00"

func toAssetResponse(a Asset) assetResponse {
	return assetResponse{
		ID: a.ID.String(), Kind: a.Kind, Source: a.Source, Attribution: a.SourceAttribution,
		MimeType: a.MimeType, Width: a.Width, Height: a.Height,
		URL: "/v1/media/" + a.ID.String(), CreatedAt: a.CreatedAt.Format(timeLayout),
	}
}

func extensionFor(mimeType string) string {
	switch mimeType {
	case "image/png":
		return ".png"
	default:
		return ".jpg"
	}
}

// processAndStore is the shared pipeline behind both direct uploads and
// search-result selection (plan.md section 16.3): detect/validate the
// format, decode with decompression-bomb limits, apply the crop (or a
// centered-square fallback), resize to the kind's target size, re-encode
// (which also strips any EXIF/geolocation metadata — plan.md section 16.3
// step 7 — since neither image/jpeg nor image/png round-trip it), hash,
// and store — deduplicating against the user's existing assets by hash.
func (s *Service) processAndStore(
	ctx context.Context, ownerUserID uuid.UUID, kind, source string,
	sourceProvider, sourceExternalID, sourceAttribution, originalFilename *string,
	raw []byte, crop *CropRect,
) (assetResponse, error) {
	if !IsValidKind(kind) {
		return assetResponse{}, apierror.NewValidation(map[string]string{"kind": "Deve essere profile, transaction o category."})
	}

	if _, err := DetectMIME(raw); err != nil {
		metrics.UploadsRejected.WithLabelValues("format").Inc()
		return assetResponse{}, apierror.New(http.StatusUnprocessableEntity, "UNSUPPORTED_IMAGE_FORMAT",
			"Formato immagine non supportato. Usa JPEG, PNG o WebP.")
	}

	defer metrics.ObserveImageProcessingSince(time.Now())

	decoded, err := DecodeWithLimits(raw)
	if err != nil {
		if errors.Is(err, ErrImageTooLarge) {
			metrics.UploadsRejected.WithLabelValues("pixels").Inc()
			return assetResponse{}, apierror.New(http.StatusUnprocessableEntity, "IMAGE_TOO_LARGE", "L'immagine supera le dimensioni massime consentite.")
		}
		metrics.UploadsRejected.WithLabelValues("format").Inc()
		return assetResponse{}, apierror.New(http.StatusUnprocessableEntity, "UNSUPPORTED_IMAGE_FORMAT", "Impossibile decodificare l'immagine.")
	}

	cropped := ApplyCrop(decoded, crop)
	size := TargetSize(kind)
	resized := Resize(cropped, size)

	encoded, mimeType, err := Encode(resized)
	if err != nil {
		return assetResponse{}, fmt.Errorf("encode processed image: %w", err)
	}

	sum := sha256.Sum256(encoded)
	key := fmt.Sprintf("media/%s/%s%s", ownerUserID, uuid.New(), extensionFor(mimeType))

	if _, err := s.store.Put(ctx, key, bytes.NewReader(encoded), int64(len(encoded)), mimeType); err != nil {
		return assetResponse{}, fmt.Errorf("upload media to storage: %w", err)
	}

	asset, err := s.repo.CreateOrReuse(ctx, CreateInput{
		OwnerUserID: ownerUserID, Kind: kind, Source: source,
		SourceProvider: sourceProvider, SourceExternalID: sourceExternalID, SourceAttribution: sourceAttribution,
		ObjectKey: key, OriginalFilename: originalFilename, MimeType: mimeType,
		Width: size, Height: size, SizeBytes: int64(len(encoded)), SHA256: sum[:], Status: StatusReady,
	})
	if err != nil {
		_ = s.store.Delete(ctx, key)
		return assetResponse{}, fmt.Errorf("save media asset: %w", err)
	}
	if asset.ObjectKey != key {
		// Deduplicated onto an existing asset — the object we just wrote is redundant.
		_ = s.store.Delete(ctx, key)
	}

	return toAssetResponse(asset), nil
}

type UploadInput struct {
	OwnerUserID      uuid.UUID
	Kind             string
	Content          []byte
	OriginalFilename string
	Crop             *CropRect
}

func (s *Service) Upload(ctx context.Context, in UploadInput) (assetResponse, error) {
	if err := s.checkRateLimit(ctx, "upload", in.OwnerUserID, uploadPerWindow, uploadWindow); err != nil {
		return assetResponse{}, err
	}
	if int64(len(in.Content)) > s.maxBytes {
		metrics.UploadsRejected.WithLabelValues("size").Inc()
		return assetResponse{}, apierror.New(http.StatusRequestEntityTooLarge, "UPLOAD_TOO_LARGE", "Il file supera la dimensione massima consentita.")
	}
	var filename *string
	if in.OriginalFilename != "" {
		f := path.Base(in.OriginalFilename)
		filename = &f
	}
	return s.processAndStore(ctx, in.OwnerUserID, in.Kind, SourceUpload, nil, nil, nil, filename, in.Content, in.Crop)
}

type SelectFromSearchInput struct {
	OwnerUserID uuid.UUID
	Kind        string
	Provider    string
	ExternalID  string
	Crop        *CropRect
}

// SelectFromSearch fetches the actual image bytes only now — at selection
// time, not for every search result shown (plan.md section 16.6).
func (s *Service) SelectFromSearch(ctx context.Context, in SelectFromSearchInput) (assetResponse, error) {
	if err := s.checkRateLimit(ctx, "upload", in.OwnerUserID, uploadPerWindow, uploadWindow); err != nil {
		return assetResponse{}, err
	}
	if in.Provider != "unsplash" {
		return assetResponse{}, apierror.NewValidation(map[string]string{"provider": "Provider non supportato."})
	}

	reader, meta, err := s.search.Fetch(ctx, in.ExternalID)
	if err != nil {
		return assetResponse{}, apierror.New(http.StatusBadGateway, "IMAGE_FETCH_FAILED", "Impossibile scaricare l'immagine selezionata.")
	}
	defer reader.Close()

	content, err := io.ReadAll(io.LimitReader(reader, s.maxBytes+1))
	if err != nil {
		return assetResponse{}, fmt.Errorf("read fetched image: %w", err)
	}
	if int64(len(content)) > s.maxBytes {
		metrics.UploadsRejected.WithLabelValues("size").Inc()
		return assetResponse{}, apierror.New(http.StatusRequestEntityTooLarge, "UPLOAD_TOO_LARGE", "L'immagine selezionata supera la dimensione massima consentita.")
	}

	provider := in.Provider
	externalID := in.ExternalID
	attribution := meta.Attribution
	return s.processAndStore(ctx, in.OwnerUserID, in.Kind, SourceSearch, &provider, &externalID, &attribution, nil, content, in.Crop)
}

type SearchInput struct {
	UserID uuid.UUID
	Query  string
	Page   int
	Limit  int
}

type searchResponse struct {
	ExternalID  string `json:"external_id"`
	ThumbURL    string `json:"thumb_url"`
	Attribution string `json:"attribution"`
	Width       int    `json:"width"`
	Height      int    `json:"height"`
}

func (s *Service) Search(ctx context.Context, in SearchInput) ([]searchResponse, error) {
	if err := s.checkRateLimit(ctx, "search", in.UserID, searchPerWindow, searchWindow); err != nil {
		return nil, err
	}
	if strings.TrimSpace(in.Query) == "" {
		return nil, apierror.NewValidation(map[string]string{"q": "Campo obbligatorio."})
	}
	results, err := s.search.Search(ctx, in.Query, in.Page, in.Limit)
	if err != nil {
		return nil, apierror.New(http.StatusBadGateway, "IMAGE_SEARCH_FAILED", "Ricerca immagini non disponibile al momento.")
	}
	out := make([]searchResponse, 0, len(results))
	for _, r := range results {
		out = append(out, searchResponse{
			ExternalID: r.ExternalID, ThumbURL: r.ThumbURL, Attribution: r.Attribution,
			Width: r.Width, Height: r.Height,
		})
	}
	return out, nil
}

func (s *Service) List(ctx context.Context, ownerUserID uuid.UUID, kind string, sortRecent bool, limit int) ([]assetResponse, error) {
	assets, err := s.repo.List(ctx, ListFilter{OwnerUserID: ownerUserID, Kind: kind, SortRecent: sortRecent, Limit: limit})
	if err != nil {
		return nil, err
	}
	out := make([]assetResponse, 0, len(assets))
	for _, a := range assets {
		out = append(out, toAssetResponse(a))
	}
	return out, nil
}

// GetContent returns the asset's bytes for the authenticated-download
// endpoint (plan.md section 16.7 MVP distribution path), bumping
// last_used_at since being viewed counts as being used.
func (s *Service) GetContent(ctx context.Context, ownerUserID, id uuid.UUID) (Asset, io.ReadCloser, error) {
	asset, err := s.repo.GetByIDAndOwner(ctx, id, ownerUserID)
	if errors.Is(err, ErrNotFound) {
		return Asset{}, nil, apierror.ErrNotFound
	}
	if err != nil {
		return Asset{}, nil, err
	}

	content, err := s.store.Get(ctx, asset.ObjectKey)
	if err != nil {
		return Asset{}, nil, fmt.Errorf("get media content: %w", err)
	}
	return asset, content, nil
}

func (s *Service) Delete(ctx context.Context, ownerUserID, id uuid.UUID) error {
	asset, err := s.repo.GetByIDAndOwner(ctx, id, ownerUserID)
	if errors.Is(err, ErrNotFound) {
		return apierror.ErrNotFound
	}
	if err != nil {
		return err
	}

	referenced, err := s.repo.IsReferenced(ctx, asset.ID)
	if err != nil {
		return err
	}
	if referenced {
		return apierror.New(http.StatusConflict, "MEDIA_IN_USE", "L'immagine è ancora in uso e non può essere eliminata.")
	}

	if err := s.repo.SoftDelete(ctx, id, ownerUserID); err != nil {
		if errors.Is(err, ErrNotFound) {
			return apierror.ErrNotFound
		}
		return err
	}
	_ = s.store.Delete(ctx, asset.ObjectKey)
	return nil
}

// CleanupOrphans deletes ready assets older than graceHours with no
// referencing row anywhere (plan.md section 16.6: "Pulire asset orfani dopo
// un periodo di grazia"), run periodically by the worker process.
func (s *Service) CleanupOrphans(ctx context.Context, graceHours int) (int, error) {
	candidates, err := s.repo.ListOrphans(ctx, graceHours, 200)
	if err != nil {
		return 0, err
	}

	deleted := 0
	for _, c := range candidates {
		if err := s.repo.SoftDeleteByID(ctx, c.ID); err != nil {
			continue
		}
		_ = s.store.Delete(ctx, c.ObjectKey)
		deleted++
	}
	return deleted, nil
}
