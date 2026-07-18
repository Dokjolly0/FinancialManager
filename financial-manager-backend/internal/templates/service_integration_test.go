package templates_test

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/database"
	"financial-manager-backend/internal/templates"
	"financial-manager-backend/internal/users"
)

// Exercises template CRUD and autocomplete ordering (plan.md section 4.4,
// 7.6, 17.3) against a real PostgreSQL — the dev stack from
// `docker compose -f compose.yaml -f compose.dev.yaml up`. Skips
// automatically if that stack isn't reachable.

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

type harness struct {
	service *templates.Service
	repo    *templates.Repository
	userID  uuid.UUID
}

func newHarness(t *testing.T) harness {
	t.Helper()

	databaseURL := envOrDefault("TEST_DATABASE_URL", "postgres://financial_manager:financial_manager@localhost:10001/financial_manager?sslmode=disable")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	dbPool, err := database.Connect(ctx, databaseURL)
	if err != nil {
		t.Skipf("skipping: dev Postgres not reachable at %s: %v", databaseURL, err)
	}
	t.Cleanup(dbPool.Close)

	usersRepo := users.NewRepository(dbPool)
	suffix := uuid.NewString()[:8]
	user, err := usersRepo.Create(context.Background(), users.CreateInput{
		FirstName:             "Test",
		LastName:              "User",
		Username:              "tpltest" + suffix,
		Email:                 "tpltest" + suffix + "@example.com",
		AvatarBackgroundColor: "#176B5B",
		AvatarTextColor:       "#FFFFFF",
		Locale:                "it-IT",
		Timezone:              "Europe/Rome",
	})
	if err != nil {
		t.Fatalf("create test user: %v", err)
	}

	repo := templates.NewRepository(dbPool)
	return harness{service: templates.NewService(repo), repo: repo, userID: user.ID}
}

func TestCreate_SearchFindsByPrefixAndUpdateAndDelete(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	created, err := h.service.Create(ctx, templates.CreateServiceInput{
		UserID: h.userID, Direction: "DEBIT", Title: "Bar Centrale",
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}

	results, err := h.service.Search(ctx, templates.SearchInput{UserID: h.userID, Direction: "DEBIT", Query: "bar"})
	if err != nil {
		t.Fatalf("Search() error = %v", err)
	}
	if len(results) != 1 || results[0].ID != created.ID {
		t.Fatalf("Search(\"bar\") = %+v, want exactly the created template", results)
	}

	// Wrong direction must not match.
	creditResults, err := h.service.Search(ctx, templates.SearchInput{UserID: h.userID, Direction: "CREDIT", Query: "bar"})
	if err != nil {
		t.Fatalf("Search() error = %v", err)
	}
	if len(creditResults) != 0 {
		t.Fatalf("Search() under CREDIT direction = %+v, want empty", creditResults)
	}

	updated, err := h.service.Update(ctx, templates.UpdateServiceInput{
		UserID: h.userID, TemplateID: uuid.MustParse(created.ID), Title: "Bar Centrale (rinnovato)",
	})
	if err != nil {
		t.Fatalf("Update() error = %v", err)
	}
	if updated.Title != "Bar Centrale (rinnovato)" {
		t.Errorf("Title after update = %q, want %q", updated.Title, "Bar Centrale (rinnovato)")
	}

	if err := h.service.Delete(ctx, h.userID, uuid.MustParse(created.ID)); err != nil {
		t.Fatalf("Delete() error = %v", err)
	}
	resultsAfterDelete, err := h.service.Search(ctx, templates.SearchInput{UserID: h.userID, Direction: "DEBIT", Query: "bar"})
	if err != nil {
		t.Fatalf("Search() after delete error = %v", err)
	}
	if len(resultsAfterDelete) != 0 {
		t.Errorf("Search() after delete = %+v, want empty", resultsAfterDelete)
	}
}

func TestCreate_DuplicateTitleSameDirectionConflicts(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	if _, err := h.service.Create(ctx, templates.CreateServiceInput{
		UserID: h.userID, Direction: "DEBIT", Title: "Spesa settimanale",
	}); err != nil {
		t.Fatalf("first Create() error = %v", err)
	}

	_, err := h.service.Create(ctx, templates.CreateServiceInput{
		UserID: h.userID, Direction: "DEBIT", Title: "spesa   settimanale",
	})
	var apiErr *apierror.Error
	if !errors.As(err, &apiErr) || apiErr.Status != 409 {
		t.Fatalf("expected a 409 conflict for a duplicate normalized title, got %v", err)
	}
}

func TestSearch_OrdersByUsageThenRecency(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	popular, err := h.service.Create(ctx, templates.CreateServiceInput{UserID: h.userID, Direction: "DEBIT", Title: "Caffè"})
	if err != nil {
		t.Fatalf("Create(Caffè) error = %v", err)
	}
	rare, err := h.service.Create(ctx, templates.CreateServiceInput{UserID: h.userID, Direction: "DEBIT", Title: "Cinema"})
	if err != nil {
		t.Fatalf("Create(Cinema) error = %v", err)
	}

	// Bump "Caffè" three times so it outranks "Cinema" despite being
	// created first (plan.md section 4.4: frequency beats recency).
	popularID := uuid.MustParse(popular.ID)
	for range 3 {
		if err := h.repo.BumpUsage(ctx, popularID, h.userID); err != nil {
			t.Fatalf("BumpUsage() error = %v", err)
		}
	}
	if err := h.repo.BumpUsage(ctx, uuid.MustParse(rare.ID), h.userID); err != nil {
		t.Fatalf("BumpUsage() error = %v", err)
	}

	results, err := h.service.Search(ctx, templates.SearchInput{UserID: h.userID, Direction: "DEBIT"})
	if err != nil {
		t.Fatalf("Search() error = %v", err)
	}
	if len(results) < 2 || results[0].ID != popular.ID {
		t.Fatalf("Search() = %+v, want %q ranked first by usage_count", results, "Caffè")
	}
}
