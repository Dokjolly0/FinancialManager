package media

import (
	"bytes"
	"context"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"io"
)

// StubImageSearchProvider is a deterministic, offline fake used in
// local/test environments so the search feature is exercisable without
// external credentials (plan.md section 16.2, .env.example: "IMAGE_SEARCH_PROVIDER
// stub ... uses a fake in-memory provider"). Fetch generates a small solid-color
// PNG rather than reaching out anywhere.
type StubImageSearchProvider struct{}

func (StubImageSearchProvider) Search(ctx context.Context, query string, page, limit int) ([]SearchResult, error) {
	if limit <= 0 {
		limit = 10
	}
	results := make([]SearchResult, 0, limit)
	for i := range limit {
		id := fmt.Sprintf("stub-%s-%d-%d", query, page, i)
		results = append(results, SearchResult{
			ExternalID:  id,
			ThumbURL:    "https://example.invalid/stub/" + id + "/thumb",
			Attribution: "Stub placeholder image",
			Width:       800,
			Height:      800,
		})
	}
	return results, nil
}

func (StubImageSearchProvider) Fetch(ctx context.Context, externalID string) (io.ReadCloser, Metadata, error) {
	img := image.NewRGBA(image.Rect(0, 0, 800, 800))
	var fill color.RGBA
	for i, c := range []byte(externalID) {
		switch i % 3 {
		case 0:
			fill.R += c
		case 1:
			fill.G += c
		case 2:
			fill.B += c
		}
	}
	fill.A = 255
	for y := range 800 {
		for x := range 800 {
			img.Set(x, y, fill)
		}
	}

	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		return nil, Metadata{}, err
	}
	return io.NopCloser(bytes.NewReader(buf.Bytes())), Metadata{Attribution: "Stub placeholder image"}, nil
}
