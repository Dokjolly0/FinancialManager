package transactions_test

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/categories"
	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/clock"
	"financial-manager-backend/internal/platform/database"
	"financial-manager-backend/internal/templates"
	"financial-manager-backend/internal/transactions"
	"financial-manager-backend/internal/users"
	"financial-manager-backend/internal/wallets"
)

// Exercises the whole ledger lifecycle (plan.md section 13) against a real
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
	service            *transactions.Service
	wallets            *wallets.Repository
	transactions       *transactions.Repository
	categories         *categories.Repository
	templates          *templates.Repository
	userID             uuid.UUID
	walletID           uuid.UUID
	openingTransaction uuid.UUID // zero if openingBalanceMinor was 0
}

func newHarness(t *testing.T, openingBalanceMinor int64) harness {
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
	auditRepo := transactions.NewAuditRepository(dbPool)
	categoriesRepo := categories.NewRepository(dbPool)
	templatesRepo := templates.NewRepository(dbPool)

	suffix := uuid.NewString()[:8]
	user, err := usersRepo.Create(context.Background(), users.CreateInput{
		FirstName:             "Test",
		LastName:              "User",
		Username:              "txtest" + suffix,
		Email:                 "txtest" + suffix + "@example.com",
		AvatarBackgroundColor: "#176B5B",
		AvatarTextColor:       "#FFFFFF",
		Locale:                "it-IT",
		Timezone:              "Europe/Rome",
	})
	if err != nil {
		t.Fatalf("create test user: %v", err)
	}

	wallet, err := walletsRepo.Create(context.Background(), user.ID, "EUR", openingBalanceMinor)
	if err != nil {
		t.Fatalf("create test wallet: %v", err)
	}

	// Mirror what registration does in production (plan.md section 7.3):
	// the wallet's initial balance is always backed by a matching
	// OPENING_BALANCE ledger row, which is what makes Reconcile() meaningful.
	var openingTxID uuid.UUID
	if openingBalanceMinor > 0 {
		opening, err := transactionsRepo.Create(context.Background(), transactions.CreateInput{
			WalletID: wallet.ID, UserID: user.ID, Direction: transactions.DirectionCredit,
			Kind: transactions.KindOpeningBalance, AmountMinor: openingBalanceMinor, Currency: "EUR",
			Title: "Saldo iniziale", OccurredAt: time.Now(),
		})
		if err != nil {
			t.Fatalf("create opening balance transaction: %v", err)
		}
		openingTxID = opening.ID
	}

	service := transactions.NewService(transactions.Deps{
		DB:           dbPool,
		Transactions: transactionsRepo,
		Wallets:      walletsRepo,
		Audit:        auditRepo,
		Categories:   categoriesRepo,
		Templates:    templatesRepo,
		Clock:        clock.System{},
	})

	return harness{
		service:            service,
		wallets:            walletsRepo,
		transactions:       transactionsRepo,
		categories:         categoriesRepo,
		templates:          templatesRepo,
		userID:             user.ID,
		walletID:           wallet.ID,
		openingTransaction: openingTxID,
	}
}

func decodeCreateResponse(t *testing.T, body []byte) (transactionID string, balanceMinor int64) {
	t.Helper()
	var decoded struct {
		Transaction struct {
			ID string `json:"id"`
		} `json:"transaction"`
		Wallet struct {
			CurrentBalanceMinor int64 `json:"current_balance_minor"`
		} `json:"wallet"`
	}
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	return decoded.Transaction.ID, decoded.Wallet.CurrentBalanceMinor
}

func TestCreateStandard_DebitsWalletAndIsIdempotent(t *testing.T) {
	h := newHarness(t, 100000) // 1000.00 EUR
	ctx := context.Background()

	key := uuid.New()
	body, status, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, Direction: transactions.DirectionDebit, AmountMinor: 5000,
		Currency: "EUR", Title: "Spesa supermercato", IdempotencyKey: key, RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateStandard() error = %v", err)
	}
	if status != 201 {
		t.Fatalf("status = %d, want 201", status)
	}

	_, balance := decodeCreateResponse(t, body)
	if balance != 95000 {
		t.Fatalf("balance after debit = %d, want 95000", balance)
	}

	// Retry with the same key must not double-debit.
	retryBody, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, Direction: transactions.DirectionDebit, AmountMinor: 5000,
		Currency: "EUR", Title: "Spesa supermercato", IdempotencyKey: key, RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("retry CreateStandard() error = %v", err)
	}
	_, retryBalance := decodeCreateResponse(t, retryBody)
	if retryBalance != 95000 {
		t.Fatalf("balance after idempotent retry = %d, want unchanged 95000", retryBalance)
	}

	wallet, err := h.wallets.GetByUserID(ctx, h.userID)
	if err != nil {
		t.Fatalf("GetByUserID() error = %v", err)
	}
	if wallet.CurrentBalanceMinor != 95000 {
		t.Fatalf("stored wallet balance = %d, want 95000 (no double debit)", wallet.CurrentBalanceMinor)
	}
}

func TestUpdateStandard_AppliesOnlyTheDifference(t *testing.T) {
	h := newHarness(t, 100000)
	ctx := context.Background()

	createBody, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, Direction: transactions.DirectionDebit, AmountMinor: 3000,
		Currency: "EUR", Title: "Bar", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateStandard() error = %v", err)
	}
	txIDStr, balance := decodeCreateResponse(t, createBody)
	if balance != 97000 {
		t.Fatalf("balance after create = %d, want 97000", balance)
	}
	txID := uuid.MustParse(txIDStr)

	updated, err := h.service.UpdateStandard(ctx, transactions.UpdateStandardInput{
		UserID: h.userID, TransactionID: txID, Direction: transactions.DirectionDebit,
		AmountMinor: 5000, Title: "Bar (corretto)", ExpectedVersion: 1,
	})
	if err != nil {
		t.Fatalf("UpdateStandard() error = %v", err)
	}
	if updated.Wallet.CurrentBalanceMinor != 95000 {
		t.Fatalf("balance after update = %d, want 95000 (only the +2000 diff applied)", updated.Wallet.CurrentBalanceMinor)
	}

	// Stale version must be rejected as a conflict.
	_, err = h.service.UpdateStandard(ctx, transactions.UpdateStandardInput{
		UserID: h.userID, TransactionID: txID, Direction: transactions.DirectionDebit,
		AmountMinor: 6000, Title: "Bar (di nuovo)", ExpectedVersion: 1, // stale: real version is now 2
	})
	var apiErr *apierror.Error
	if !errors.As(err, &apiErr) || apiErr.Status != 409 {
		t.Fatalf("expected a 409 conflict for a stale version, got %v", err)
	}
}

func TestDelete_ReversesBalanceAndForbidsOpeningBalance(t *testing.T) {
	h := newHarness(t, 100000)
	ctx := context.Background()

	createBody, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, Direction: transactions.DirectionCredit, AmountMinor: 2000,
		Currency: "EUR", Title: "Rimborso", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateStandard() error = %v", err)
	}
	txIDStr, balance := decodeCreateResponse(t, createBody)
	if balance != 102000 {
		t.Fatalf("balance after credit = %d, want 102000", balance)
	}

	walletAfterDelete, err := h.service.Delete(ctx, h.userID, uuid.MustParse(txIDStr))
	if err != nil {
		t.Fatalf("Delete() error = %v", err)
	}
	if walletAfterDelete.CurrentBalanceMinor != 100000 {
		t.Fatalf("balance after delete = %d, want 100000 (credit reversed)", walletAfterDelete.CurrentBalanceMinor)
	}

	// OPENING_BALANCE must not be deletable through the ordinary flow
	// (plan.md section 13.4) — harness already created one for this wallet.
	_, err = h.service.Delete(ctx, h.userID, h.openingTransaction)
	var apiErr *apierror.Error
	if !errors.As(err, &apiErr) || apiErr.Status != 403 {
		t.Fatalf("expected a 403 forbidding OPENING_BALANCE deletion, got %v", err)
	}
}

func TestBalanceAdjustment_SetsExactTarget(t *testing.T) {
	h := newHarness(t, 50000)
	ctx := context.Background()

	body, status, err := h.service.CreateBalanceAdjustment(ctx, transactions.CreateBalanceAdjustmentInput{
		UserID: h.userID, TargetBalanceMinor: 47000, Reason: "Allineamento con saldo reale",
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateBalanceAdjustment() error = %v", err)
	}
	if status != 201 {
		t.Fatalf("status = %d, want 201", status)
	}

	var decoded struct {
		Transaction struct {
			Kind      string `json:"kind"`
			Direction string `json:"direction"`
		} `json:"transaction"`
		Wallet struct {
			CurrentBalanceMinor int64 `json:"current_balance_minor"`
		} `json:"wallet"`
	}
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if decoded.Wallet.CurrentBalanceMinor != 47000 {
		t.Fatalf("balance after adjustment = %d, want 47000", decoded.Wallet.CurrentBalanceMinor)
	}
	if decoded.Transaction.Kind != transactions.KindBalanceAdjustment {
		t.Errorf("kind = %q, want %q", decoded.Transaction.Kind, transactions.KindBalanceAdjustment)
	}
	if decoded.Transaction.Direction != transactions.DirectionDebit {
		t.Errorf("direction = %q, want DEBIT (target < current)", decoded.Transaction.Direction)
	}
}

func TestReconcile_FindsNoMismatchAfterNormalOperations(t *testing.T) {
	h := newHarness(t, 100000)
	ctx := context.Background()

	if _, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, Direction: transactions.DirectionDebit, AmountMinor: 2500,
		Currency: "EUR", Title: "Caffè", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	}); err != nil {
		t.Fatalf("CreateStandard() error = %v", err)
	}

	mismatches, err := h.service.Reconcile(ctx)
	if err != nil {
		t.Fatalf("Reconcile() error = %v", err)
	}
	for _, m := range mismatches {
		if m.WalletID == h.walletID {
			t.Fatalf("unexpected mismatch for test wallet: stored=%d recalculated=%d", m.StoredBalance, m.RecalculatedSum)
		}
	}
}

// TestCrossUserAccess_IsAlwaysRejected covers plan.md section 19.1/23.8
// (BOLA/IDOR): user B must not be able to read, edit, or delete user A's
// transaction just by knowing its ID.
func TestCrossUserAccess_IsAlwaysRejected(t *testing.T) {
	owner := newHarness(t, 100000)
	intruder := newHarness(t, 0)
	ctx := context.Background()

	body, _, err := owner.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: owner.userID, Direction: transactions.DirectionDebit, AmountMinor: 1500,
		Currency: "EUR", Title: "Privato di A", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateStandard() error = %v", err)
	}
	txIDStr, _ := decodeCreateResponse(t, body)
	txID, err := uuid.Parse(txIDStr)
	if err != nil {
		t.Fatalf("parse transaction id: %v", err)
	}

	if _, err := owner.service.Get(ctx, intruder.userID, txID); !errors.Is(err, apierror.ErrNotFound) {
		t.Errorf("Get() by intruder = %v, want apierror.ErrNotFound", err)
	}

	_, err = owner.service.UpdateStandard(ctx, transactions.UpdateStandardInput{
		UserID: intruder.userID, TransactionID: txID, Direction: transactions.DirectionDebit,
		AmountMinor: 999999, Title: "Hijacked", ExpectedVersion: 1,
	})
	if !errors.Is(err, apierror.ErrNotFound) {
		t.Errorf("UpdateStandard() by intruder = %v, want apierror.ErrNotFound", err)
	}

	if _, err := owner.service.Delete(ctx, intruder.userID, txID); !errors.Is(err, apierror.ErrNotFound) {
		t.Errorf("Delete() by intruder = %v, want apierror.ErrNotFound", err)
	}

	// The transaction must still exist, untouched, for its real owner.
	if _, err := owner.service.Get(ctx, owner.userID, txID); err != nil {
		t.Errorf("owner's own Get() after intruder attempts = %v, want no error", err)
	}
}
