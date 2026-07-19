package export_test

import (
	"context"
	"encoding/csv"
	"encoding/json"
	"io"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/categories"
	"financial-manager-backend/internal/export"
	"financial-manager-backend/internal/platform/database"
	"financial-manager-backend/internal/platform/storage"
	"financial-manager-backend/internal/templates"
	"financial-manager-backend/internal/transactions"
	"financial-manager-backend/internal/users"
	"financial-manager-backend/internal/wallets"
)

// Exercises CSV/JSON generation end-to-end (plan.md section 20.2) against a
// real PostgreSQL and MinIO — the dev stack from
// `docker compose -f compose.yaml -f compose.dev.yaml up`. Skips
// automatically if either isn't reachable.

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

type harness struct {
	service *export.Service
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
	walletsRepo := wallets.NewRepository(dbPool)
	categoriesRepo := categories.NewRepository(dbPool)
	transactionsRepo := transactions.NewRepository(dbPool)
	templatesRepo := templates.NewRepository(dbPool)

	suffix := uuid.NewString()[:8]
	user, err := usersRepo.Create(context.Background(), users.CreateInput{
		FirstName: "Export", LastName: "Test", Username: "exporttest" + suffix,
		Email:                 "exporttest" + suffix + "@example.com",
		AvatarBackgroundColor: "#176B5B", AvatarTextColor: "#FFFFFF",
		Locale: "it-IT", Timezone: "Europe/Rome",
	})
	if err != nil {
		t.Fatalf("create test user: %v", err)
	}
	wallet, err := walletsRepo.Create(context.Background(), user.ID, "EUR", 10000)
	if err != nil {
		t.Fatalf("create test wallet: %v", err)
	}
	category, err := categoriesRepo.Create(context.Background(), categories.CreateInput{
		OwnerUserID: user.ID, Name: "Spesa export test " + suffix, DirectionScope: categories.ScopeDebit,
	})
	if err != nil {
		t.Fatalf("create test category: %v", err)
	}
	if _, err := transactionsRepo.Create(context.Background(), transactions.CreateInput{
		WalletID: wallet.ID, UserID: user.ID, Direction: transactions.DirectionDebit, Kind: transactions.KindStandard,
		AmountMinor: 1250, Currency: "EUR", Title: "Caffe export test", CategoryID: &category.ID,
		OccurredAt: time.Now(),
	}); err != nil {
		t.Fatalf("create test transaction: %v", err)
	}

	service := export.NewService(export.Deps{
		Repo: export.NewRepository(dbPool), Store: store, Users: usersRepo, Wallets: walletsRepo,
		Categories: categoriesRepo, Templates: templatesRepo, Transactions: transactionsRepo,
	})
	return harness{service: service, userID: user.ID}
}

func downloadBody(t *testing.T, h harness, exportID uuid.UUID) []byte {
	t.Helper()
	_, content, err := h.service.DownloadContent(context.Background(), h.userID, exportID)
	if err != nil {
		t.Fatalf("DownloadContent() error = %v", err)
	}
	defer content.Close()
	body, err := io.ReadAll(content)
	if err != nil {
		t.Fatalf("read export body: %v", err)
	}
	return body
}

func TestRequestExport_CSV_ContainsTransactionRow(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	record, err := h.service.RequestExport(ctx, h.userID, export.FormatCSV)
	if err != nil {
		t.Fatalf("RequestExport() error = %v", err)
	}
	if record.Status != export.StatusReady {
		t.Fatalf("record.Status = %q, want %q (error: %v)", record.Status, export.StatusReady, record.ErrorMessage)
	}

	body := downloadBody(t, h, record.ID)
	rows, err := csv.NewReader(strings.NewReader(string(body))).ReadAll()
	if err != nil {
		t.Fatalf("parse CSV: %v", err)
	}
	if len(rows) < 2 {
		t.Fatalf("got %d CSV rows, want a header plus at least one transaction", len(rows))
	}
	wantHeader := []string{"id", "data_ora", "tipo", "titolo", "categoria", "descrizione", "importo", "valuta", "natura"}
	for i, col := range wantHeader {
		if rows[0][i] != col {
			t.Errorf("header[%d] = %q, want %q", i, rows[0][i], col)
		}
	}

	found := false
	for _, row := range rows[1:] {
		if row[3] == "Caffe export test" {
			found = true
			if row[4] == "" {
				t.Error("category column is empty for a transaction with a category")
			}
			if row[6] != "12.50" {
				t.Errorf("importo = %q, want 12.50", row[6])
			}
		}
	}
	if !found {
		t.Error("CSV export is missing the seeded transaction")
	}
}

func TestRequestExport_JSON_ContainsProfileWalletAndTransactions(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	record, err := h.service.RequestExport(ctx, h.userID, export.FormatJSON)
	if err != nil {
		t.Fatalf("RequestExport() error = %v", err)
	}
	if record.Status != export.StatusReady {
		t.Fatalf("record.Status = %q, want %q (error: %v)", record.Status, export.StatusReady, record.ErrorMessage)
	}

	body := downloadBody(t, h, record.ID)
	var decoded struct {
		Profile struct {
			ID string `json:"id"`
		} `json:"profilo"`
		Wallet struct {
			Currency string `json:"currency"`
		} `json:"portafoglio"`
		Transactions []struct {
			Title string `json:"title"`
		} `json:"transazioni"`
	}
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatalf("parse JSON export: %v", err)
	}
	if decoded.Profile.ID != h.userID.String() {
		t.Errorf("profilo.id = %q, want %q", decoded.Profile.ID, h.userID.String())
	}
	if decoded.Wallet.Currency != "EUR" {
		t.Errorf("portafoglio.currency = %q, want EUR", decoded.Wallet.Currency)
	}
	found := false
	for _, tx := range decoded.Transactions {
		if tx.Title == "Caffe export test" {
			found = true
		}
	}
	if !found {
		t.Error("JSON export is missing the seeded transaction")
	}
}

func TestGetExport_UnknownIDIsNotFound(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	_, err := h.service.GetExport(ctx, h.userID, uuid.New())
	if err == nil {
		t.Fatal("expected an error for an unknown export id")
	}
}

func TestGetExport_AnotherUsersExportIsNotFound(t *testing.T) {
	h1 := newHarness(t)
	h2 := newHarness(t)
	ctx := context.Background()

	record, err := h1.service.RequestExport(ctx, h1.userID, export.FormatCSV)
	if err != nil {
		t.Fatalf("RequestExport() error = %v", err)
	}

	if _, err := h2.service.GetExport(ctx, h2.userID, record.ID); err == nil {
		t.Fatal("expected an error when a different user requests someone else's export")
	}
}
