package media

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// UnsplashProvider implements ImageSearchProvider against the real
// Unsplash API (plan.md section 16.2). Requires an Access Key from
// unsplash.com/developers (IMAGE_SEARCH_API_KEY, selected via
// IMAGE_SEARCH_PROVIDER=unsplash).
type UnsplashProvider struct {
	accessKey  string
	httpClient *http.Client
	baseURL    string // overridable in tests
}

func NewUnsplashProvider(accessKey string) *UnsplashProvider {
	return &UnsplashProvider{
		accessKey:  accessKey,
		httpClient: &http.Client{Timeout: 15 * time.Second},
		baseURL:    "https://api.unsplash.com",
	}
}

func (p *UnsplashProvider) authorize(req *http.Request) {
	req.Header.Set("Authorization", "Client-ID "+p.accessKey)
	req.Header.Set("Accept-Version", "v1")
}

// isAllowedUnsplashHost bounds SSRF risk (plan.md section 16.2: "Il backend
// accetta soltanto provider e domini in allowlist") for the two follow-up
// URLs Unsplash's own API responses hand back to us (download_location, and
// the final signed asset URL) — both must stay on an unsplash.com host.
func isAllowedUnsplashHost(rawURL string) bool {
	u, err := url.Parse(rawURL)
	if err != nil {
		return false
	}
	host := strings.ToLower(u.Host)
	return host == "unsplash.com" || strings.HasSuffix(host, ".unsplash.com")
}

type unsplashSearchResponse struct {
	Results []unsplashPhoto `json:"results"`
}

type unsplashPhoto struct {
	ID     string `json:"id"`
	Width  int    `json:"width"`
	Height int    `json:"height"`
	URLs   struct {
		Thumb   string `json:"thumb"`
		Regular string `json:"regular"`
	} `json:"urls"`
	Links struct {
		DownloadLocation string `json:"download_location"`
	} `json:"links"`
	User struct {
		Name string `json:"name"`
	} `json:"user"`
}

func (p *UnsplashProvider) Search(ctx context.Context, query string, page, limit int) ([]SearchResult, error) {
	if page <= 0 {
		page = 1
	}
	if limit <= 0 || limit > 30 {
		limit = 20
	}

	reqURL := fmt.Sprintf("%s/search/photos?query=%s&page=%d&per_page=%d",
		p.baseURL, url.QueryEscape(query), page, limit)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, reqURL, nil)
	if err != nil {
		return nil, err
	}
	p.authorize(req)

	resp, err := p.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("unsplash search request: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unsplash search: unexpected status %d", resp.StatusCode)
	}

	var decoded unsplashSearchResponse
	if err := json.NewDecoder(resp.Body).Decode(&decoded); err != nil {
		return nil, fmt.Errorf("decode unsplash search response: %w", err)
	}

	results := make([]SearchResult, 0, len(decoded.Results))
	for _, r := range decoded.Results {
		results = append(results, SearchResult{
			ExternalID:  r.ID,
			ThumbURL:    r.URLs.Thumb,
			Attribution: fmt.Sprintf("Photo by %s on Unsplash", r.User.Name),
			Width:       r.Width,
			Height:      r.Height,
		})
	}
	return results, nil
}

func (p *UnsplashProvider) Fetch(ctx context.Context, externalID string) (io.ReadCloser, Metadata, error) {
	detailURL := fmt.Sprintf("%s/photos/%s", p.baseURL, url.PathEscape(externalID))
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, detailURL, nil)
	if err != nil {
		return nil, Metadata{}, err
	}
	p.authorize(req)

	resp, err := p.httpClient.Do(req)
	if err != nil {
		return nil, Metadata{}, fmt.Errorf("unsplash photo detail request: %w", err)
	}
	var photo unsplashPhoto
	decodeErr := json.NewDecoder(resp.Body).Decode(&photo)
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, Metadata{}, fmt.Errorf("unsplash photo detail: unexpected status %d", resp.StatusCode)
	}
	if decodeErr != nil {
		return nil, Metadata{}, fmt.Errorf("decode unsplash photo detail: %w", decodeErr)
	}

	// Unsplash API guidelines require pinging download_location whenever a
	// photo is actually used, not just previewed — it returns a signed,
	// tracked URL for the real file rather than us hotlinking urls.regular.
	if !isAllowedUnsplashHost(photo.Links.DownloadLocation) {
		return nil, Metadata{}, fmt.Errorf("unexpected download_location host")
	}
	dlReq, err := http.NewRequestWithContext(ctx, http.MethodGet, photo.Links.DownloadLocation, nil)
	if err != nil {
		return nil, Metadata{}, err
	}
	p.authorize(dlReq)

	dlResp, err := p.httpClient.Do(dlReq)
	if err != nil {
		return nil, Metadata{}, fmt.Errorf("unsplash download_location request: %w", err)
	}
	var dl struct {
		URL string `json:"url"`
	}
	dlDecodeErr := json.NewDecoder(dlResp.Body).Decode(&dl)
	dlResp.Body.Close()
	if dlResp.StatusCode != http.StatusOK {
		return nil, Metadata{}, fmt.Errorf("unsplash download_location: unexpected status %d", dlResp.StatusCode)
	}
	if dlDecodeErr != nil {
		return nil, Metadata{}, fmt.Errorf("decode unsplash download_location: %w", dlDecodeErr)
	}

	if !isAllowedUnsplashHost(dl.URL) {
		return nil, Metadata{}, fmt.Errorf("unexpected asset host")
	}
	fileReq, err := http.NewRequestWithContext(ctx, http.MethodGet, dl.URL, nil)
	if err != nil {
		return nil, Metadata{}, err
	}
	fileResp, err := p.httpClient.Do(fileReq)
	if err != nil {
		return nil, Metadata{}, fmt.Errorf("unsplash asset download: %w", err)
	}
	if fileResp.StatusCode != http.StatusOK {
		fileResp.Body.Close()
		return nil, Metadata{}, fmt.Errorf("unsplash asset download: unexpected status %d", fileResp.StatusCode)
	}

	return fileResp.Body, Metadata{Attribution: fmt.Sprintf("Photo by %s on Unsplash", photo.User.Name)}, nil
}
