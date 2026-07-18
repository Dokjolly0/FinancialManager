package transactions_test

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/categories"
	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/templates"
	"financial-manager-backend/internal/transactions"
)

// Exercises the Fase 5 additions to the ledger: category/template linkage
// (plan.md section 4.4, 11.10) and the extended list filters (section 17.1).

func TestCreateStandard_LinksValidCategoryAndBumpsTemplateUsage(t *testing.T) {
	h := newHarness(t, 100000)
	ctx := context.Background()

	categoryService := categories.NewService(h.categories)
	category, err := categoryService.Create(ctx, categories.CreateServiceInput{
		UserID: h.userID, Name: "Trasporti pubblici", DirectionScope: categories.ScopeDebit,
	})
	if err != nil {
		t.Fatalf("create category: %v", err)
	}
	categoryID := uuid.MustParse(category.ID)

	templateService := templates.NewService(h.templates)
	template, err := templateService.Create(ctx, templates.CreateServiceInput{
		UserID: h.userID, Direction: "DEBIT", Title: "Biglietto autobus",
	})
	if err != nil {
		t.Fatalf("create template: %v", err)
	}
	templateID := uuid.MustParse(template.ID)

	body, status, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, Direction: transactions.DirectionDebit, AmountMinor: 150,
		Currency: "EUR", Title: "Biglietto autobus", CategoryID: &categoryID, TemplateID: &templateID,
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateStandard() error = %v", err)
	}
	if status != 201 {
		t.Fatalf("status = %d, want 201", status)
	}

	var decoded struct {
		Transaction struct {
			CategoryID string `json:"category_id"`
			TemplateID string `json:"template_id"`
		} `json:"transaction"`
	}
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if decoded.Transaction.CategoryID != category.ID {
		t.Errorf("category_id = %q, want %q", decoded.Transaction.CategoryID, category.ID)
	}
	if decoded.Transaction.TemplateID != template.ID {
		t.Errorf("template_id = %q, want %q", decoded.Transaction.TemplateID, template.ID)
	}

	// The template's usage stats must reflect this creation (plan.md
	// section 4.4: "ordinati per frequenza e utilizzo recente").
	refreshed, err := templateService.Search(ctx, templates.SearchInput{UserID: h.userID, Direction: "DEBIT", Query: "biglietto"})
	if err != nil {
		t.Fatalf("Search() error = %v", err)
	}
	if len(refreshed) != 1 || refreshed[0].UsageCount != 1 {
		t.Fatalf("template usage after creation = %+v, want usage_count 1", refreshed)
	}
}

func TestCreateStandard_RejectsAnotherUsersCategoryAndTemplate(t *testing.T) {
	h := newHarness(t, 100000)
	other := newHarness(t, 0)
	ctx := context.Background()

	categoryService := categories.NewService(other.categories)
	foreignCategory, err := categoryService.Create(ctx, categories.CreateServiceInput{
		UserID: other.userID, Name: "Categoria altrui", DirectionScope: categories.ScopeDebit,
	})
	if err != nil {
		t.Fatalf("create foreign category: %v", err)
	}
	foreignCategoryID := uuid.MustParse(foreignCategory.ID)

	_, _, err = h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, Direction: transactions.DirectionDebit, AmountMinor: 500,
		Currency: "EUR", Title: "Tentativo", CategoryID: &foreignCategoryID,
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	var apiErr *apierror.Error
	if !errors.As(err, &apiErr) || apiErr.Status != 422 {
		t.Fatalf("expected a 422 validation error referencing another user's category, got %v", err)
	}

	// The whole mutation must have rolled back — no partial transaction left behind.
	wallet, getErr := h.wallets.GetByUserID(ctx, h.userID)
	if getErr != nil {
		t.Fatalf("GetByUserID() error = %v", getErr)
	}
	if wallet.CurrentBalanceMinor != 100000 {
		t.Fatalf("wallet balance = %d, want unchanged 100000 after the rejected create", wallet.CurrentBalanceMinor)
	}
}

func TestList_FiltersByTitleAmountRangeAndCategory(t *testing.T) {
	h := newHarness(t, 1000000)
	ctx := context.Background()

	categoryService := categories.NewService(h.categories)
	groceries, err := categoryService.Create(ctx, categories.CreateServiceInput{
		UserID: h.userID, Name: "Spesa quotidiana", DirectionScope: categories.ScopeDebit,
	})
	if err != nil {
		t.Fatalf("create category: %v", err)
	}
	groceriesID := uuid.MustParse(groceries.ID)

	if _, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, Direction: transactions.DirectionDebit, AmountMinor: 2000,
		Currency: "EUR", Title: "Supermercato Conad", CategoryID: &groceriesID,
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	}); err != nil {
		t.Fatalf("create tx1: %v", err)
	}
	if _, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, Direction: transactions.DirectionDebit, AmountMinor: 9000,
		Currency: "EUR", Title: "Bar Centrale",
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	}); err != nil {
		t.Fatalf("create tx2: %v", err)
	}

	byTitle, err := h.service.List(ctx, transactions.ListFilter{UserID: h.userID, Title: "superm", Limit: 10})
	if err != nil {
		t.Fatalf("List(title) error = %v", err)
	}
	if len(byTitle.Transactions) != 1 || byTitle.Transactions[0].Title != "Supermercato Conad" {
		t.Fatalf("List(title=superm) = %+v, want exactly \"Supermercato Conad\"", byTitle.Transactions)
	}

	byAmount, err := h.service.List(ctx, transactions.ListFilter{UserID: h.userID, Kind: transactions.KindStandard, AmountMinMinor: 5000, Limit: 10})
	if err != nil {
		t.Fatalf("List(amount_min) error = %v", err)
	}
	if len(byAmount.Transactions) != 1 || byAmount.Transactions[0].Title != "Bar Centrale" {
		t.Fatalf("List(amount_min=5000) = %+v, want exactly \"Bar Centrale\"", byAmount.Transactions)
	}

	byCategory, err := h.service.List(ctx, transactions.ListFilter{UserID: h.userID, CategoryID: groceriesID, Limit: 10})
	if err != nil {
		t.Fatalf("List(category_id) error = %v", err)
	}
	if len(byCategory.Transactions) != 1 || byCategory.Transactions[0].Title != "Supermercato Conad" {
		t.Fatalf("List(category_id=groceries) = %+v, want exactly \"Supermercato Conad\"", byCategory.Transactions)
	}
}

func TestList_FiltersByOccurredAtRange(t *testing.T) {
	h := newHarness(t, 1000000)
	ctx := context.Background()

	past := time.Date(2020, 1, 15, 10, 0, 0, 0, time.UTC)
	recent := time.Now().UTC()

	if _, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, Direction: transactions.DirectionDebit, AmountMinor: 1000,
		Currency: "EUR", Title: "Vecchia spesa", OccurredAt: past,
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	}); err != nil {
		t.Fatalf("create past tx: %v", err)
	}
	if _, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, Direction: transactions.DirectionDebit, AmountMinor: 1000,
		Currency: "EUR", Title: "Spesa recente", OccurredAt: recent,
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	}); err != nil {
		t.Fatalf("create recent tx: %v", err)
	}

	result, err := h.service.List(ctx, transactions.ListFilter{
		UserID: h.userID, Kind: transactions.KindStandard,
		OccurredFrom: time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC), Limit: 10,
	})
	if err != nil {
		t.Fatalf("List(occurred_from) error = %v", err)
	}
	if len(result.Transactions) != 1 || result.Transactions[0].Title != "Spesa recente" {
		t.Fatalf("List(occurred_from=2025) = %+v, want exactly \"Spesa recente\"", result.Transactions)
	}
}
