package ai_test

import (
	"context"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/categories"
	"financial-manager-backend/internal/transactions"
)

func (h *harness) seedCategorized(category uuid.UUID, amount int64, title string, at time.Time) {
	h.t.Helper()
	if _, err := transactions.NewRepository(h.db).Create(context.Background(), transactions.CreateInput{
		WalletID: h.walletID, UserID: h.userID, Direction: transactions.DirectionDebit, Kind: transactions.KindStandard,
		AmountMinor: amount, Currency: "EUR", Title: title, OccurredAt: at, CategoryID: &category,
	}); err != nil {
		h.t.Fatal(err)
	}
}

func filteredBody(filters map[string]any, period map[string]any) map[string]any {
	if period == nil {
		period = map[string]any{"preset": "last_12_months"}
	}
	return map[string]any{
		"preset": "MONTHLY_CHECKUP",
		"period": period,
		"options": map[string]any{
			"sections":             []string{"monthly", "categories", "titles", "transfers", "recurring"},
			"include_transactions": true,
			"filters":              filters,
		},
	}
}

func TestPreview_HistoryFilters(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-filter-0001")
	h.seedLedger()

	// Expenses whose title contains "netflix": only the 4 subscriptions.
	r := h.do(http.MethodPost, "/v1/ai/analyses/preview", filteredBody(map[string]any{"direction": "DEBIT", "title": "netFLIX"}, nil))
	h.mustStatus(r, http.StatusOK)
	data := r.body["data_block"].(string)
	for _, want := range []string{
		"## Filtri applicati", "- Solo uscite", `contiene: "netFLIX"`,
		"0.00 | 51.96 | -51.96 | 4 |", "Saldi non disponibili", "Non inclusi: con i filtri attivi",
		"Netflix | 4 | 12.99",
	} {
		if !strings.Contains(data, want) {
			t.Errorf("filtered block lacks %q:\n%s", want, data)
		}
	}
	for _, absent := range []string{"Affitto", "Stipendio", "Conto | Contanti | 100.00"} {
		if strings.Contains(data, absent) {
			t.Errorf("filtered block contains %q", absent)
		}
	}
	if d := r.body["disclosure"].(map[string]any); d["transaction_count"] != float64(4) || d["transactions_omitted"] != float64(0) {
		t.Fatalf("disclosure = %v", d)
	}

	// Amount bounds.
	r = h.do(http.MethodPost, "/v1/ai/analyses/preview", filteredBody(map[string]any{"amount_min_minor": 4000, "amount_max_minor": 100000}, nil))
	h.mustStatus(r, http.StatusOK)
	if data := r.body["data_block"].(string); !strings.Contains(data, "0.00 | 3245.50 | -3245.50 | 5 |") {
		t.Fatalf("amount filter:\n%s", data)
	}
}

func TestPreview_CategoryFilter(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-filter-0002")
	cat, err := categories.NewRepository(h.db).Create(context.Background(), categories.CreateInput{
		OwnerUserID: h.userID, Name: "Svago " + uuid.NewString()[:6], DirectionScope: categories.ScopeDebit,
	})
	if err != nil {
		t.Fatal(err)
	}
	h.seedCategorized(cat.ID, 2500, "Cinema", time.Date(2026, 9, 1, 20, 0, 0, 0, time.UTC))
	h.seed(h.walletID, transactions.DirectionDebit, transactions.KindStandard, 9000, "Bolletta", time.Date(2026, 9, 2, 9, 0, 0, 0, time.UTC))

	r := h.do(http.MethodPost, "/v1/ai/analyses/preview", filteredBody(map[string]any{"category_id": cat.ID.String()}, nil))
	h.mustStatus(r, http.StatusOK)
	data := r.body["data_block"].(string)
	if !strings.Contains(data, "- Categoria: "+cat.Name) || !strings.Contains(data, "Cinema") || strings.Contains(data, "Bolletta") {
		t.Fatalf("category filter:\n%s", data)
	}

	other := newHarness(t)
	otherCat, _ := categories.NewRepository(other.db).Create(context.Background(), categories.CreateInput{
		OwnerUserID: other.userID, Name: "Altrui " + uuid.NewString()[:6], DirectionScope: categories.ScopeDebit,
	})
	r = h.do(http.MethodPost, "/v1/ai/analyses/preview", filteredBody(map[string]any{"category_id": otherCat.ID.String()}, nil))
	if r.fieldError("options.filters.category_id") != "CATEGORY_NOT_FOUND" {
		t.Fatalf("someone else's category = %d %s", r.status, r.raw)
	}
}

func TestPreview_FilterValidationAndOpenEndedPeriods(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-filter-0003")
	h.seedLedger()

	for name, c := range map[string]struct {
		filters map[string]any
		field   string
	}{
		"bad direction": {map[string]any{"direction": "SIDEWAYS"}, "options.filters.direction"},
		"min above max": {map[string]any{"amount_min_minor": 500, "amount_max_minor": 100}, "options.filters.amount_max_minor"},
		"negative":      {map[string]any{"amount_min_minor": -1}, "options.filters.amount_min_minor"},
		"long title":    {map[string]any{"title": strings.Repeat("x", 121)}, "options.filters.title"},
	} {
		t.Run(name, func(t *testing.T) {
			r := h.do(http.MethodPost, "/v1/ai/analyses/preview", filteredBody(c.filters, nil))
			if r.fieldError(c.field) == "" {
				t.Fatalf("= %d %s, want a %s error", r.status, r.raw, c.field)
			}
		})
	}

	// Only "from": up to today.
	r := h.do(http.MethodPost, "/v1/ai/analyses/preview", filteredBody(nil, map[string]any{"preset": "custom", "from": "2026-08-01"}))
	h.mustStatus(r, http.StatusOK)
	if r.body["period_from"] != "2026-08-01" || r.body["period_to"] != "2026-10-20" {
		t.Fatalf("from only = %v → %v", r.body["period_from"], r.body["period_to"])
	}
	// Only "to": the whole history up to that day.
	r = h.do(http.MethodPost, "/v1/ai/analyses/preview", filteredBody(nil, map[string]any{"preset": "custom", "to": "2026-07-31"}))
	h.mustStatus(r, http.StatusOK)
	if r.body["period_from"] != nil || r.body["period_to"] != "2026-07-31" {
		t.Fatalf("to only = %v → %v", r.body["period_from"], r.body["period_to"])
	}
	if data := r.body["data_block"].(string); !strings.Contains(data, "4000.00 |") {
		t.Fatalf("June and July salaries expected:\n%s", data)
	}

	// No filter object, or an empty one, changes nothing.
	plain := h.do(http.MethodPost, "/v1/ai/analyses/preview", filteredBody(nil, nil))
	empty := h.do(http.MethodPost, "/v1/ai/analyses/preview", filteredBody(map[string]any{"title": "  "}, nil))
	if plain.body["data_fingerprint"] != empty.body["data_fingerprint"] {
		t.Fatal("an empty filter must behave like no filter")
	}
}
