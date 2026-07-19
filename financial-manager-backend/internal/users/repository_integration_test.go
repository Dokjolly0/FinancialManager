package users_test

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/platform/database"
	"financial-manager-backend/internal/users"
)

// Exercises the account-deletion repository methods (plan.md section
// 20.3) against a real PostgreSQL — the dev stack from
// `docker compose -f compose.yaml -f compose.dev.yaml up`. Skips
// automatically if it isn't reachable.

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func newTestRepo(t *testing.T) *users.Repository {
	t.Helper()
	databaseURL := envOrDefault("TEST_DATABASE_URL", "postgres://financial_manager:financial_manager@localhost:10001/financial_manager?sslmode=disable")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	dbPool, err := database.Connect(ctx, databaseURL)
	if err != nil {
		t.Skipf("skipping: dev Postgres not reachable at %s: %v", databaseURL, err)
	}
	t.Cleanup(dbPool.Close)

	return users.NewRepository(dbPool)
}

func createTestUser(t *testing.T, repo *users.Repository) users.User {
	t.Helper()
	suffix := uuid.NewString()[:8]
	u, err := repo.Create(context.Background(), users.CreateInput{
		FirstName: "Delete", LastName: "Test", Username: "deltest" + suffix,
		Email:                 "deltest" + suffix + "@example.com",
		AvatarBackgroundColor: "#176B5B", AvatarTextColor: "#FFFFFF",
		Locale: "it-IT", Timezone: "Europe/Rome",
	})
	if err != nil {
		t.Fatalf("create test user: %v", err)
	}
	return u
}

func TestMarkPendingDeletion_ThenListPendingDeletionOlderThan(t *testing.T) {
	repo := newTestRepo(t)
	ctx := context.Background()
	u := createTestUser(t, repo)

	if err := repo.MarkPendingDeletion(ctx, u.ID); err != nil {
		t.Fatalf("MarkPendingDeletion() error = %v", err)
	}

	reloaded, err := repo.GetByID(ctx, u.ID)
	if err != nil {
		t.Fatalf("GetByID() error = %v", err)
	}
	if reloaded.Status != users.StatusPendingDeletion {
		t.Errorf("status = %q, want %q", reloaded.Status, users.StatusPendingDeletion)
	}

	// A cutoff in the past excludes an account marked just now.
	notYetDue, err := repo.ListPendingDeletionOlderThan(ctx, time.Now().Add(-time.Hour))
	if err != nil {
		t.Fatalf("ListPendingDeletionOlderThan(past) error = %v", err)
	}
	for _, candidate := range notYetDue {
		if candidate.ID == u.ID {
			t.Error("a just-marked account must not appear before its grace period elapses")
		}
	}

	// A cutoff in the future includes it (simulates the grace period
	// having elapsed without needing to actually wait).
	due, err := repo.ListPendingDeletionOlderThan(ctx, time.Now().Add(time.Hour))
	if err != nil {
		t.Fatalf("ListPendingDeletionOlderThan(future) error = %v", err)
	}
	found := false
	for _, candidate := range due {
		if candidate.ID == u.ID {
			found = true
		}
	}
	if !found {
		t.Error("expected the marked account to appear once its grace period is considered elapsed")
	}
}

func TestPurge_AnonymizesAndBlocksFutureLookup(t *testing.T) {
	repo := newTestRepo(t)
	ctx := context.Background()
	u := createTestUser(t, repo)
	originalEmail := u.Email

	if err := repo.Purge(ctx, u.ID); err != nil {
		t.Fatalf("Purge() error = %v", err)
	}

	if _, err := repo.GetByID(ctx, u.ID); err == nil {
		t.Error("GetByID() must not find a purged (deleted_at set) user")
	}
	if _, err := repo.GetByEmailNormalized(ctx, users.NormalizeEmail(originalEmail)); err == nil {
		t.Error("the original email must no longer resolve to any account after purge")
	}
}
