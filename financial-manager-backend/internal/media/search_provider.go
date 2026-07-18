package media

import (
	"context"
	"io"
)

// SearchResult is one hit from an image search provider (plan.md section
// 16.2). ThumbURL points directly at the provider's own CDN so the client
// can preview results without the backend downloading anything — a
// media_asset row (and the backend Fetch below) only gets created once the
// user actually picks a result (plan.md section 16.6: "Salvare un asset
// solo quando viene selezionato").
type SearchResult struct {
	ExternalID  string
	ThumbURL    string
	Attribution string
	Width       int
	Height      int
}

// Metadata describes a fetched search result, persisted alongside the
// asset for attribution requirements.
type Metadata struct {
	Attribution string
}

// ImageSearchProvider abstracts the external stock-photo source (plan.md
// section 16.2). The client only ever sends an ExternalID the backend
// already emitted from Search — never an arbitrary URL — so Fetch is the
// only place that reaches out to a third-party host, kept to an allowlist
// of known provider domains to bound SSRF risk.
type ImageSearchProvider interface {
	Search(ctx context.Context, query string, page, limit int) ([]SearchResult, error)
	Fetch(ctx context.Context, externalID string) (io.ReadCloser, Metadata, error)
}
