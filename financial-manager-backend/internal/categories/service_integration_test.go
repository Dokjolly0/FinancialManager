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
	"financial-manager-backend/internal/templates"
	"financial-manager-backend/internal/transactions"
	"financial-manager-backend/internal/users"
	"financial-manager-backend/internal/wallets"
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
	db      *database.Pool
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

	service := categories.NewService(categories.Deps{DB: dbPool, Repo: categories.NewRepository(dbPool)})
	return harness{service: service, db: dbPool, userID: user.ID}
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

// TestCrossUserAccess_IsAlwaysRejected covers plan.md section 19.1/23.8
// (BOLA/IDOR): user B must not be able to edit or delete user A's own
// (non-system) category just by knowing its ID.
func TestCrossUserAccess_IsAlwaysRejected(t *testing.T) {
	owner := newHarness(t)
	intruder := newHarness(t)
	ctx := context.Background()

	created, err := owner.service.Create(ctx, categories.CreateServiceInput{
		UserID: owner.userID, Name: "Privata di A", DirectionScope: categories.ScopeDebit,
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	categoryID := uuid.MustParse(created.ID)

	_, err = owner.service.Update(ctx, categories.UpdateServiceInput{
		UserID: intruder.userID, CategoryID: categoryID, Name: "Hijacked", DirectionScope: categories.ScopeDebit,
	})
	if !errors.Is(err, apierror.ErrNotFound) {
		t.Errorf("Update() by intruder = %v, want apierror.ErrNotFound", err)
	}

	if err := owner.service.Delete(ctx, intruder.userID, categoryID); !errors.Is(err, apierror.ErrNotFound) {
		t.Errorf("Delete() by intruder = %v, want apierror.ErrNotFound", err)
	}
}

// seedTransaction writes a ledger row straight through the repository (the
// wallet balance isn't relevant to categories) and returns its ID.
func (h harness) seedTransaction(t *testing.T, walletID uuid.UUID, categoryID *uuid.UUID) uuid.UUID {
	t.Helper()
	tx, err := transactions.NewRepository(h.db).Create(context.Background(), transactions.CreateInput{
		WalletID: walletID, UserID: h.userID, Direction: transactions.DirectionDebit, Kind: transactions.KindStandard,
		AmountMinor: 1000, Currency: "EUR", Title: "Spesa", CategoryID: categoryID, OccurredAt: time.Now(),
	})
	if err != nil {
		t.Fatalf("seed transaction: %v", err)
	}
	return tx.ID
}

func (h harness) seedWallet(t *testing.T) uuid.UUID {
	t.Helper()
	w, err := wallets.NewRepository(h.db).Create(context.Background(), wallets.CreateRowInput{
		UserID: h.userID, Name: "Conto", Currency: "EUR", Type: wallets.TypeBank, Icon: "bank", Color: "#176B5B",
	})
	if err != nil {
		t.Fatalf("seed wallet: %v", err)
	}
	return w.ID
}

// find returns the per-user fields of category id as h's user lists it.
func (h harness) find(t *testing.T, id string) (usageCount int64, hidden, found bool) {
	t.Helper()
	list, err := h.service.List(context.Background(), h.userID)
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	for _, c := range list {
		if c.ID == id {
			return c.UsageCount, c.Hidden, true
		}
	}
	return 0, false, false
}

func TestList_IsAlphabeticalAcrossSystemAndCustom(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	if _, err := h.service.Create(ctx, categories.CreateServiceInput{
		UserID: h.userID, Name: "Animali", DirectionScope: categories.ScopeDebit,
	}); err != nil {
		t.Fatalf("Create() error = %v", err)
	}

	list, err := h.service.List(ctx, h.userID)
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	for i := 1; i < len(list); i++ {
		if categories.NormalizeName(list[i-1].Name) > categories.NormalizeName(list[i].Name) {
			t.Fatalf("List() not alphabetical: %q before %q", list[i-1].Name, list[i].Name)
		}
	}
}

func TestList_UsageCountIgnoresDeletedTransactions(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	created, err := h.service.Create(ctx, categories.CreateServiceInput{
		UserID: h.userID, Name: "Palestra", DirectionScope: categories.ScopeDebit,
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	categoryID := uuid.MustParse(created.ID)
	walletID := h.seedWallet(t)
	h.seedTransaction(t, walletID, &categoryID)
	h.seedTransaction(t, walletID, &categoryID)
	deleted := h.seedTransaction(t, walletID, &categoryID)
	h.seedTransaction(t, walletID, nil)
	if _, err := h.db.Exec(ctx, `UPDATE transactions SET deleted_at = now() WHERE id = $1`, deleted); err != nil {
		t.Fatalf("soft-delete transaction: %v", err)
	}

	if usage, _, _ := h.find(t, created.ID); usage != 2 {
		t.Errorf("usage_count = %d, want 2 (the soft-deleted transaction must not count)", usage)
	}
}

func TestDelete_LeavesTransactionsAndTemplatesWithoutCategory(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	created, err := h.service.Create(ctx, categories.CreateServiceInput{
		UserID: h.userID, Name: "Cinema", DirectionScope: categories.ScopeDebit,
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	categoryID := uuid.MustParse(created.ID)
	walletID := h.seedWallet(t)
	txID := h.seedTransaction(t, walletID, &categoryID)
	template, err := templates.NewRepository(h.db).Create(ctx, templates.CreateInput{
		UserID: h.userID, Direction: transactions.DirectionDebit, Title: "Cinema", DefaultCategoryID: &categoryID,
	})
	if err != nil {
		t.Fatalf("create template: %v", err)
	}

	if err := h.service.Delete(ctx, h.userID, categoryID); err != nil {
		t.Fatalf("Delete() error = %v", err)
	}

	var txCategory *uuid.UUID
	var version int64
	if err := h.db.QueryRow(ctx, `SELECT category_id, version FROM transactions WHERE id = $1`, txID).Scan(&txCategory, &version); err != nil {
		t.Fatalf("read transaction: %v", err)
	}
	if txCategory != nil {
		t.Errorf("transaction category_id = %v, want NULL", *txCategory)
	}
	if version != 2 {
		t.Errorf("transaction version = %d, want 2 (detaching is an edit)", version)
	}

	var templateCategory *uuid.UUID
	if err := h.db.QueryRow(ctx, `SELECT default_category_id FROM transaction_templates WHERE id = $1`, template.ID).Scan(&templateCategory); err != nil {
		t.Fatalf("read template: %v", err)
	}
	if templateCategory != nil {
		t.Errorf("template default_category_id = %v, want NULL", *templateCategory)
	}

	if _, _, found := h.find(t, created.ID); found {
		t.Error("deleted category must not appear in List() anymore")
	}
}

func TestHide_SystemCategoryIsHiddenAndRestorable(t *testing.T) {
	h := newHarness(t)
	other := newHarness(t)
	ctx := context.Background()

	list, err := h.service.List(ctx, h.userID)
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	var systemID string
	for _, c := range list {
		if c.IsSystem && c.Name == "Svago" {
			systemID = c.ID
		}
	}
	if systemID == "" {
		t.Fatal("expected the seeded system category \"Svago\"")
	}
	id := uuid.MustParse(systemID)

	// Twice: hiding is idempotent.
	for range 2 {
		if err := h.service.Hide(ctx, h.userID, id); err != nil {
			t.Fatalf("Hide() error = %v", err)
		}
	}
	if _, hidden, found := h.find(t, systemID); !found || !hidden {
		t.Errorf("after Hide(): found = %v, hidden = %v; want a hidden category still listed", found, hidden)
	}
	if _, hidden, _ := other.find(t, systemID); hidden {
		t.Error("hiding a system category must only hide it for that user")
	}

	for range 2 {
		if err := h.service.Unhide(ctx, h.userID, id); err != nil {
			t.Fatalf("Unhide() error = %v", err)
		}
	}
	if _, hidden, _ := h.find(t, systemID); hidden {
		t.Error("after Unhide() the category must not be hidden")
	}
}

func TestHide_CustomCategoryIsRejected(t *testing.T) {
	h := newHarness(t)
	ctx := context.Background()

	created, err := h.service.Create(ctx, categories.CreateServiceInput{
		UserID: h.userID, Name: "Viaggi", DirectionScope: categories.ScopeDebit,
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}

	err = h.service.Hide(ctx, h.userID, uuid.MustParse(created.ID))
	var apiErr *apierror.Error
	if !errors.As(err, &apiErr) || apiErr.Status != 422 || apiErr.Code != "CATEGORY_NOT_HIDEABLE" {
		t.Fatalf("Hide() on a custom category = %v, want 422 CATEGORY_NOT_HIDEABLE", err)
	}

	if err := h.service.Hide(ctx, h.userID, uuid.New()); !errors.Is(err, apierror.ErrNotFound) {
		t.Errorf("Hide() on an unknown category = %v, want apierror.ErrNotFound", err)
	}
}
