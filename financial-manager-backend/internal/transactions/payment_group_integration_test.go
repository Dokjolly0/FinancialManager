package transactions_test

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/transactions"
)

// Exercises the "pagamenti collegati" linked-transactions feature (plan.md):
// an acconto (deposit) and a saldo (final payment) linked together as
// installments of the same logical expense. The link is purely a display
// grouping — every member keeps its own STANDARD ledger entry and its own
// effect on the wallet balance, so these tests assert both that linking
// works and that it never distorts the ordinary accounting.

func TestCreateStandard_LinkToTransaction_SharesGroupAndBothDebitTheWallet(t *testing.T) {
	h := newHarness(t, 100000) // 1000.00 EUR
	ctx := context.Background()

	accontoBody, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, WalletID: h.walletID, Direction: transactions.DirectionDebit, AmountMinor: 10000,
		Currency: "EUR", Title: "Acconto viaggio", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateStandard(acconto) error = %v", err)
	}
	accontoIDStr, balanceAfterAcconto := decodeCreateResponse(t, accontoBody)
	if balanceAfterAcconto != 90000 {
		t.Fatalf("balance after acconto = %d, want 90000", balanceAfterAcconto)
	}
	accontoID := uuid.MustParse(accontoIDStr)

	saldoBody, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, WalletID: h.walletID, Direction: transactions.DirectionDebit, AmountMinor: 30000,
		Currency: "EUR", Title: "Saldo viaggio", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
		LinkToTransactionID: &accontoID,
	})
	if err != nil {
		t.Fatalf("CreateStandard(saldo, linked) error = %v", err)
	}
	saldoIDStr, balanceAfterSaldo := decodeCreateResponse(t, saldoBody)
	if balanceAfterSaldo != 60000 {
		t.Fatalf("balance after saldo = %d, want 60000 (both payments applied individually)", balanceAfterSaldo)
	}
	saldoID := uuid.MustParse(saldoIDStr)

	accontoAfter, err := h.service.Get(ctx, h.userID, accontoID)
	if err != nil {
		t.Fatalf("Get(acconto) error = %v", err)
	}
	saldoAfter, err := h.service.Get(ctx, h.userID, saldoID)
	if err != nil {
		t.Fatalf("Get(saldo) error = %v", err)
	}
	if accontoAfter.PaymentGroupID == nil || saldoAfter.PaymentGroupID == nil {
		t.Fatalf("expected both legs to have a payment_group_id, got acconto=%v saldo=%v",
			accontoAfter.PaymentGroupID, saldoAfter.PaymentGroupID)
	}
	if *accontoAfter.PaymentGroupID != *saldoAfter.PaymentGroupID {
		t.Fatalf("payment_group_id mismatch: acconto=%s saldo=%s", *accontoAfter.PaymentGroupID, *saldoAfter.PaymentGroupID)
	}
}

func TestCreateStandard_LinkToTransaction_ThirdMemberReusesExistingGroup(t *testing.T) {
	h := newHarness(t, 100000)
	ctx := context.Background()

	accontoBody, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, WalletID: h.walletID, Direction: transactions.DirectionDebit, AmountMinor: 10000,
		Currency: "EUR", Title: "Acconto", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateStandard(acconto) error = %v", err)
	}
	accontoIDStr, _ := decodeCreateResponse(t, accontoBody)
	accontoID := uuid.MustParse(accontoIDStr)

	secondBody, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, WalletID: h.walletID, Direction: transactions.DirectionDebit, AmountMinor: 5000,
		Currency: "EUR", Title: "Secondo acconto", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
		LinkToTransactionID: &accontoID,
	})
	if err != nil {
		t.Fatalf("CreateStandard(second, linked to acconto) error = %v", err)
	}
	secondIDStr, _ := decodeCreateResponse(t, secondBody)
	secondID := uuid.MustParse(secondIDStr)

	// Linking a third payment to the SAME original target (not to the
	// second leg) must join the group the first link already created,
	// never mint a second, separate group.
	thirdBody, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, WalletID: h.walletID, Direction: transactions.DirectionDebit, AmountMinor: 25000,
		Currency: "EUR", Title: "Saldo", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
		LinkToTransactionID: &accontoID,
	})
	if err != nil {
		t.Fatalf("CreateStandard(third, linked to acconto) error = %v", err)
	}
	thirdIDStr, _ := decodeCreateResponse(t, thirdBody)
	thirdID := uuid.MustParse(thirdIDStr)

	acconto, err := h.service.Get(ctx, h.userID, accontoID)
	if err != nil {
		t.Fatalf("Get(acconto) error = %v", err)
	}
	second, err := h.service.Get(ctx, h.userID, secondID)
	if err != nil {
		t.Fatalf("Get(second) error = %v", err)
	}
	third, err := h.service.Get(ctx, h.userID, thirdID)
	if err != nil {
		t.Fatalf("Get(third) error = %v", err)
	}
	if acconto.PaymentGroupID == nil || second.PaymentGroupID == nil || third.PaymentGroupID == nil {
		t.Fatalf("expected all three legs to have a payment_group_id")
	}
	if *acconto.PaymentGroupID != *second.PaymentGroupID || *second.PaymentGroupID != *third.PaymentGroupID {
		t.Fatalf("expected one shared group, got acconto=%s second=%s third=%s",
			*acconto.PaymentGroupID, *second.PaymentGroupID, *third.PaymentGroupID)
	}

	groups, err := h.service.ListPaymentGroupMembers(ctx, h.userID, uuid.MustParse(*acconto.PaymentGroupID))
	if err != nil {
		t.Fatalf("ListPaymentGroupMembers() error = %v", err)
	}
	if len(groups.Transactions) != 3 {
		t.Fatalf("group member count = %d, want 3", len(groups.Transactions))
	}
}

func TestCreateStandard_LinkTarget_NotFound(t *testing.T) {
	h := newHarness(t, 100000)
	ctx := context.Background()

	missing := uuid.New()
	_, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, WalletID: h.walletID, Direction: transactions.DirectionDebit, AmountMinor: 1000,
		Currency: "EUR", Title: "Saldo", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
		LinkToTransactionID: &missing,
	})
	var apiErr *apierror.Error
	if !errors.As(err, &apiErr) || apiErr.FieldErrors["link_to_transaction_id"] != "LINK_TARGET_NOT_FOUND" {
		t.Fatalf("error = %v, want LINK_TARGET_NOT_FOUND", err)
	}
}

func TestCreateStandard_LinkTarget_RejectsNonStandardKind(t *testing.T) {
	h := newHarness(t, 100000) // gives this wallet an OPENING_BALANCE row
	ctx := context.Background()

	_, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, WalletID: h.walletID, Direction: transactions.DirectionDebit, AmountMinor: 1000,
		Currency: "EUR", Title: "Saldo", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
		LinkToTransactionID: &h.openingTransaction,
	})
	var apiErr *apierror.Error
	if !errors.As(err, &apiErr) || apiErr.FieldErrors["link_to_transaction_id"] != "LINK_TARGET_NOT_LINKABLE" {
		t.Fatalf("error = %v, want LINK_TARGET_NOT_LINKABLE for an OPENING_BALANCE target", err)
	}
}

func TestCreateStandard_LinkTarget_RejectsMealVoucherWallet(t *testing.T) {
	h := newHarness(t, 0)
	voucherWalletID := newVoucherWallet(t, h, 800)
	ctx := context.Background()

	if _, _, err := h.service.CreateVoucherCredit(ctx, transactions.CreateVoucherCreditInput{
		UserID: h.userID, WalletID: voucherWalletID, Quantity: 5, OccurredAt: time.Now(),
		IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	}); err != nil {
		t.Fatalf("seed credit: %v", err)
	}
	expenseBody, _, err := h.service.CreateVoucherExpense(ctx, transactions.CreateVoucherExpenseInput{
		UserID: h.userID, VoucherWalletID: voucherWalletID, VoucherQuantity: 1, TotalExpenseMinor: 600,
		Title: "Pranzo", OccurredAt: time.Now(), IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateVoucherExpense() error = %v", err)
	}
	var decoded transactions.VoucherExpenseResult
	if err := json.Unmarshal(expenseBody, &decoded); err != nil {
		t.Fatalf("decode voucher expense: %v", err)
	}
	voucherLegID := uuid.MustParse(decoded.VoucherTransaction.ID)

	// Kind=STANDARD, SystemGenerated=false, LinkedTransactionID=nil (fully
	// covered by vouchers) — passes every check except the wallet type one,
	// which is exactly what this test guards.
	_, _, err = h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, WalletID: h.walletID, Direction: transactions.DirectionDebit, AmountMinor: 1000,
		Currency: "EUR", Title: "Saldo", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
		LinkToTransactionID: &voucherLegID,
	})
	var apiErr *apierror.Error
	if !errors.As(err, &apiErr) || apiErr.FieldErrors["link_to_transaction_id"] != "LINK_TARGET_NOT_LINKABLE" {
		t.Fatalf("error = %v, want LINK_TARGET_NOT_LINKABLE for a meal-voucher-wallet target", err)
	}
}

func TestDelete_DissolvesPaymentGroupWhenOneMemberRemains(t *testing.T) {
	h := newHarness(t, 100000)
	ctx := context.Background()

	accontoBody, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, WalletID: h.walletID, Direction: transactions.DirectionDebit, AmountMinor: 10000,
		Currency: "EUR", Title: "Acconto", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateStandard(acconto) error = %v", err)
	}
	accontoIDStr, _ := decodeCreateResponse(t, accontoBody)
	accontoID := uuid.MustParse(accontoIDStr)

	saldoBody, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, WalletID: h.walletID, Direction: transactions.DirectionDebit, AmountMinor: 30000,
		Currency: "EUR", Title: "Saldo", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
		LinkToTransactionID: &accontoID,
	})
	if err != nil {
		t.Fatalf("CreateStandard(saldo, linked) error = %v", err)
	}
	saldoIDStr, _ := decodeCreateResponse(t, saldoBody)
	saldoID := uuid.MustParse(saldoIDStr)

	if _, err := h.service.Delete(ctx, h.userID, saldoID); err != nil {
		t.Fatalf("Delete(saldo) error = %v", err)
	}

	acconto, err := h.service.Get(ctx, h.userID, accontoID)
	if err != nil {
		t.Fatalf("Get(acconto) error = %v", err)
	}
	if acconto.PaymentGroupID != nil {
		t.Fatalf("acconto.PaymentGroupID = %v, want nil (group dissolved back to standalone)", *acconto.PaymentGroupID)
	}
}

func TestDelete_KeepsGroupWhenMoreThanOneMemberRemains(t *testing.T) {
	h := newHarness(t, 100000)
	ctx := context.Background()

	accontoBody, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, WalletID: h.walletID, Direction: transactions.DirectionDebit, AmountMinor: 10000,
		Currency: "EUR", Title: "Acconto", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateStandard(acconto) error = %v", err)
	}
	accontoIDStr, _ := decodeCreateResponse(t, accontoBody)
	accontoID := uuid.MustParse(accontoIDStr)

	secondBody, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, WalletID: h.walletID, Direction: transactions.DirectionDebit, AmountMinor: 5000,
		Currency: "EUR", Title: "Secondo", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
		LinkToTransactionID: &accontoID,
	})
	if err != nil {
		t.Fatalf("CreateStandard(second, linked) error = %v", err)
	}
	secondIDStr, _ := decodeCreateResponse(t, secondBody)
	secondID := uuid.MustParse(secondIDStr)

	thirdBody, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, WalletID: h.walletID, Direction: transactions.DirectionDebit, AmountMinor: 25000,
		Currency: "EUR", Title: "Saldo", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
		LinkToTransactionID: &accontoID,
	})
	if err != nil {
		t.Fatalf("CreateStandard(third, linked) error = %v", err)
	}
	thirdIDStr, _ := decodeCreateResponse(t, thirdBody)
	thirdID := uuid.MustParse(thirdIDStr)

	if _, err := h.service.Delete(ctx, h.userID, secondID); err != nil {
		t.Fatalf("Delete(second) error = %v", err)
	}

	acconto, err := h.service.Get(ctx, h.userID, accontoID)
	if err != nil {
		t.Fatalf("Get(acconto) error = %v", err)
	}
	third, err := h.service.Get(ctx, h.userID, thirdID)
	if err != nil {
		t.Fatalf("Get(third) error = %v", err)
	}
	if acconto.PaymentGroupID == nil || third.PaymentGroupID == nil {
		t.Fatalf("expected the two remaining legs to stay grouped, got acconto=%v third=%v",
			acconto.PaymentGroupID, third.PaymentGroupID)
	}
	if *acconto.PaymentGroupID != *third.PaymentGroupID {
		t.Fatalf("remaining legs' group ids diverged: acconto=%s third=%s", *acconto.PaymentGroupID, *third.PaymentGroupID)
	}
}

func TestUnlinkPaymentGroup_DissolvesPairAndRejectsUngroupedTransaction(t *testing.T) {
	h := newHarness(t, 100000)
	ctx := context.Background()

	accontoBody, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, WalletID: h.walletID, Direction: transactions.DirectionDebit, AmountMinor: 10000,
		Currency: "EUR", Title: "Acconto", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateStandard(acconto) error = %v", err)
	}
	accontoIDStr, _ := decodeCreateResponse(t, accontoBody)
	accontoID := uuid.MustParse(accontoIDStr)

	saldoBody, _, err := h.service.CreateStandard(ctx, transactions.CreateStandardInput{
		UserID: h.userID, WalletID: h.walletID, Direction: transactions.DirectionDebit, AmountMinor: 30000,
		Currency: "EUR", Title: "Saldo", IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
		LinkToTransactionID: &accontoID,
	})
	if err != nil {
		t.Fatalf("CreateStandard(saldo, linked) error = %v", err)
	}
	saldoIDStr, _ := decodeCreateResponse(t, saldoBody)
	saldoID := uuid.MustParse(saldoIDStr)

	if _, err := h.service.UnlinkPaymentGroup(ctx, h.userID, saldoID); err != nil {
		t.Fatalf("UnlinkPaymentGroup(saldo) error = %v", err)
	}

	acconto, err := h.service.Get(ctx, h.userID, accontoID)
	if err != nil {
		t.Fatalf("Get(acconto) error = %v", err)
	}
	saldo, err := h.service.Get(ctx, h.userID, saldoID)
	if err != nil {
		t.Fatalf("Get(saldo) error = %v", err)
	}
	if acconto.PaymentGroupID != nil || saldo.PaymentGroupID != nil {
		t.Fatalf("expected both legs to revert to standalone, got acconto=%v saldo=%v",
			acconto.PaymentGroupID, saldo.PaymentGroupID)
	}

	_, err = h.service.UnlinkPaymentGroup(ctx, h.userID, accontoID)
	var apiErr *apierror.Error
	if !errors.As(err, &apiErr) || apiErr.Code != "NOT_IN_PAYMENT_GROUP" {
		t.Fatalf("error = %v, want NOT_IN_PAYMENT_GROUP for an already-standalone transaction", err)
	}
}
