package categories_test

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/categories"
	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/database"
	"financial-manager-backend/internal/users"
)

// Exercises category visibility and CRUD (plan.md section 14.7) against a
// real PostgreSQL — the dev stack from
// `docker compose -f compose.yaml -f compose.dev.yaml up`. Skips
// automatically if that stack isn't reachable.

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

type harness struct {
	service *categories.Service
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
		Username:              "cattest" + suffix,
		Email:                 "cattest" + suffix + "@example.com",
		AvatarBackgroundColor: "#176B5B",
		AvatarTextColor:       "#FFFFFF",
		Locale:                "it-IT",
		Timezone:              "Europe/Rome",
	})
	if err != nil {
		t.Fatalf("create test user: %v", err)
	}

	service := categories.NewService(categories.NewRepository(dbPool))
	return harness{service: service, userID: user.ID}
}

func TestList_IncludesSystemCategoriesForANewUser(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	list, err := h.service.List(ctx, h.userID)
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}

	var foundSystem bool
	for _, c := range list {
		if c.IsSystem && c.Name == "Alimentari" {
			foundSystem = true
		}
	}
	if !foundSystem {
		t.Error("expected the seeded system category \"Alimentari\" to be visible to a new user")
	}
}

func TestCreate_ListsAndIsUpdatableAndDeletable(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	created, err := h.service.Create(ctx, categories.CreateServiceInput{
		UserID: h.userID, Name: "Hobby fotografia", DirectionScope: categories.ScopeDebit,
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if created.IsSystem {
		t.Error("a user-created category must not be marked is_system")
	}

	list, err := h.service.List(ctx, h.userID)
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	var found bool
	for _, c := range list {
		if c.ID == created.ID {
			found = true
		}
	}
	if !found {
		t.Error("expected the newly created custom category to appear in List()")
	}

	updated, err := h.service.Update(ctx, categories.UpdateServiceInput{
		UserID: h.userID, CategoryID: uuid.MustParse(created.ID),
		Name: "Hobby fotografia analogica", DirectionScope: categories.ScopeDebit,
	})
	if err != nil {
		t.Fatalf("Update() error = %v", err)
	}
	if updated.Name != "Hobby fotografia analogica" {
		t.Errorf("Name after update = %q, want %q", updated.Name, "Hobby fotografia analogica")
	}

	if err := h.service.Delete(ctx, h.userID, uuid.MustParse(created.ID)); err != nil {
		t.Fatalf("Delete() error = %v", err)
	}

	listAfterDelete, err := h.service.List(ctx, h.userID)
	if err != nil {
		t.Fatalf("List() after delete error = %v", err)
	}
	for _, c := range listAfterDelete {
		if c.ID == created.ID {
			t.Error("deleted category must not appear in List() anymore")
		}
	}
}

func TestCreate_DuplicateNameSameScopeConflicts(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	if _, err := h.service.Create(ctx, categories.CreateServiceInput{
		UserID: h.userID, Name: "Palestra", DirectionScope: categories.ScopeDebit,
	}); err != nil {
		t.Fatalf("first Create() error = %v", err)
	}

	_, err := h.service.Create(ctx, categories.CreateServiceInput{
		UserID: h.userID, Name: "palestra", DirectionScope: categories.ScopeDebit,
	})
	var apiErr *apierror.Error
	if !errors.As(err, &apiErr) || apiErr.Status != 409 {
		t.Fatalf("expected a 409 conflict for a duplicate normalized name, got %v", err)
	}
}

func TestSystemCategory_CannotBeEditedOrDeleted(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	list, err := h.service.List(ctx, h.userID)
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	var systemID string
	for _, c := range list {
		if c.IsSystem {
			systemID = c.ID
			break
		}
	}
	if systemID == "" {
		t.Fatal("expected at least one system category")
	}

	_, err = h.service.Update(ctx, categories.UpdateServiceInput{
		UserID: h.userID, CategoryID: uuid.MustParse(systemID), Name: "Hacked", DirectionScope: categories.ScopeDebit,
	})
	var apiErr *apierror.Error
	if !errors.As(err, &apiErr) || apiErr.Status != 403 {
		t.Fatalf("expected a 403 forbidding editing a system category, got %v", err)
	}

	err = h.service.Delete(ctx, h.userID, uuid.MustParse(systemID))
	if !errors.As(err, &apiErr) || apiErr.Status != 403 {
		t.Fatalf("expected a 403 forbidding deleting a system category, got %v", err)
	}
}
