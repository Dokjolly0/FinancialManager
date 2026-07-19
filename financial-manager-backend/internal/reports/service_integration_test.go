package reports

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/categories"
	"financial-manager-backend/internal/platform/clock"
	"financial-manager-backend/internal/platform/database"
	"financial-manager-backend/internal/templates"
	"financial-manager-backend/internal/transactions"
	"financial-manager-backend/internal/users"
	"financial-manager-backend/internal/wallets"
)

// Exercises report aggregation (plan.md section 18) against a real
// PostgreSQL — the dev stack from
// `docker compose -f compose.yaml -f compose.dev.yaml up`. Skips
// automatically if that stack isn't reachable.

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

type harness struct {
	reports      *Service
	transactions *transactions.Service
	categories   *categories.Service
	templates    *templates.Service
	userID       uuid.UUID
}

func newHarness(t *testing.T, openingBalanceMinor int64, now time.Time) harness {
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
	walletsRepo := wallets.NewRepository(dbPool)
	transactionsRepo := transactions.NewRepository(dbPool)
	categoriesRepo := categories.NewRepository(dbPool)
	templatesRepo := templates.NewRepository(dbPool)

	suffix := uuid.NewString()[:8]
	user, err := usersRepo.Create(context.Background(), users.CreateInput{
		FirstName: "Test", LastName: "User",
		Username: "reptest" + suffix, Email: "reptest" + suffix + "@example.com",
		AvatarBackgroundColor: "#176B5B", AvatarTextColor: "#FFFFFF",
		Locale: "it-IT", Timezone: "Europe/Rome",
	})
	if err != nil {
		t.Fatalf("create test user: %v", err)
	}

	wallet, err := walletsRepo.Create(context.Background(), user.ID, "EUR", openingBalanceMinor)
	if err != nil {
		t.Fatalf("create test wallet: %v", err)
	}
	if openingBalanceMinor > 0 {
		if _, err := transactionsRepo.Create(context.Background(), transactions.CreateInput{
			WalletID: wallet.ID, UserID: user.ID, Direction: transactions.DirectionCredit,
			Kind: transactions.KindOpeningBalance, AmountMinor: openingBalanceMinor, Currency: "EUR",
			Title: "Saldo iniziale", OccurredAt: now.AddDate(-1, 0, 0),
		}); err != nil {
			t.Fatalf("create opening balance transaction: %v", err)
		}
	}

	fixedClock := clock.Frozen{At: now}

	transactionsService := transactions.NewService(transactions.Deps{
		DB: dbPool, Transactions: transactionsRepo, Wallets: walletsRepo,
		Audit: transactions.NewAuditRepository(dbPool), Categories: categoriesRepo, Templates: templatesRepo,
		Clock: fixedClock,
	})
	reportsService := NewService(Deps{
		Repo: NewRepository(dbPool), Wallets: walletsRepo, Users: usersRepo, Clock: fixedClock,
	})

	return harness{
		reports: reportsService, transactions: transactionsService,
		categories: categories.NewService(categoriesRepo), templates: templates.NewService(templatesRepo),
		userID: user.ID,
	}
}

func (h harness) createStandard(t *testing.T, direction string, amountMinor int64, title string, occurredAt time.Time, categoryID, templateID *uuid.UUID) {
	t.Helper()
	_, _, err := h.transactions.CreateStandard(context.Background(), transactions.CreateStandardInput{
		UserID: h.userID, Direction: direction, AmountMinor: amountMinor, Currency: "EUR",
		Title: title, CategoryID: categoryID, TemplateID: templateID, OccurredAt: occurredAt,
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("createStandard(%q) error = %v", title, err)
	}
}

func (h harness) ctxInput(preset string, from, to *time.Time, tz string) contextInput {
	return contextInput{UserID: h.userID, Preset: preset, CustomFrom: from, CustomTo: to, Timezone: tz}
}

func customPeriod(from, to time.Time) (string, *time.Time, *time.Time) {
	return PresetCustom, &from, &to
}

func TestSummary_ComputesOpeningClosingAndTotals(t *testing.T) {
	now := time.Date(2026, 6, 15, 10, 0, 0, 0, time.UTC)
	h := newHarness(t, 100000, now) // opening balance 1000.00 EUR, dated a year before now

	from := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 6, 10, 0, 0, 0, 0, time.UTC)
	h.createStandard(t, transactions.DirectionCredit, 50000, "Stipendio", from.AddDate(0, 0, 2), nil, nil)
	h.createStandard(t, transactions.DirectionDebit, 12000, "Spesa", from.AddDate(0, 0, 3), nil, nil)
	// Outside the period: must not affect totals, only the opening balance.
	h.createStandard(t, transactions.DirectionDebit, 30000, "Fuori periodo", from.AddDate(0, 0, -5), nil, nil)

	preset, customFrom, customTo := customPeriod(from, to.AddDate(0, 0, -1))
	summary, err := h.reports.Summary(context.Background(), SummaryInput{
		contextInput: h.ctxInput(preset, customFrom, customTo, "UTC"),
	})
	if err != nil {
		t.Fatalf("Summary() error = %v", err)
	}

	if summary.TotalCreditsMinor != 50000 {
		t.Errorf("TotalCreditsMinor = %d, want 50000", summary.TotalCreditsMinor)
	}
	if summary.TotalDebitsMinor != 12000 {
		t.Errorf("TotalDebitsMinor = %d, want 12000 (the out-of-period debit must be excluded)", summary.TotalDebitsMinor)
	}
	if summary.NetMinor != 38000 {
		t.Errorf("NetMinor = %d, want 38000", summary.NetMinor)
	}
	if summary.TransactionCount != 2 {
		t.Errorf("TransactionCount = %d, want 2", summary.TransactionCount)
	}
	// Opening balance = 100000 (initial) - 30000 (the pre-period debit) = 70000.
	if summary.OpeningBalanceMinor != 70000 {
		t.Errorf("OpeningBalanceMinor = %d, want 70000", summary.OpeningBalanceMinor)
	}
	if summary.ClosingBalanceMinor != 70000+38000 {
		t.Errorf("ClosingBalanceMinor = %d, want %d", summary.ClosingBalanceMinor, 70000+38000)
	}
	if summary.SavingsRatePercent == nil || *summary.SavingsRatePercent < 75.99 || *summary.SavingsRatePercent > 76.01 {
		t.Errorf("SavingsRatePercent = %v, want ~76 (38000/50000*100)", summary.SavingsRatePercent)
	}
	if summary.Currency != "EUR" {
		t.Errorf("Currency = %q, want EUR", summary.Currency)
	}
}

func TestSummary_AllTimeHasZeroOpeningBalanceAndNoFromInResponse(t *testing.T) {
	now := time.Date(2026, 6, 15, 10, 0, 0, 0, time.UTC)
	h := newHarness(t, 100000, now)

	summary, err := h.reports.Summary(context.Background(), SummaryInput{
		contextInput: h.ctxInput(PresetAllTime, nil, nil, "UTC"),
	})
	if err != nil {
		t.Fatalf("Summary() error = %v", err)
	}
	if summary.OpeningBalanceMinor != 0 {
		t.Errorf("OpeningBalanceMinor = %d, want 0 for all_time (nothing precedes it)", summary.OpeningBalanceMinor)
	}
	if summary.From != nil {
		t.Errorf("From = %v, want nil for all_time", summary.From)
	}
	if summary.ClosingBalanceMinor != 100000 {
		t.Errorf("ClosingBalanceMinor = %d, want 100000 (just the opening balance transaction)", summary.ClosingBalanceMinor)
	}
}

func TestSummary_IncludeAdjustmentsTogglesFoldedTotals(t *testing.T) {
	now := time.Date(2026, 6, 15, 10, 0, 0, 0, time.UTC)
	h := newHarness(t, 100000, now)

	from := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 6, 10, 0, 0, 0, 0, time.UTC)
	h.createStandard(t, transactions.DirectionDebit, 10000, "Spesa", from.AddDate(0, 0, 2), nil, nil)
	if _, _, err := h.transactions.CreateBalanceAdjustment(context.Background(), transactions.CreateBalanceAdjustmentInput{
		UserID: h.userID, TargetBalanceMinor: 200000, Reason: "Allineamento",
		OccurredAt: from.AddDate(0, 0, 3), IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	}); err != nil {
		t.Fatalf("CreateBalanceAdjustment() error = %v", err)
	}

	preset, customFrom, customTo := customPeriod(from, to.AddDate(0, 0, -1))

	without, err := h.reports.Summary(context.Background(), SummaryInput{
		contextInput: h.ctxInput(preset, customFrom, customTo, "UTC"), IncludeAdjustments: false,
	})
	if err != nil {
		t.Fatalf("Summary(include_adjustments=false) error = %v", err)
	}
	if without.TotalDebitsMinor != 10000 {
		t.Errorf("without adjustments: TotalDebitsMinor = %d, want 10000 (adjustment excluded)", without.TotalDebitsMinor)
	}

	with, err := h.reports.Summary(context.Background(), SummaryInput{
		contextInput: h.ctxInput(preset, customFrom, customTo, "UTC"), IncludeAdjustments: true,
	})
	if err != nil {
		t.Fatalf("Summary(include_adjustments=true) error = %v", err)
	}
	// The adjustment moved the balance from 90000 to 200000: a credit of 110000.
	if with.TotalCreditsMinor != 110000 {
		t.Errorf("with adjustments: TotalCreditsMinor = %d, want 110000", with.TotalCreditsMinor)
	}

	// The closing balance is always the real balance regardless of the toggle.
	if without.ClosingBalanceMinor != with.ClosingBalanceMinor {
		t.Errorf("closing balance must not depend on include_adjustments: %d vs %d", without.ClosingBalanceMinor, with.ClosingBalanceMinor)
	}
}

func TestBreakdownByTitle_CoalescesByTemplateThenByTitleNormalized(t *testing.T) {
	now := time.Date(2026, 6, 15, 10, 0, 0, 0, time.UTC)
	h := newHarness(t, 0, now)

	tpl, err := h.templates.Create(context.Background(), templates.CreateServiceInput{
		UserID: h.userID, Direction: "DEBIT", Title: "Bar Centrale",
	})
	if err != nil {
		t.Fatalf("create template: %v", err)
	}
	templateID := uuid.MustParse(tpl.ID)

	from := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 6, 10, 0, 0, 0, 0, time.UTC)
	h.createStandard(t, transactions.DirectionDebit, 500, "Bar Centrale", from.AddDate(0, 0, 1), nil, &templateID)
	h.createStandard(t, transactions.DirectionDebit, 700, "Bar Centrale", from.AddDate(0, 0, 2), nil, &templateID)
	h.createStandard(t, transactions.DirectionDebit, 1000, "Spesa unica", from.AddDate(0, 0, 3), nil, nil)

	preset, customFrom, customTo := customPeriod(from, to.AddDate(0, 0, -1))
	result, err := h.reports.Breakdown(context.Background(), BreakdownInput{
		contextInput: h.ctxInput(preset, customFrom, customTo, "UTC"), GroupBy: GroupByTitle,
	})
	if err != nil {
		t.Fatalf("Breakdown() error = %v", err)
	}

	if len(result.Debits) != 2 {
		t.Fatalf("Debits = %+v, want exactly 2 groups (templated Bar Centrale merged, plus Spesa unica)", result.Debits)
	}
	var barTotal, spesaTotal int64
	for _, item := range result.Debits {
		switch item.Label {
		case "Bar Centrale":
			barTotal = item.AmountMinor
			if item.TransactionCount != 2 {
				t.Errorf("Bar Centrale transaction_count = %d, want 2", item.TransactionCount)
			}
		case "Spesa unica":
			spesaTotal = item.AmountMinor
		}
	}
	if barTotal != 1200 {
		t.Errorf("Bar Centrale total = %d, want 1200 (500+700 merged by template_id)", barTotal)
	}
	if spesaTotal != 1000 {
		t.Errorf("Spesa unica total = %d, want 1000", spesaTotal)
	}
}

func TestBreakdownByCategory_UncategorizedGoesToAltro(t *testing.T) {
	now := time.Date(2026, 6, 15, 10, 0, 0, 0, time.UTC)
	h := newHarness(t, 0, now)

	cat, err := h.categories.Create(context.Background(), categories.CreateServiceInput{
		UserID: h.userID, Name: "Trasporti", DirectionScope: categories.ScopeDebit,
	})
	if err != nil {
		t.Fatalf("create category: %v", err)
	}
	catID := uuid.MustParse(cat.ID)

	from := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 6, 10, 0, 0, 0, 0, time.UTC)
	h.createStandard(t, transactions.DirectionDebit, 2000, "Treno", from.AddDate(0, 0, 1), &catID, nil)
	h.createStandard(t, transactions.DirectionDebit, 500, "Non categorizzato", from.AddDate(0, 0, 2), nil, nil)

	preset, customFrom, customTo := customPeriod(from, to.AddDate(0, 0, -1))
	result, err := h.reports.Breakdown(context.Background(), BreakdownInput{
		contextInput: h.ctxInput(preset, customFrom, customTo, "UTC"), GroupBy: GroupByCategory,
	})
	if err != nil {
		t.Fatalf("Breakdown() error = %v", err)
	}

	var foundAltro, foundTrasporti bool
	for _, item := range result.Debits {
		if item.Label == "Altro" {
			foundAltro = true
			if item.AmountMinor != 500 {
				t.Errorf("Altro amount = %d, want 500", item.AmountMinor)
			}
		}
		if item.Label == "Trasporti" {
			foundTrasporti = true
			if item.AmountMinor != 2000 {
				t.Errorf("Trasporti amount = %d, want 2000", item.AmountMinor)
			}
		}
	}
	if !foundAltro {
		t.Error("expected an 'Altro' group for the uncategorized transaction")
	}
	if !foundTrasporti {
		t.Error("expected a 'Trasporti' group")
	}
}

func TestTimeseries_FillsZeroBuckets(t *testing.T) {
	now := time.Date(2026, 6, 15, 10, 0, 0, 0, time.UTC)
	h := newHarness(t, 0, now)

	from := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 6, 5, 0, 0, 0, 0, time.UTC) // 4-day span: June 1-4 inclusive requested as custom to=June 4
	h.createStandard(t, transactions.DirectionCredit, 1000, "Solo giorno 1", from, nil, nil)

	preset, customFrom, customTo := customPeriod(from, to.AddDate(0, 0, -1))
	result, err := h.reports.Timeseries(context.Background(), TimeseriesInput{
		contextInput: h.ctxInput(preset, customFrom, customTo, "UTC"),
	})
	if err != nil {
		t.Fatalf("Timeseries() error = %v", err)
	}
	if result.Granularity != GranularityDaily {
		t.Errorf("Granularity = %q, want daily", result.Granularity)
	}
	if len(result.Points) != 4 {
		t.Fatalf("got %d points, want 4 (June 1, 2, 3, 4 all present)", len(result.Points))
	}
	if result.Points[0].CreditsMinor != 1000 {
		t.Errorf("first point credits = %d, want 1000", result.Points[0].CreditsMinor)
	}
	for i := 1; i < len(result.Points); i++ {
		if result.Points[i].CreditsMinor != 0 || result.Points[i].DebitsMinor != 0 {
			t.Errorf("point %d = %+v, want a zero-filled gap day", i, result.Points[i])
		}
		// The cumulative balance must carry forward even on zero-activity days.
		if result.Points[i].BalanceMinor != result.Points[0].BalanceMinor {
			t.Errorf("point %d balance = %d, want it to carry forward at %d", i, result.Points[i].BalanceMinor, result.Points[0].BalanceMinor)
		}
	}
}

func TestMonthlyComparison_SpansMultipleMonthsFlag(t *testing.T) {
	now := time.Date(2026, 6, 15, 10, 0, 0, 0, time.UTC)
	h := newHarness(t, 0, now)

	singleMonthFrom := time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC)
	singleMonthTo := time.Date(2026, 6, 20, 0, 0, 0, 0, time.UTC)
	preset, customFrom, customTo := customPeriod(singleMonthFrom, singleMonthTo)
	single, err := h.reports.MonthlyComparison(context.Background(), MonthlyComparisonInput{
		contextInput: h.ctxInput(preset, customFrom, customTo, "UTC"),
	})
	if err != nil {
		t.Fatalf("MonthlyComparison() error = %v", err)
	}
	if single.SpansMultipleMonths {
		t.Error("a period entirely within June must report spans_multiple_months=false")
	}

	multiFrom := time.Date(2026, 5, 15, 0, 0, 0, 0, time.UTC)
	multiTo := time.Date(2026, 6, 15, 0, 0, 0, 0, time.UTC)
	preset2, customFrom2, customTo2 := customPeriod(multiFrom, multiTo)
	h.createStandard(t, transactions.DirectionCredit, 5000, "Maggio", multiFrom.AddDate(0, 0, 1), nil, nil)
	h.createStandard(t, transactions.DirectionCredit, 7000, "Giugno", multiTo.AddDate(0, 0, -1), nil, nil)

	multi, err := h.reports.MonthlyComparison(context.Background(), MonthlyComparisonInput{
		contextInput: h.ctxInput(preset2, customFrom2, customTo2, "UTC"),
	})
	if err != nil {
		t.Fatalf("MonthlyComparison() error = %v", err)
	}
	if !multi.SpansMultipleMonths {
		t.Error("a period crossing May into June must report spans_multiple_months=true")
	}
	if len(multi.Months) != 2 {
		t.Fatalf("got %d months, want 2 (May and June)", len(multi.Months))
	}
	if multi.Months[0].CreditsMinor != 5000 || multi.Months[1].CreditsMinor != 7000 {
		t.Errorf("months = %+v, want [5000, 7000]", multi.Months)
	}
}
