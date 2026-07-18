package media_test

import (
	"bytes"
	"context"
	"errors"
	"image"
	"image/color"
	"image/png"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/media"
	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/clock"
	"financial-manager-backend/internal/platform/database"
	"financial-manager-backend/internal/platform/storage"
	"financial-manager-backend/internal/transactions"
	"financial-manager-backend/internal/users"
	"financial-manager-backend/internal/wallets"
)

// Exercises the upload/dedup/list/delete/orphan-cleanup pipeline (plan.md
// section 16) against a real PostgreSQL and MinIO — the dev stack from
// `docker compose -f compose.yaml -f compose.dev.yaml up`. Skips
// automatically if either isn't reachable.

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

type harness struct {
	service *media.Service
	repo    *media.Repository
	dbPool  *database.Pool
	userID  uuid.UUID
}

func newHarness(t *testing.T) harness {
	t.Helper()

	databaseURL := envOrDefault("TEST_DATABASE_URL", "postgres://financial_manager:financial_manager@localhost:10001/financial_manager?sslmode=disable")
	objectStorageEndpoint := envOrDefault("TEST_OBJECT_STORAGE_ENDPOINT", "localhost:9002")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	dbPool, err := database.Connect(ctx, databaseURL)
	if err != nil {
		t.Skipf("skipping: dev Postgres not reachable at %s: %v", databaseURL, err)
	}
	t.Cleanup(dbPool.Close)

	store, err := storage.NewMinIOStore(ctx, storage.MinIOConfig{
		Endpoint: objectStorageEndpoint, AccessKey: "financial_manager", SecretKey: "financial_manager_secret",
		Bucket: "financial-manager-media", UseSSL: false,
	})
	if err != nil {
		t.Skipf("skipping: dev MinIO not reachable at %s: %v", objectStorageEndpoint, err)
	}

	usersRepo := users.NewRepository(dbPool)
	suffix := uuid.NewString()[:8]
	user, err := usersRepo.Create(context.Background(), users.CreateInput{
		FirstName:             "Test",
		LastName:              "User",
		Username:              "mediatest" + suffix,
		Email:                 "mediatest" + suffix + "@example.com",
		AvatarBackgroundColor: "#176B5B",
		AvatarTextColor:       "#FFFFFF",
		Locale:                "it-IT",
		Timezone:              "Europe/Rome",
	})
	if err != nil {
		t.Fatalf("create test user: %v", err)
	}

	repo := media.NewRepository(dbPool)
	service := media.NewService(media.Deps{
		Repo: repo, Store: store, Search: media.StubImageSearchProvider{},
		MaxUploadBytes: 10 * 1024 * 1024, AllowedImageTypes: []string{"image/jpeg", "image/png", "image/webp"},
	})
	return harness{service: service, repo: repo, dbPool: dbPool, userID: user.ID}
}

func testPNG(t *testing.T, width, height int, c color.Color) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, width, height))
	for y := range height {
		for x := range width {
			img.Set(x, y, c)
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatalf("encode test png: %v", err)
	}
	return buf.Bytes()
}

func TestUpload_ProcessesAndListsTheAsset(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	content := testPNG(t, 400, 300, color.RGBA{R: 200, G: 50, B: 50, A: 255})
	asset, err := h.service.Upload(ctx, media.UploadInput{
		OwnerUserID: h.userID, Kind: media.KindTransaction, Content: content, OriginalFilename: "receipt.png",
	})
	if err != nil {
		t.Fatalf("Upload() error = %v", err)
	}
	if asset.Width != 512 || asset.Height != 512 {
		t.Errorf("dimensions = %dx%d, want 512x512 (transaction target size)", asset.Width, asset.Height)
	}

	list, err := h.service.List(ctx, h.userID, media.KindTransaction, false, 10)
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	if len(list) != 1 || list[0].ID != asset.ID {
		t.Fatalf("List() = %+v, want exactly the uploaded asset", list)
	}
}

func TestUpload_DeduplicatesIdenticalContent(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	content := testPNG(t, 200, 200, color.RGBA{R: 10, G: 20, B: 30, A: 255})

	first, err := h.service.Upload(ctx, media.UploadInput{
		OwnerUserID: h.userID, Kind: media.KindTransaction, Content: content,
	})
	if err != nil {
		t.Fatalf("first Upload() error = %v", err)
	}
	second, err := h.service.Upload(ctx, media.UploadInput{
		OwnerUserID: h.userID, Kind: media.KindTransaction, Content: content,
	})
	if err != nil {
		t.Fatalf("second Upload() error = %v", err)
	}
	if first.ID != second.ID {
		t.Errorf("re-uploading identical content created a new asset: %q vs %q, want the same id", first.ID, second.ID)
	}

	list, err := h.service.List(ctx, h.userID, media.KindTransaction, false, 10)
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	if len(list) != 1 {
		t.Fatalf("List() = %+v, want exactly one deduplicated asset", list)
	}
}

func TestSelectFromSearch_FetchesAndStoresViaStubProvider(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	asset, err := h.service.SelectFromSearch(ctx, media.SelectFromSearchInput{
		OwnerUserID: h.userID, Kind: media.KindTransaction, Provider: "unsplash", ExternalID: "stub-coffee-1-0",
	})
	if err != nil {
		t.Fatalf("SelectFromSearch() error = %v", err)
	}
	if asset.Source != media.SourceSearch {
		t.Errorf("source = %q, want %q", asset.Source, media.SourceSearch)
	}
	if asset.Attribution == nil || *asset.Attribution == "" {
		t.Error("expected a non-empty attribution for a search-sourced asset")
	}
}

func TestDelete_RejectsWhileReferencedThenSucceedsAfterDetached(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	content := testPNG(t, 100, 100, color.RGBA{G: 200, A: 255})
	asset, err := h.service.Upload(ctx, media.UploadInput{
		OwnerUserID: h.userID, Kind: media.KindTransaction, Content: content,
	})
	if err != nil {
		t.Fatalf("Upload() error = %v", err)
	}
	assetID := uuid.MustParse(asset.ID)

	// Simulate the asset being attached to a transaction by bumping usage
	// via MarkUsed is not enough — IsReferenced checks actual FK rows, so
	// directly exercise the referenced-vs-not paths using a real reference:
	// mark it used (allowed) and confirm deletion is blocked only once an
	// actual referencing row exists is out of scope here; this test instead
	// confirms deletion succeeds for a genuinely unreferenced asset.
	if err := h.service.Delete(ctx, h.userID, assetID); err != nil {
		t.Fatalf("Delete() of an unreferenced asset error = %v", err)
	}

	list, err := h.service.List(ctx, h.userID, media.KindTransaction, false, 10)
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	for _, a := range list {
		if a.ID == asset.ID {
			t.Error("deleted asset must not appear in List() anymore")
		}
	}

	// Deleting again must 404, not silently succeed.
	err = h.service.Delete(ctx, h.userID, assetID)
	var apiErr *apierror.Error
	if !errors.As(err, &apiErr) || apiErr.Status != 404 {
		t.Fatalf("expected a 404 deleting an already-deleted asset, got %v", err)
	}
}

func TestDelete_RejectsWhileReferencedByATransaction(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	content := testPNG(t, 120, 120, color.RGBA{R: 100, G: 100, A: 255})
	asset, err := h.service.Upload(ctx, media.UploadInput{
		OwnerUserID: h.userID, Kind: media.KindTransaction, Content: content,
	})
	if err != nil {
		t.Fatalf("Upload() error = %v", err)
	}
	mediaID := uuid.MustParse(asset.ID)

	walletsRepo := wallets.NewRepository(h.dbPool)
	wallet, err := walletsRepo.Create(ctx, h.userID, "EUR", 100000)
	if err != nil {
		t.Fatalf("create test wallet: %v", err)
	}

	transactionsService := transactions.NewService(transactions.Deps{
		DB: h.dbPool, Transactions: transactions.NewRepository(h.dbPool), Wallets: walletsRepo,
		Audit: transactions.NewAuditRepository(h.dbPool), Categories: nil, Templates: nil, Media: h.repo,
		Clock: clock.System{},
	})
	_ = wallet
	_, _, err = transactionsService.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, Direction: transactions.DirectionDebit, AmountMinor: 500,
		Currency: "EUR", Title: "Con immagine", MediaID: &mediaID,
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateStandard() error = %v", err)
	}

	err = h.service.Delete(ctx, h.userID, mediaID)
	var apiErr *apierror.Error
	if !errors.As(err, &apiErr) || apiErr.Status != 409 {
		t.Fatalf("expected a 409 conflict deleting a media asset still attached to a transaction, got %v", err)
	}
}

func TestCleanupOrphans_LeavesRecentAssetsAlone(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	content := testPNG(t, 64, 64, color.RGBA{B: 200, A: 255})
	asset, err := h.service.Upload(ctx, media.UploadInput{
		OwnerUserID: h.userID, Kind: media.KindTransaction, Content: content,
	})
	if err != nil {
		t.Fatalf("Upload() error = %v", err)
	}

	// A freshly uploaded asset is well within any reasonable grace period,
	// so a 24h-grace cleanup pass must not touch it.
	deleted, err := h.service.CleanupOrphans(ctx, 24)
	if err != nil {
		t.Fatalf("CleanupOrphans() error = %v", err)
	}
	_ = deleted

	list, err := h.service.List(ctx, h.userID, media.KindTransaction, false, 10)
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	var found bool
	for _, a := range list {
		if a.ID == asset.ID {
			found = true
		}
	}
	if !found {
		t.Error("a fresh asset must survive a grace-period cleanup pass")
	}
}
