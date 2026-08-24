package transactions_test

import (
	"context"
	"encoding/json"
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

// clockHarness mirrors harness but with an injectable, mutable clock, for
// tests that need to move time forward (voucher expiry).
type clockHarness struct {
	service  *transactions.Service
	wallets  *wallets.Repository
	userID   uuid.UUID
	walletID uuid.UUID
	now      *time.Time
}

// movableClock lets a test advance "now" between calls without rebuilding
// the service.
type movableClock struct{ now *time.Time }

func (c movableClock) Now() time.Time { return *c.now }

func newClockHarness(t *testing.T) clockHarness {
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
		FirstName: "Test", LastName: "User", Username: "vouchertest" + suffix,
		Email: "vouchertest" + suffix + "@example.com", AvatarBackgroundColor: "#176B5B", AvatarTextColor: "#FFFFFF",
		Locale: "it-IT", Timezone: "Europe/Rome",
	})
	if err != nil {
		t.Fatalf("create test user: %v", err)
	}

	wallet, err := walletsRepo.Create(context.Background(), wallets.CreateRowInput{
		UserID: user.ID, Name: wallets.DefaultName, Currency: "EUR", Type: wallets.TypeOther,
		Icon: wallets.DefaultIcon, Color: wallets.DefaultColor, OpeningBalanceMinor: 0,
	})
	if err != nil {
		t.Fatalf("create test wallet: %v", err)
	}

	now := time.Now().UTC()
	service := transactions.NewService(transactions.Deps{
		DB: dbPool, Transactions: transactionsRepo, Wallets: walletsRepo, Audit: auditRepo,
		Categories: categoriesRepo, Templates: templatesRepo, Clock: movableClock{now: &now},
	})

	return clockHarness{service: service, wallets: walletsRepo, userID: user.ID, walletID: wallet.ID, now: &now}
}

// newVoucherWallet creates a MEAL_VOUCHER wallet (unit value in minor units,
// default expiry policy, no initial quantity) on the given harness's user
// and returns its id.
func newVoucherWallet(t *testing.T, h harness, unitValueMinor int64) uuid.UUID {
	t.Helper()
	body, status, err := h.service.CreateWallet(context.Background(), transactions.CreateWalletInput{
		UserID: h.userID, Name: "Buoni pasto", Type: wallets.TypeMealVoucher, Icon: "restaurant", Color: "#6750A4",
		VoucherUnitValueMinor: &unitValueMinor,
		IdempotencyKey:        uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateWallet(meal voucher) error = %v", err)
	}
	if status != 201 {
		t.Fatalf("CreateWallet(meal voucher) status = %d, want 201", status)
	}
	var decoded struct {
		Wallet struct {
			ID string `json:"id"`
		} `json:"wallet"`
	}
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatalf("decode create wallet response: %v", err)
	}
	return uuid.MustParse(decoded.Wallet.ID)
}

func TestCreateWallet_MealVoucherWithInitialQuantity(t *testing.T) {
	h := newHarness(t, 0)
	unitValue := int64(800) // 8.00 EUR
	qty := 10
	body, status, err := h.service.CreateWallet(context.Background(), transactions.CreateWalletInput{
		UserID: h.userID, Name: "Buoni pasto", Type: wallets.TypeMealVoucher, Icon: "restaurant", Color: "#6750A4",
		VoucherUnitValueMinor: &unitValue, InitialVoucherQuantity: qty, VoucherLoadedAt: time.Now(),
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateWallet() error = %v", err)
	}
	if status != 201 {
		t.Fatalf("status = %d, want 201", status)
	}
	var decoded struct {
		Wallet struct {
			CurrentBalanceMinor int64 `json:"current_balance_minor"`
		} `json:"wallet"`
	}
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if want := unitValue * int64(qty); decoded.Wallet.CurrentBalanceMinor != want {
		t.Fatalf("balance = %d, want %d", decoded.Wallet.CurrentBalanceMinor, want)
	}
}

func TestCreateVoucherCredit_AddThenRemove(t *testing.T) {
	h := newHarness(t, 0)
	walletID := newVoucherWallet(t, h, 800)
	ctx := context.Background()

	addBody, status, err := h.service.CreateVoucherCredit(ctx, transactions.CreateVoucherCreditInput{
		UserID: h.userID, WalletID: walletID, Quantity: 5, OccurredAt: time.Now(),
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateVoucherCredit(add) error = %v", err)
	}
	if status != 201 {
		t.Fatalf("status = %d, want 201", status)
	}
	var decoded struct {
		Wallet struct {
			CurrentBalanceMinor int64 `json:"current_balance_minor"`
		} `json:"wallet"`
	}
	if err := json.Unmarshal(addBody, &decoded); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if decoded.Wallet.CurrentBalanceMinor != 4000 {
		t.Fatalf("balance after +5 vouchers = %d, want 4000", decoded.Wallet.CurrentBalanceMinor)
	}

	removeBody, _, err := h.service.CreateVoucherCredit(ctx, transactions.CreateVoucherCreditInput{
		UserID: h.userID, WalletID: walletID, Quantity: -2, OccurredAt: time.Now(),
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateVoucherCredit(remove) error = %v", err)
	}
	if err := json.Unmarshal(removeBody, &decoded); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if decoded.Wallet.CurrentBalanceMinor != 2400 {
		t.Fatalf("balance after -2 vouchers = %d, want 2400", decoded.Wallet.CurrentBalanceMinor)
	}

	// Removing more than available must fail without changing the balance.
	_, _, err = h.service.CreateVoucherCredit(ctx, transactions.CreateVoucherCreditInput{
		UserID: h.userID, WalletID: walletID, Quantity: -100, OccurredAt: time.Now(),
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err == nil {
		t.Fatal("CreateVoucherCredit(remove 100) error = nil, want VOUCHER_INSUFFICIENT_BALANCE")
	}
	var apiErr *apierror.Error
	if !isAPIError(err, &apiErr) || apiErr.FieldErrors["quantity"] != "VOUCHER_INSUFFICIENT_BALANCE" {
		t.Fatalf("CreateVoucherCredit(remove 100) error = %v, want VOUCHER_INSUFFICIENT_BALANCE", err)
	}
}

func TestCreateVoucherExpense_FullyCoveredNoShortfall(t *testing.T) {
	h := newHarness(t, 0)
	walletID := newVoucherWallet(t, h, 800)
	ctx := context.Background()

	if _, _, err := h.service.CreateVoucherCredit(ctx, transactions.CreateVoucherCreditInput{
		UserID: h.userID, WalletID: walletID, Quantity: 5, OccurredAt: time.Now(),
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	}); err != nil {
		t.Fatalf("seed credit: %v", err)
	}

	body, status, err := h.service.CreateVoucherExpense(ctx, transactions.CreateVoucherExpenseInput{
		UserID: h.userID, VoucherWalletID: walletID, VoucherQuantity: 1, TotalExpenseMinor: 600,
		Title: "Pranzo", OccurredAt: time.Now(), IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateVoucherExpense() error = %v", err)
	}
	if status != 201 {
		t.Fatalf("status = %d, want 201", status)
	}
	var decoded transactions.VoucherExpenseResult
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if decoded.OtherTransaction != nil {
		t.Fatalf("OtherTransaction = %+v, want nil (fully covered by vouchers)", decoded.OtherTransaction)
	}
	if decoded.VoucherWallet.CurrentBalanceMinor != 3200 { // 4 vouchers left * 800
		t.Fatalf("voucher wallet balance = %d, want 3200 (the whole 800 voucher was spent, not just the 600 real cost)", decoded.VoucherWallet.CurrentBalanceMinor)
	}
}

func TestCreateVoucherExpense_ShortfallRequiresAndDebitsOtherWallet(t *testing.T) {
	h := newHarness(t, 100000) // 1000.00 EUR "other" wallet
	walletID := newVoucherWallet(t, h, 800)
	ctx := context.Background()

	if _, _, err := h.service.CreateVoucherCredit(ctx, transactions.CreateVoucherCreditInput{
		UserID: h.userID, WalletID: walletID, Quantity: 2, OccurredAt: time.Now(),
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	}); err != nil {
		t.Fatalf("seed credit: %v", err)
	}

	// Missing other_wallet_id when there IS a shortfall must fail.
	_, _, err := h.service.CreateVoucherExpense(ctx, transactions.CreateVoucherExpenseInput{
		UserID: h.userID, VoucherWalletID: walletID, VoucherQuantity: 1, TotalExpenseMinor: 1500,
		Title: "Cena", OccurredAt: time.Now(), IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err == nil {
		t.Fatal("CreateVoucherExpense(shortfall, no other wallet) error = nil, want OTHER_WALLET_REQUIRED")
	}

	otherWalletID := h.walletID
	body, _, err := h.service.CreateVoucherExpense(ctx, transactions.CreateVoucherExpenseInput{
		UserID: h.userID, VoucherWalletID: walletID, VoucherQuantity: 1, TotalExpenseMinor: 1500,
		OtherWalletID: &otherWalletID, Title: "Cena", OccurredAt: time.Now(),
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateVoucherExpense(shortfall) error = %v", err)
	}
	var decoded transactions.VoucherExpenseResult
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if decoded.OtherTransaction == nil {
		t.Fatal("OtherTransaction = nil, want the shortfall leg")
	}
	if decoded.OtherTransaction.AmountMinor != 700 { // 1500 - 800
		t.Fatalf("shortfall amount = %d, want 700", decoded.OtherTransaction.AmountMinor)
	}
	if decoded.OtherWallet.CurrentBalanceMinor != 99300 {
		t.Fatalf("other wallet balance = %d, want 99300", decoded.OtherWallet.CurrentBalanceMinor)
	}
	if decoded.VoucherWallet.CurrentBalanceMinor != 800 { // 1 voucher left
		t.Fatalf("voucher wallet balance = %d, want 800", decoded.VoucherWallet.CurrentBalanceMinor)
	}
}

func TestDeleteVoucherExpense_ReversesBothLegsAndLots(t *testing.T) {
	h := newHarness(t, 100000)
	walletID := newVoucherWallet(t, h, 800)
	ctx := context.Background()

	if _, _, err := h.service.CreateVoucherCredit(ctx, transactions.CreateVoucherCreditInput{
		UserID: h.userID, WalletID: walletID, Quantity: 3, OccurredAt: time.Now(),
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	}); err != nil {
		t.Fatalf("seed credit: %v", err)
	}

	otherWalletID := h.walletID
	body, _, err := h.service.CreateVoucherExpense(ctx, transactions.CreateVoucherExpenseInput{
		UserID: h.userID, VoucherWalletID: walletID, VoucherQuantity: 2, TotalExpenseMinor: 2000,
		OtherWalletID: &otherWalletID, Title: "Cena", OccurredAt: time.Now(),
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateVoucherExpense() error = %v", err)
	}
	var decoded transactions.VoucherExpenseResult
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatalf("decode: %v", err)
	}

	voucherTxID := uuid.MustParse(decoded.VoucherTransaction.ID)
	snap, err := h.service.Delete(ctx, h.userID, voucherTxID)
	if err != nil {
		t.Fatalf("Delete(voucher leg) error = %v", err)
	}
	if snap.CurrentBalanceMinor != 2400 { // back to 3 vouchers * 800
		t.Fatalf("voucher wallet balance after delete = %d, want 2400", snap.CurrentBalanceMinor)
	}

	otherWallet, err := h.wallets.GetByID(ctx, otherWalletID, h.userID)
	if err != nil {
		t.Fatalf("get other wallet: %v", err)
	}
	if otherWallet.CurrentBalanceMinor != 100000 {
		t.Fatalf("other wallet balance after delete = %d, want restored to 100000", otherWallet.CurrentBalanceMinor)
	}

	// The shortfall leg must be gone too (soft-deleted) — fetching it directly should now 404.
	if _, err := h.service.Get(ctx, h.userID, uuid.MustParse(decoded.OtherTransaction.ID)); err == nil {
		t.Fatal("Get(shortfall leg) after cascade delete = nil error, want not found")
	}
}

func TestGenericEndpoints_RejectMealVoucherWallet(t *testing.T) {
	h := newHarness(t, 0)
	walletID := newVoucherWallet(t, h, 800)
	ctx := context.Background()

	if _, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, WalletID: walletID, Direction: transactions.DirectionDebit, AmountMinor: 500,
		Currency: "EUR", Title: "Not allowed", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	}); err == nil {
		t.Fatal("CreateStandard() on meal-voucher wallet error = nil, want WALLET_IS_MEAL_VOUCHER")
	}

	if _, _, err := h.service.CreateBalanceAdjustment(ctx, transactions.CreateBalanceAdjustmentInput{
		UserID: h.userID, WalletID: walletID, TargetBalanceMinor: 1000,
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	}); err == nil {
		t.Fatal("CreateBalanceAdjustment() on meal-voucher wallet error = nil, want WALLET_IS_MEAL_VOUCHER")
	}

	if _, _, err := h.service.CreateTransfer(ctx, transactions.CreateTransferInput{
		UserID: h.userID, SourceWalletID: h.walletID, DestinationWalletID: walletID, AmountMinor: 500,
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	}); err == nil {
		t.Fatal("CreateTransfer() into meal-voucher wallet error = nil, want WALLET_IS_MEAL_VOUCHER")
	}
}

func TestApplyVoucherLotExpiry_SweepsPastLotsOnNextMutation(t *testing.T) {
	h := newClockHarness(t)
	ctx := context.Background()

	*h.now = time.Date(2026, 6, 15, 12, 0, 0, 0, time.UTC)
	cutoffMonth, expiryMonth, expiryDay := 6, 6, 20
	unitValue := int64(800)

	body, status, err := h.service.CreateWallet(ctx, transactions.CreateWalletInput{
		UserID: h.userID, Name: "Buoni pasto", Type: wallets.TypeMealVoucher, Icon: "restaurant", Color: "#6750A4",
		VoucherUnitValueMinor: &unitValue, VoucherExpiryCutoffMonth: &cutoffMonth,
		VoucherExpiryMonth: &expiryMonth, VoucherExpiryDay: &expiryDay,
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateWallet() error = %v", err)
	}
	if status != 201 {
		t.Fatalf("status = %d, want 201", status)
	}
	var walletDecoded struct {
		Wallet struct {
			ID string `json:"id"`
		} `json:"wallet"`
	}
	if err := json.Unmarshal(body, &walletDecoded); err != nil {
		t.Fatalf("decode: %v", err)
	}
	walletID := uuid.MustParse(walletDecoded.Wallet.ID)

	// Lot 1: loaded June 15 (month 6 <= cutoff 6) -> expires June 20, 2026 (same year).
	creditBody, _, err := h.service.CreateVoucherCredit(ctx, transactions.CreateVoucherCreditInput{
		UserID: h.userID, WalletID: walletID, Quantity: 5,
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateVoucherCredit(lot1) error = %v", err)
	}
	var creditDecoded struct {
		Wallet struct {
			CurrentBalanceMinor int64 `json:"current_balance_minor"`
		} `json:"wallet"`
	}
	if err := json.Unmarshal(creditBody, &creditDecoded); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if creditDecoded.Wallet.CurrentBalanceMinor != 4000 {
		t.Fatalf("balance after lot1 = %d, want 4000", creditDecoded.Wallet.CurrentBalanceMinor)
	}

	// Advance past both the expiry date AND the cutoff month, so lot 2
	// (loaded in July, month 7 > cutoff 6) lands in the *next* bucket
	// (June 20, 2027) instead of colliding with lot 1's now-past date.
	*h.now = time.Date(2026, 7, 5, 12, 0, 0, 0, time.UTC)

	// Lot 2: this mutation must first sweep lot 1 (expired) before adding
	// its own voucher, so the resulting balance reflects only lot 2.
	sweepBody, _, err := h.service.CreateVoucherCredit(ctx, transactions.CreateVoucherCreditInput{
		UserID: h.userID, WalletID: walletID, Quantity: 1,
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateVoucherCredit(lot2, triggers sweep) error = %v", err)
	}
	var sweepDecoded struct {
		Wallet struct {
			CurrentBalanceMinor int64 `json:"current_balance_minor"`
		} `json:"wallet"`
	}
	if err := json.Unmarshal(sweepBody, &sweepDecoded); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if sweepDecoded.Wallet.CurrentBalanceMinor != 800 {
		t.Fatalf("balance after sweep + lot2 = %d, want 800 (5 expired vouchers written off, 1 new voucher added)", sweepDecoded.Wallet.CurrentBalanceMinor)
	}

	lots, err := h.wallets.ListLots(ctx, walletID)
	if err != nil {
		t.Fatalf("ListLots: %v", err)
	}
	var sawExpired, sawActive bool
	for _, l := range lots {
		if l.QuantityExpired == 5 {
			sawExpired = true
		}
		if l.QuantityRemaining == 1 {
			sawActive = true
		}
	}
	if !sawExpired {
		t.Fatal("no lot shows QuantityExpired = 5")
	}
	if !sawActive {
		t.Fatal("no lot shows QuantityRemaining = 1")
	}
}

func isAPIError(err error, target **apierror.Error) bool {
	if e, ok := err.(*apierror.Error); ok {
		*target = e
		return true
	}
	return false
}
