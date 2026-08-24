package transactions

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/idempotency"
	"financial-manager-backend/internal/wallets"
)

// --- Expiry sweep ----------------------------------------------------------

// applyVoucherLotExpiry sweeps wallet's active lots for any whose
// expires_at has passed, writing the loss off as a single system-generated
// BALANCE_ADJUSTMENT ("Buoni scaduti") and updating the wallet balance.
// Must be called with wallet already locked (LockByIDForUpdate) — it locks
// every active lot itself and returns the possibly-updated wallet alongside
// the lots that are still active after the sweep, row-locked for the rest
// of the caller's transaction and ready for FIFO consumption. Called at the
// start of every voucher-specific mutation (credit, removal, expense, and
// their edits) so a wallet's numbers are always correct by the time it's
// touched, and additionally on a schedule by cmd/worker so they stay
// correct even for a wallet nobody opens for months.
func (s *Service) applyVoucherLotExpiry(ctx context.Context, tx pgx.Tx, wallet wallets.Wallet) (wallets.Wallet, []wallets.VoucherLot, error) {
	lots, err := s.wallets.WithQuerier(tx).LockActiveLotsForUpdate(ctx, wallet.ID)
	if err != nil {
		return wallets.Wallet{}, nil, fmt.Errorf("lock active voucher lots: %w", err)
	}

	now := s.clock.Now().UTC()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)

	var active, expired []wallets.VoucherLot
	for _, lot := range lots {
		if today.After(lot.ExpiresAt) {
			expired = append(expired, lot)
		} else {
			active = append(active, lot)
		}
	}
	if len(expired) == 0 {
		return wallet, active, nil
	}

	var expiredQty int64
	for _, lot := range expired {
		expiredQty += int64(lot.QuantityRemaining)
	}

	expiryTx, err := s.transactions.WithQuerier(tx).Create(ctx, CreateInput{
		WalletID: wallet.ID, UserID: wallet.UserID, Direction: DirectionDebit, Kind: KindBalanceAdjustment,
		AmountMinor: expiredQty * (*wallet.VoucherUnitValueMinor), Currency: wallet.Currency, Title: "Buoni scaduti",
		OccurredAt: now, SystemGenerated: true,
	})
	if err != nil {
		return wallets.Wallet{}, nil, fmt.Errorf("create voucher expiry adjustment: %w", err)
	}

	for _, lot := range expired {
		if err := s.wallets.WithQuerier(tx).MarkLotExpired(ctx, lot.ID, lot.QuantityRemaining, expiryTx.ID); err != nil {
			return wallets.Wallet{}, nil, fmt.Errorf("mark voucher lot expired: %w", err)
		}
	}

	newBalance := wallet.CurrentBalanceMinor - expiredQty*(*wallet.VoucherUnitValueMinor)
	updatedWallet, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, wallet.ID, newBalance, wallet.Version)
	if err != nil {
		return wallets.Wallet{}, nil, fmt.Errorf("update wallet balance after voucher expiry: %w", err)
	}

	if err := s.audit.WithQuerier(tx).Record(ctx, expiryTx.ID, wallet.UserID, AuditActionCreated, nil, expiryTx); err != nil {
		return wallets.Wallet{}, nil, err
	}

	return updatedWallet, active, nil
}

// ExpireAllVoucherLots sweeps every MEAL_VOUCHER wallet across every user
// for expired lots, each wallet in its own DB transaction so one wallet's
// failure doesn't block the rest. Called on a schedule by cmd/worker — the
// same sweep already runs inline on every voucher-specific mutation (see
// applyVoucherLotExpiry), so this only matters for a wallet nobody touches
// for a long time.
func (s *Service) ExpireAllVoucherLots(ctx context.Context) (swept, failed int, err error) {
	walletsList, err := s.wallets.ListActiveByType(ctx, wallets.TypeMealVoucher)
	if err != nil {
		return 0, 0, fmt.Errorf("list meal voucher wallets: %w", err)
	}

	for _, w := range walletsList {
		txErr := s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
			locked, lockErr := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, w.ID, w.UserID)
			if lockErr != nil {
				return fmt.Errorf("lock wallet: %w", lockErr)
			}
			_, _, applyErr := s.applyVoucherLotExpiry(ctx, tx, locked)
			return applyErr
		})
		if txErr != nil {
			failed++
			continue
		}
		swept++
	}
	return swept, failed, nil
}

// --- FIFO consumption helpers -----------------------------------------------

// consumeVoucherLotsFIFO draws need vouchers from active (already ordered
// soonest-expiry-first by LockActiveLotsForUpdate), recording one
// wallet_voucher_lot_consumptions row per lot touched. Callers must already
// have verified need <= the sum of active's QuantityRemaining — a shortfall
// here indicates an internal invariant violation, not a user error.
func (s *Service) consumeVoucherLotsFIFO(ctx context.Context, tx pgx.Tx, transactionID uuid.UUID, active []wallets.VoucherLot, need int) error {
	remaining := need
	for _, lot := range active {
		if remaining == 0 {
			break
		}
		take := lot.QuantityRemaining
		if take > remaining {
			take = remaining
		}
		if take == 0 {
			continue
		}
		if err := s.wallets.WithQuerier(tx).UpdateLotRemaining(ctx, lot.ID, lot.QuantityRemaining-take); err != nil {
			return fmt.Errorf("update voucher lot remaining: %w", err)
		}
		if err := s.wallets.WithQuerier(tx).RecordLotConsumption(ctx, transactionID, lot.ID, take); err != nil {
			return fmt.Errorf("record voucher lot consumption: %w", err)
		}
		remaining -= take
	}
	if remaining > 0 {
		return fmt.Errorf("insufficient voucher lots to consume %d (short by %d) — caller should have validated availability first", need, remaining)
	}
	return nil
}

// reverseVoucherLotConsumption credits every lot transactionID drew from
// back to QuantityRemaining and clears its consumption rows — the first
// step of editing or deleting a voucher removal/expense, before
// recomputing from scratch with new inputs (or dropping the operation
// entirely, for delete).
func (s *Service) reverseVoucherLotConsumption(ctx context.Context, tx pgx.Tx, transactionID uuid.UUID) error {
	consumptions, err := s.wallets.WithQuerier(tx).ConsumptionsForTransaction(ctx, transactionID)
	if err != nil {
		return fmt.Errorf("list voucher lot consumptions: %w", err)
	}
	for _, c := range consumptions {
		lot, err := s.wallets.WithQuerier(tx).LockLotForUpdate(ctx, c.LotID)
		if err != nil {
			return fmt.Errorf("lock voucher lot for reversal: %w", err)
		}
		if err := s.wallets.WithQuerier(tx).UpdateLotRemaining(ctx, lot.ID, lot.QuantityRemaining+c.Quantity); err != nil {
			return fmt.Errorf("restore voucher lot remaining: %w", err)
		}
	}
	if err := s.wallets.WithQuerier(tx).DeleteLotConsumptionsForTransaction(ctx, transactionID); err != nil {
		return fmt.Errorf("delete voucher lot consumptions: %w", err)
	}
	return nil
}

func sumRemaining(lots []wallets.VoucherLot) int {
	total := 0
	for _, l := range lots {
		total += l.QuantityRemaining
	}
	return total
}

// --- Voucher credit / removal ------------------------------------------------

type CreateVoucherCreditInput struct {
	UserID         uuid.UUID
	WalletID       uuid.UUID
	Quantity       int // positive = add (creates a lot), negative = remove (consumes FIFO)
	Reason         string
	OccurredAt     time.Time
	SessionID      *uuid.UUID
	IdempotencyKey uuid.UUID
	RequestBody    []byte
}

// CreateVoucherCredit is the only way to change a meal-voucher wallet's
// quantity outside of an expense: a positive Quantity records a new batch
// of vouchers received (e.g. from an employer) with its expiry computed
// from the wallet's policy; a negative Quantity records vouchers removed
// without a purchase (e.g. lost, corrected), consumed FIFO like a spend.
func (s *Service) CreateVoucherCredit(ctx context.Context, in CreateVoucherCreditInput) ([]byte, int, error) {
	fieldErrors := map[string]string{}
	if in.WalletID == uuid.Nil {
		fieldErrors["wallet_id"] = apierror.FieldRequired
	}
	if in.Quantity == 0 {
		fieldErrors["quantity"] = apierror.FieldRequired
	}
	if in.IdempotencyKey == uuid.Nil {
		fieldErrors["idempotency_key"] = apierror.FieldRequired
	}
	if len(fieldErrors) > 0 {
		return nil, 0, apierror.NewValidation(fieldErrors)
	}

	occurredAt := in.OccurredAt
	if occurredAt.IsZero() {
		occurredAt = s.clock.Now()
	}
	requestHash := sha256Sum(in.RequestBody)

	var responseBody []byte
	var walletID uuid.UUID
	err := s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		idemStore := idempotency.NewStore(tx)
		claimed, existing, claimErr := idemStore.Claim(ctx, in.UserID.String(), voucherCreditEndpoint, in.IdempotencyKey, requestHash, idempotencyTTL)
		if claimErr != nil {
			if errors.Is(claimErr, idempotency.ErrKeyReusedWithDifferentPayload) {
				return apierror.New(http.StatusUnprocessableEntity, "IDEMPOTENCY_KEY_REUSED",
					"The idempotency key was already used with different data.")
			}
			return claimErr
		}
		if !claimed {
			responseBody = existing.ResponseBody
			return nil
		}

		wallet, err := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, in.WalletID, in.UserID)
		if errors.Is(err, wallets.ErrNotFound) {
			return apierror.NewValidation(map[string]string{"wallet_id": "WALLET_NOT_FOUND"})
		}
		if err != nil {
			return fmt.Errorf("lock wallet: %w", err)
		}
		if wallet.Type != wallets.TypeMealVoucher {
			return apierror.New(http.StatusForbidden, "WALLET_NOT_MEAL_VOUCHER", "This operation is only available for meal-voucher wallets.")
		}
		walletID = wallet.ID

		wallet, active, err := s.applyVoucherLotExpiry(ctx, tx, wallet)
		if err != nil {
			return err
		}

		var description *string
		if strings.TrimSpace(in.Reason) != "" {
			description = &in.Reason
		}

		var createdTx Transaction
		if in.Quantity > 0 {
			created, err := s.transactions.WithQuerier(tx).Create(ctx, CreateInput{
				WalletID: wallet.ID, UserID: in.UserID, Direction: DirectionCredit, Kind: KindBalanceAdjustment,
				AmountMinor: int64(in.Quantity) * (*wallet.VoucherUnitValueMinor), Currency: wallet.Currency,
				Title: "Buoni ricevuti", Description: description, OccurredAt: occurredAt, CreatedBySessionID: in.SessionID,
			})
			if err != nil {
				return fmt.Errorf("create voucher credit: %w", err)
			}
			createdTx = created

			expiresAt := wallets.ComputeLotExpiry(*wallet.VoucherExpiryCutoffMonth, *wallet.VoucherExpiryMonth, *wallet.VoucherExpiryDay, occurredAt)
			if _, err := s.wallets.WithQuerier(tx).CreateVoucherLot(ctx, wallet.ID, in.Quantity, expiresAt, created.ID); err != nil {
				return fmt.Errorf("create voucher lot: %w", err)
			}
		} else {
			need := -in.Quantity
			if sumRemaining(active) < need {
				return apierror.NewValidation(map[string]string{"quantity": "VOUCHER_INSUFFICIENT_BALANCE"})
			}
			created, err := s.transactions.WithQuerier(tx).Create(ctx, CreateInput{
				WalletID: wallet.ID, UserID: in.UserID, Direction: DirectionDebit, Kind: KindBalanceAdjustment,
				AmountMinor: int64(need) * (*wallet.VoucherUnitValueMinor), Currency: wallet.Currency,
				Title: "Buoni rimossi", Description: description, OccurredAt: occurredAt, CreatedBySessionID: in.SessionID,
			})
			if err != nil {
				return fmt.Errorf("create voucher removal: %w", err)
			}
			createdTx = created

			if err := s.consumeVoucherLotsFIFO(ctx, tx, created.ID, active, need); err != nil {
				return err
			}
		}

		newBalance := wallet.CurrentBalanceMinor + SignedDelta(createdTx.Direction, createdTx.AmountMinor)
		updatedWallet, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, wallet.ID, newBalance, wallet.Version)
		if err != nil {
			return fmt.Errorf("update wallet balance: %w", err)
		}

		if err := s.audit.WithQuerier(tx).Record(ctx, createdTx.ID, in.UserID, AuditActionCreated, nil, createdTx); err != nil {
			return err
		}

		body, err := json.Marshal(struct {
			Transaction transactionResponse `json:"transaction"`
			Wallet      walletSnapshot      `json:"wallet"`
		}{Transaction: toTransactionResponse(createdTx), Wallet: toWalletSnapshot(updatedWallet)})
		if err != nil {
			return fmt.Errorf("encode response: %w", err)
		}
		responseBody = body

		return idemStore.Fill(ctx, in.UserID.String(), voucherCreditEndpoint, in.IdempotencyKey, http.StatusCreated, body)
	})
	if err != nil {
		return nil, 0, err
	}
	if walletID != uuid.Nil {
		s.bumpReportVersion(ctx, walletID)
	}
	return responseBody, http.StatusCreated, nil
}

type UpdateVoucherCreditInput struct {
	UserID          uuid.UUID
	WalletID        uuid.UUID
	TransactionID   uuid.UUID
	Quantity        int // new absolute quantity for this credit/removal record; sign/direction is fixed from the existing record
	Reason          string
	OccurredAt      time.Time
	ExpectedVersion int64
}

// UpdateVoucherCredit edits a previously created voucher credit (addition)
// or removal's quantity and/or date. An addition's own lot is resized in
// place (rejecting a shrink below what other transactions already consumed
// from it, or any edit once it has expired); a removal reverses and
// re-applies its FIFO consumption against the wallet's current lots.
func (s *Service) UpdateVoucherCredit(ctx context.Context, in UpdateVoucherCreditInput) (TransactionWithWallet, error) {
	fieldErrors := map[string]string{}
	if in.WalletID == uuid.Nil {
		fieldErrors["wallet_id"] = apierror.FieldRequired
	}
	if in.Quantity <= 0 {
		fieldErrors["quantity"] = apierror.FieldAmountNotPositive
	}
	if len(fieldErrors) > 0 {
		return TransactionWithWallet{}, apierror.NewValidation(fieldErrors)
	}

	occurredAt := in.OccurredAt
	if occurredAt.IsZero() {
		occurredAt = s.clock.Now()
	}

	var result TransactionWithWallet
	var walletID uuid.UUID
	err := s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		existing, err := s.transactions.WithQuerier(tx).LockByIDAndUserID(ctx, in.TransactionID, in.UserID)
		if errors.Is(err, ErrNotFound) {
			return apierror.ErrNotFound
		}
		if err != nil {
			return err
		}
		if existing.Kind != KindBalanceAdjustment || existing.SystemGenerated || existing.WalletID != in.WalletID {
			return apierror.New(http.StatusForbidden, "NOT_EDITABLE", "Only voucher credits/removals can be edited through this endpoint.")
		}

		wallet, err := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, in.WalletID, in.UserID)
		if errors.Is(err, wallets.ErrNotFound) {
			return apierror.NewValidation(map[string]string{"wallet_id": "WALLET_NOT_FOUND"})
		}
		if err != nil {
			return fmt.Errorf("lock wallet: %w", err)
		}
		if wallet.Type != wallets.TypeMealVoucher {
			return apierror.New(http.StatusForbidden, "WALLET_NOT_MEAL_VOUCHER", "This operation is only available for meal-voucher wallets.")
		}
		walletID = wallet.ID

		wallet, _, err = s.applyVoucherLotExpiry(ctx, tx, wallet)
		if err != nil {
			return err
		}

		var description *string
		if strings.TrimSpace(in.Reason) != "" {
			description = &in.Reason
		}

		var newAmount int64
		if existing.Direction == DirectionCredit {
			lot, err := s.wallets.WithQuerier(tx).LockLotByCreatingTransactionForUpdate(ctx, existing.ID)
			if err != nil {
				return fmt.Errorf("lock voucher lot: %w", err)
			}
			if lot.QuantityExpired > 0 {
				return apierror.New(http.StatusConflict, "VOUCHER_LOT_ALREADY_EXPIRED",
					"This voucher credit's lot has already expired and can no longer be edited.")
			}
			consumed := lot.QuantityTotal - lot.QuantityRemaining
			if in.Quantity < consumed {
				return apierror.NewValidation(map[string]string{"quantity": "VOUCHER_LOT_ALREADY_USED"})
			}
			newExpiresAt := wallets.ComputeLotExpiry(*wallet.VoucherExpiryCutoffMonth, *wallet.VoucherExpiryMonth, *wallet.VoucherExpiryDay, occurredAt)
			newRemaining := lot.QuantityRemaining + (in.Quantity - lot.QuantityTotal)
			if err := s.wallets.WithQuerier(tx).UpdateLotQuantityAndExpiry(ctx, lot.ID, in.Quantity, newRemaining, newExpiresAt); err != nil {
				return fmt.Errorf("update voucher lot: %w", err)
			}
			newAmount = int64(in.Quantity) * (*wallet.VoucherUnitValueMinor)
		} else {
			if err := s.reverseVoucherLotConsumption(ctx, tx, existing.ID); err != nil {
				return err
			}
			refreshedActive, err := s.wallets.WithQuerier(tx).LockActiveLotsForUpdate(ctx, wallet.ID)
			if err != nil {
				return fmt.Errorf("relock active voucher lots: %w", err)
			}
			if sumRemaining(refreshedActive) < in.Quantity {
				return apierror.NewValidation(map[string]string{"quantity": "VOUCHER_INSUFFICIENT_BALANCE"})
			}
			if err := s.consumeVoucherLotsFIFO(ctx, tx, existing.ID, refreshedActive, in.Quantity); err != nil {
				return err
			}
			newAmount = int64(in.Quantity) * (*wallet.VoucherUnitValueMinor)
		}

		updated, err := s.transactions.WithQuerier(tx).Update(ctx, existing.ID, in.UserID, in.ExpectedVersion, UpdateInput{
			WalletID: wallet.ID, Direction: existing.Direction, AmountMinor: newAmount, Title: existing.Title,
			Description: description, CategoryID: existing.CategoryID, TemplateID: existing.TemplateID, MediaID: existing.MediaID,
			OccurredAt: occurredAt,
		})
		if errors.Is(err, ErrNotFound) {
			if _, getErr := s.transactions.WithQuerier(tx).GetByIDAndUserID(ctx, existing.ID, in.UserID); getErr == nil {
				return apierror.ErrConflict
			}
			return apierror.ErrNotFound
		}
		if err != nil {
			return err
		}

		diff := SignedDelta(existing.Direction, newAmount) - SignedDelta(existing.Direction, existing.AmountMinor)
		updatedWallet, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, wallet.ID, wallet.CurrentBalanceMinor+diff, wallet.Version)
		if err != nil {
			return fmt.Errorf("update wallet balance: %w", err)
		}

		if err := s.audit.WithQuerier(tx).Record(ctx, updated.ID, in.UserID, AuditActionUpdated, existing, updated); err != nil {
			return err
		}

		result = TransactionWithWallet{Transaction: toTransactionResponse(updated), Wallet: toWalletSnapshot(updatedWallet)}
		return nil
	})
	if err == nil {
		s.bumpReportVersion(ctx, walletID)
	}
	return result, err
}

// deleteVoucherCreditOrRemoval handles Delete for a BALANCE_ADJUSTMENT on a
// MEAL_VOUCHER wallet — a manual credit or removal (callers already reject
// SystemGenerated, so this is never the automatic expiry write-off).
func (s *Service) deleteVoucherCreditOrRemoval(ctx context.Context, tx pgx.Tx, userID uuid.UUID, existing Transaction, wallet wallets.Wallet) (walletSnapshot, error) {
	if existing.Direction == DirectionCredit {
		lot, err := s.wallets.WithQuerier(tx).LockLotByCreatingTransactionForUpdate(ctx, existing.ID)
		if err != nil {
			return walletSnapshot{}, fmt.Errorf("lock voucher lot: %w", err)
		}
		if lot.QuantityExpired > 0 {
			return walletSnapshot{}, apierror.New(http.StatusConflict, "VOUCHER_LOT_ALREADY_EXPIRED",
				"This voucher credit's lot has already expired and can no longer be deleted.")
		}
		if lot.QuantityRemaining != lot.QuantityTotal {
			return walletSnapshot{}, apierror.New(http.StatusConflict, "VOUCHER_LOT_ALREADY_USED",
				"Some of these vouchers have already been spent or removed; undo those first.")
		}
		if err := s.wallets.WithQuerier(tx).DeleteLot(ctx, lot.ID); err != nil {
			return walletSnapshot{}, fmt.Errorf("delete voucher lot: %w", err)
		}
	} else {
		if err := s.reverseVoucherLotConsumption(ctx, tx, existing.ID); err != nil {
			return walletSnapshot{}, err
		}
	}

	if err := s.transactions.WithQuerier(tx).SoftDelete(ctx, existing.ID, userID); err != nil {
		return walletSnapshot{}, err
	}

	newBalance := wallet.CurrentBalanceMinor - SignedDelta(existing.Direction, existing.AmountMinor)
	updatedWallet, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, wallet.ID, newBalance, wallet.Version)
	if err != nil {
		return walletSnapshot{}, fmt.Errorf("update wallet balance: %w", err)
	}

	if err := s.audit.WithQuerier(tx).Record(ctx, existing.ID, userID, AuditActionDeleted, existing, nil); err != nil {
		return walletSnapshot{}, err
	}

	return toWalletSnapshot(updatedWallet), nil
}

// --- Voucher expense ---------------------------------------------------------

type CreateVoucherExpenseInput struct {
	UserID            uuid.UUID
	VoucherWalletID   uuid.UUID
	VoucherQuantity   int
	TotalExpenseMinor int64
	OtherWalletID     *uuid.UUID
	Title             string
	Description       *string
	CategoryID        *uuid.UUID
	TemplateID        *uuid.UUID
	MediaID           *uuid.UUID
	OccurredAt        time.Time
	SessionID         *uuid.UUID
	IdempotencyKey    uuid.UUID
	RequestBody       []byte
}

// VoucherExpenseResult is the shared response shape for creating and
// editing a voucher expense. OtherTransaction/OtherWallet are nil when the
// expense is fully covered by vouchers (no shortfall).
type VoucherExpenseResult struct {
	VoucherTransaction transactionResponse  `json:"voucher_transaction"`
	OtherTransaction   *transactionResponse `json:"other_transaction,omitempty"`
	VoucherWallet      walletSnapshot       `json:"voucher_wallet"`
	OtherWallet        *walletSnapshot      `json:"other_wallet,omitempty"`
}

// CreateVoucherExpense records a purchase paid partly or fully with meal
// vouchers: the voucher-wallet leg always debits exactly
// VoucherQuantity*unit_value (the full value of the vouchers spent — if
// that exceeds TotalExpenseMinor, the excess is lost, matching how meal
// vouchers work in practice, never refunded or credited back). If
// TotalExpenseMinor exceeds the vouchers' value, OtherWalletID must be set
// and a second linked DEBIT leg covers the shortfall there. Both legs are
// Kind=STANDARD (unlike TRANSFER) so they count normally in reports.
func (s *Service) CreateVoucherExpense(ctx context.Context, in CreateVoucherExpenseInput) ([]byte, int, error) {
	fieldErrors := map[string]string{}
	if in.VoucherWalletID == uuid.Nil {
		fieldErrors["voucher_wallet_id"] = apierror.FieldRequired
	}
	if in.VoucherQuantity <= 0 {
		fieldErrors["voucher_quantity"] = apierror.FieldAmountNotPositive
	}
	if in.TotalExpenseMinor <= 0 {
		fieldErrors["total_expense_minor"] = apierror.FieldAmountNotPositive
	} else if in.TotalExpenseMinor > maxAmountMinor {
		fieldErrors["total_expense_minor"] = apierror.FieldAmountImplausible
	}
	if strings.TrimSpace(in.Title) == "" || len(in.Title) > 120 {
		fieldErrors["title"] = apierror.FieldTitleLength
	}
	if in.OtherWalletID != nil && *in.OtherWalletID == in.VoucherWalletID {
		fieldErrors["other_wallet_id"] = "SAME_AS_VOUCHER_WALLET"
	}
	if in.IdempotencyKey == uuid.Nil {
		fieldErrors["idempotency_key"] = apierror.FieldRequired
	}
	if len(fieldErrors) > 0 {
		return nil, 0, apierror.NewValidation(fieldErrors)
	}

	occurredAt := in.OccurredAt
	if occurredAt.IsZero() {
		occurredAt = s.clock.Now()
	}
	requestHash := sha256Sum(in.RequestBody)

	var responseBody []byte
	var voucherWalletID, otherWalletID uuid.UUID
	err := s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		idemStore := idempotency.NewStore(tx)
		claimed, existing, claimErr := idemStore.Claim(ctx, in.UserID.String(), voucherExpenseEndpoint, in.IdempotencyKey, requestHash, idempotencyTTL)
		if claimErr != nil {
			if errors.Is(claimErr, idempotency.ErrKeyReusedWithDifferentPayload) {
				return apierror.New(http.StatusUnprocessableEntity, "IDEMPOTENCY_KEY_REUSED",
					"The idempotency key was already used with different data.")
			}
			return claimErr
		}
		if !claimed {
			responseBody = existing.ResponseBody
			return nil
		}

		var voucherWallet, otherWallet wallets.Wallet
		if in.OtherWalletID != nil {
			firstID, secondID := orderedWalletIDs(in.VoucherWalletID, *in.OtherWalletID)
			firstWallet, err := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, firstID, in.UserID)
			if errors.Is(err, wallets.ErrNotFound) {
				return apierror.NewValidation(map[string]string{"voucher_wallet_id": "WALLET_NOT_FOUND"})
			}
			if err != nil {
				return fmt.Errorf("lock wallet: %w", err)
			}
			secondWallet, err := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, secondID, in.UserID)
			if errors.Is(err, wallets.ErrNotFound) {
				return apierror.NewValidation(map[string]string{"other_wallet_id": "WALLET_NOT_FOUND"})
			}
			if err != nil {
				return fmt.Errorf("lock wallet: %w", err)
			}
			if firstWallet.ID == in.VoucherWalletID {
				voucherWallet, otherWallet = firstWallet, secondWallet
			} else {
				voucherWallet, otherWallet = secondWallet, firstWallet
			}
		} else {
			w, err := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, in.VoucherWalletID, in.UserID)
			if errors.Is(err, wallets.ErrNotFound) {
				return apierror.NewValidation(map[string]string{"voucher_wallet_id": "WALLET_NOT_FOUND"})
			}
			if err != nil {
				return fmt.Errorf("lock wallet: %w", err)
			}
			voucherWallet = w
		}
		voucherWalletID = voucherWallet.ID
		if in.OtherWalletID != nil {
			otherWalletID = otherWallet.ID
		}

		if voucherWallet.Type != wallets.TypeMealVoucher {
			return apierror.NewValidation(map[string]string{"voucher_wallet_id": "WALLET_NOT_MEAL_VOUCHER"})
		}
		if in.OtherWalletID != nil {
			if otherWallet.Type == wallets.TypeMealVoucher {
				return apierror.NewValidation(map[string]string{"other_wallet_id": "WALLET_IS_MEAL_VOUCHER"})
			}
			if otherWallet.Currency != voucherWallet.Currency {
				return apierror.NewValidation(map[string]string{"other_wallet_id": apierror.FieldCurrencyMismatch})
			}
		}

		if err := s.resolveAttachments(ctx, tx, in.UserID, in.CategoryID, in.TemplateID, in.MediaID); err != nil {
			return err
		}

		voucherWallet, active, err := s.applyVoucherLotExpiry(ctx, tx, voucherWallet)
		if err != nil {
			return err
		}
		if sumRemaining(active) < in.VoucherQuantity {
			return apierror.NewValidation(map[string]string{"voucher_quantity": "VOUCHER_INSUFFICIENT_BALANCE"})
		}

		voucherLegAmount := int64(in.VoucherQuantity) * (*voucherWallet.VoucherUnitValueMinor)
		shortfall := in.TotalExpenseMinor - voucherLegAmount
		if shortfall > 0 && in.OtherWalletID == nil {
			return apierror.NewValidation(map[string]string{"other_wallet_id": "OTHER_WALLET_REQUIRED"})
		}
		if shortfall <= 0 && in.OtherWalletID != nil {
			return apierror.NewValidation(map[string]string{"other_wallet_id": "OTHER_WALLET_NOT_ALLOWED"})
		}

		voucherLeg, err := s.transactions.WithQuerier(tx).Create(ctx, CreateInput{
			WalletID: voucherWallet.ID, UserID: in.UserID, Direction: DirectionDebit, Kind: KindStandard,
			AmountMinor: voucherLegAmount, Currency: voucherWallet.Currency, Title: in.Title, Description: in.Description,
			CategoryID: in.CategoryID, TemplateID: in.TemplateID, MediaID: in.MediaID,
			OccurredAt: occurredAt, CreatedBySessionID: in.SessionID,
		})
		if err != nil {
			return fmt.Errorf("create voucher expense leg: %w", err)
		}

		if err := s.consumeVoucherLotsFIFO(ctx, tx, voucherLeg.ID, active, in.VoucherQuantity); err != nil {
			return err
		}

		newVoucherBalance := voucherWallet.CurrentBalanceMinor - voucherLegAmount
		updatedVoucherWallet, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, voucherWallet.ID, newVoucherBalance, voucherWallet.Version)
		if err != nil {
			return fmt.Errorf("update voucher wallet balance: %w", err)
		}

		if err := s.audit.WithQuerier(tx).Record(ctx, voucherLeg.ID, in.UserID, AuditActionCreated, nil, voucherLeg); err != nil {
			return err
		}

		result := VoucherExpenseResult{
			VoucherTransaction: toTransactionResponse(voucherLeg),
			VoucherWallet:      toWalletSnapshot(updatedVoucherWallet),
		}

		if shortfall > 0 {
			otherLeg, err := s.transactions.WithQuerier(tx).Create(ctx, CreateInput{
				WalletID: otherWallet.ID, UserID: in.UserID, Direction: DirectionDebit, Kind: KindStandard,
				AmountMinor: shortfall, Currency: otherWallet.Currency, Title: in.Title, Description: in.Description,
				CategoryID: in.CategoryID, TemplateID: in.TemplateID, MediaID: in.MediaID,
				OccurredAt: occurredAt, CreatedBySessionID: in.SessionID, LinkedTransactionID: &voucherLeg.ID,
			})
			if err != nil {
				return fmt.Errorf("create voucher expense shortfall leg: %w", err)
			}
			if err := s.transactions.WithQuerier(tx).SetLinkedTransactionID(ctx, voucherLeg.ID, &otherLeg.ID); err != nil {
				return err
			}
			voucherLeg.LinkedTransactionID = &otherLeg.ID
			result.VoucherTransaction = toTransactionResponse(voucherLeg)

			newOtherBalance := otherWallet.CurrentBalanceMinor - shortfall
			updatedOtherWallet, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, otherWallet.ID, newOtherBalance, otherWallet.Version)
			if err != nil {
				return fmt.Errorf("update other wallet balance: %w", err)
			}

			if err := s.audit.WithQuerier(tx).Record(ctx, otherLeg.ID, in.UserID, AuditActionCreated, nil, otherLeg); err != nil {
				return err
			}

			otherResp := toTransactionResponse(otherLeg)
			otherWalletResp := toWalletSnapshot(updatedOtherWallet)
			result.OtherTransaction = &otherResp
			result.OtherWallet = &otherWalletResp
		}

		body, err := json.Marshal(result)
		if err != nil {
			return fmt.Errorf("encode response: %w", err)
		}
		responseBody = body

		return idemStore.Fill(ctx, in.UserID.String(), voucherExpenseEndpoint, in.IdempotencyKey, http.StatusCreated, body)
	})
	if err != nil {
		return nil, 0, err
	}
	if voucherWalletID != uuid.Nil {
		s.bumpReportVersion(ctx, voucherWalletID)
	}
	if otherWalletID != uuid.Nil {
		s.bumpReportVersion(ctx, otherWalletID)
	}
	return responseBody, http.StatusCreated, nil
}

type UpdateVoucherExpenseInput struct {
	UserID            uuid.UUID
	TransactionID     uuid.UUID // the voucher-wallet leg's transaction id
	VoucherQuantity   int
	TotalExpenseMinor int64
	OtherWalletID     *uuid.UUID
	Title             string
	Description       *string
	CategoryID        *uuid.UUID
	TemplateID        *uuid.UUID
	MediaID           *uuid.UUID
	OccurredAt        time.Time
	ExpectedVersion   int64
}

// UpdateVoucherExpense edits a voucher expense's quantity, real cost,
// shortfall wallet, and/or date. Always addressed by the voucher-wallet
// leg's id (not the optional shortfall leg's). Internally it fully reverses
// the expense's prior lot consumption and shortfall-leg effect, then
// recomputes from scratch against the wallet's *current* lots and inputs —
// simpler to reason about than patching deltas, and correct even if other
// activity happened on the voucher wallet since the original expense.
func (s *Service) UpdateVoucherExpense(ctx context.Context, in UpdateVoucherExpenseInput) (VoucherExpenseResult, error) {
	fieldErrors := map[string]string{}
	if in.VoucherQuantity <= 0 {
		fieldErrors["voucher_quantity"] = apierror.FieldAmountNotPositive
	}
	if in.TotalExpenseMinor <= 0 {
		fieldErrors["total_expense_minor"] = apierror.FieldAmountNotPositive
	} else if in.TotalExpenseMinor > maxAmountMinor {
		fieldErrors["total_expense_minor"] = apierror.FieldAmountImplausible
	}
	if strings.TrimSpace(in.Title) == "" || len(in.Title) > 120 {
		fieldErrors["title"] = apierror.FieldTitleLength
	}
	if len(fieldErrors) > 0 {
		return VoucherExpenseResult{}, apierror.NewValidation(fieldErrors)
	}

	occurredAt := in.OccurredAt
	if occurredAt.IsZero() {
		occurredAt = s.clock.Now()
	}

	var result VoucherExpenseResult
	var voucherWalletID, oldOtherWalletID, newOtherWalletID uuid.UUID
	err := s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		voucherLeg, err := s.transactions.WithQuerier(tx).LockByIDAndUserID(ctx, in.TransactionID, in.UserID)
		if errors.Is(err, ErrNotFound) {
			return apierror.ErrNotFound
		}
		if err != nil {
			return err
		}
		if voucherLeg.Kind != KindStandard || voucherLeg.SystemGenerated {
			return apierror.New(http.StatusForbidden, "NOT_EDITABLE", "Only voucher expenses can be edited through this endpoint.")
		}

		voucherWallet, err := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, voucherLeg.WalletID, in.UserID)
		if err != nil {
			return fmt.Errorf("lock voucher wallet: %w", err)
		}
		if voucherWallet.Type != wallets.TypeMealVoucher {
			return apierror.New(http.StatusForbidden, "NOT_EDITABLE", "Only voucher expenses can be edited through this endpoint.")
		}
		voucherWalletID = voucherWallet.ID

		var oldOtherLeg *Transaction
		var oldOtherWallet wallets.Wallet
		if voucherLeg.LinkedTransactionID != nil {
			linked, err := s.transactions.WithQuerier(tx).LockByIDAndUserID(ctx, *voucherLeg.LinkedTransactionID, in.UserID)
			if err != nil {
				return fmt.Errorf("lock linked transaction: %w", err)
			}
			oldOtherLeg = &linked
			oldOtherWalletID = linked.WalletID
			oldOtherWallet, err = s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, linked.WalletID, in.UserID)
			if err != nil {
				return fmt.Errorf("lock old other wallet: %w", err)
			}
		}

		var newOtherWallet wallets.Wallet
		newOtherWalletSet := in.OtherWalletID != nil
		if newOtherWalletSet {
			if oldOtherLeg != nil && *in.OtherWalletID == oldOtherLeg.WalletID {
				newOtherWallet = oldOtherWallet
			} else {
				newOtherWallet, err = s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, *in.OtherWalletID, in.UserID)
				if errors.Is(err, wallets.ErrNotFound) {
					return apierror.NewValidation(map[string]string{"other_wallet_id": "WALLET_NOT_FOUND"})
				}
				if err != nil {
					return fmt.Errorf("lock new other wallet: %w", err)
				}
			}
			newOtherWalletID = newOtherWallet.ID
			if newOtherWallet.Type == wallets.TypeMealVoucher {
				return apierror.NewValidation(map[string]string{"other_wallet_id": "WALLET_IS_MEAL_VOUCHER"})
			}
			if newOtherWallet.Currency != voucherWallet.Currency {
				return apierror.NewValidation(map[string]string{"other_wallet_id": apierror.FieldCurrencyMismatch})
			}
		}

		if err := s.resolveAttachments(ctx, tx, in.UserID, in.CategoryID, in.TemplateID, in.MediaID); err != nil {
			return err
		}

		if err := s.reverseVoucherLotConsumption(ctx, tx, voucherLeg.ID); err != nil {
			return err
		}

		voucherWallet, active, err := s.applyVoucherLotExpiry(ctx, tx, voucherWallet)
		if err != nil {
			return err
		}
		if sumRemaining(active) < in.VoucherQuantity {
			return apierror.NewValidation(map[string]string{"voucher_quantity": "VOUCHER_INSUFFICIENT_BALANCE"})
		}

		voucherLegAmount := int64(in.VoucherQuantity) * (*voucherWallet.VoucherUnitValueMinor)
		shortfall := in.TotalExpenseMinor - voucherLegAmount
		if shortfall > 0 && !newOtherWalletSet {
			return apierror.NewValidation(map[string]string{"other_wallet_id": "OTHER_WALLET_REQUIRED"})
		}
		if shortfall <= 0 && newOtherWalletSet {
			return apierror.NewValidation(map[string]string{"other_wallet_id": "OTHER_WALLET_NOT_ALLOWED"})
		}

		updatedVoucherLeg, err := s.transactions.WithQuerier(tx).Update(ctx, voucherLeg.ID, in.UserID, in.ExpectedVersion, UpdateInput{
			WalletID: voucherWallet.ID, Direction: DirectionDebit, AmountMinor: voucherLegAmount, Title: in.Title,
			Description: in.Description, CategoryID: in.CategoryID, TemplateID: in.TemplateID, MediaID: in.MediaID,
			OccurredAt: occurredAt,
		})
		if errors.Is(err, ErrNotFound) {
			if _, getErr := s.transactions.WithQuerier(tx).GetByIDAndUserID(ctx, voucherLeg.ID, in.UserID); getErr == nil {
				return apierror.ErrConflict
			}
			return apierror.ErrNotFound
		}
		if err != nil {
			return err
		}

		if err := s.consumeVoucherLotsFIFO(ctx, tx, updatedVoucherLeg.ID, active, in.VoucherQuantity); err != nil {
			return err
		}

		voucherDiff := SignedDelta(DirectionDebit, voucherLegAmount) - SignedDelta(DirectionDebit, voucherLeg.AmountMinor)
		updatedVoucherWallet, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, voucherWallet.ID, voucherWallet.CurrentBalanceMinor+voucherDiff, voucherWallet.Version)
		if err != nil {
			return fmt.Errorf("update voucher wallet balance: %w", err)
		}

		if err := s.audit.WithQuerier(tx).Record(ctx, updatedVoucherLeg.ID, in.UserID, AuditActionUpdated, voucherLeg, updatedVoucherLeg); err != nil {
			return err
		}

		switch {
		case oldOtherLeg != nil && newOtherWalletSet:
			// The shortfall leg persists (possibly moved to a different
			// wallet, possibly resized) — its id, and so voucherLeg's
			// LinkedTransactionID, never changes.
			updatedOtherLeg, err := s.transactions.WithQuerier(tx).Update(ctx, oldOtherLeg.ID, in.UserID, oldOtherLeg.Version, UpdateInput{
				WalletID: newOtherWallet.ID, Direction: DirectionDebit, AmountMinor: shortfall, Title: in.Title,
				Description: in.Description, CategoryID: in.CategoryID, TemplateID: in.TemplateID, MediaID: in.MediaID,
				OccurredAt: occurredAt,
			})
			if err != nil {
				return fmt.Errorf("update voucher expense shortfall leg: %w", err)
			}

			var updatedOtherWallet wallets.Wallet
			if newOtherWallet.ID == oldOtherWallet.ID {
				diff := SignedDelta(DirectionDebit, shortfall) - SignedDelta(DirectionDebit, oldOtherLeg.AmountMinor)
				updatedOtherWallet, err = s.wallets.WithQuerier(tx).UpdateBalance(ctx, newOtherWallet.ID, newOtherWallet.CurrentBalanceMinor+diff, newOtherWallet.Version)
				if err != nil {
					return fmt.Errorf("update other wallet balance: %w", err)
				}
			} else {
				if _, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, oldOtherWallet.ID, oldOtherWallet.CurrentBalanceMinor+oldOtherLeg.AmountMinor, oldOtherWallet.Version); err != nil {
					return fmt.Errorf("restore old other wallet balance: %w", err)
				}
				updatedOtherWallet, err = s.wallets.WithQuerier(tx).UpdateBalance(ctx, newOtherWallet.ID, newOtherWallet.CurrentBalanceMinor-shortfall, newOtherWallet.Version)
				if err != nil {
					return fmt.Errorf("update new other wallet balance: %w", err)
				}
			}

			if err := s.audit.WithQuerier(tx).Record(ctx, updatedOtherLeg.ID, in.UserID, AuditActionUpdated, *oldOtherLeg, updatedOtherLeg); err != nil {
				return err
			}
			otherResp := toTransactionResponse(updatedOtherLeg)
			otherWalletResp := toWalletSnapshot(updatedOtherWallet)
			result.OtherTransaction = &otherResp
			result.OtherWallet = &otherWalletResp

		case oldOtherLeg != nil && !newOtherWalletSet:
			// No longer needed.
			if err := s.transactions.WithQuerier(tx).SoftDelete(ctx, oldOtherLeg.ID, in.UserID); err != nil {
				return err
			}
			if _, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, oldOtherWallet.ID, oldOtherWallet.CurrentBalanceMinor+oldOtherLeg.AmountMinor, oldOtherWallet.Version); err != nil {
				return fmt.Errorf("restore old other wallet balance: %w", err)
			}
			if err := s.transactions.WithQuerier(tx).SetLinkedTransactionID(ctx, updatedVoucherLeg.ID, nil); err != nil {
				return err
			}
			updatedVoucherLeg.LinkedTransactionID = nil
			if err := s.audit.WithQuerier(tx).Record(ctx, oldOtherLeg.ID, in.UserID, AuditActionDeleted, *oldOtherLeg, nil); err != nil {
				return err
			}

		case oldOtherLeg == nil && newOtherWalletSet:
			// Newly needed.
			newLeg, err := s.transactions.WithQuerier(tx).Create(ctx, CreateInput{
				WalletID: newOtherWallet.ID, UserID: in.UserID, Direction: DirectionDebit, Kind: KindStandard,
				AmountMinor: shortfall, Currency: newOtherWallet.Currency, Title: in.Title, Description: in.Description,
				CategoryID: in.CategoryID, TemplateID: in.TemplateID, MediaID: in.MediaID,
				OccurredAt: occurredAt, LinkedTransactionID: &updatedVoucherLeg.ID,
			})
			if err != nil {
				return fmt.Errorf("create voucher expense shortfall leg: %w", err)
			}
			if err := s.transactions.WithQuerier(tx).SetLinkedTransactionID(ctx, updatedVoucherLeg.ID, &newLeg.ID); err != nil {
				return err
			}
			updatedVoucherLeg.LinkedTransactionID = &newLeg.ID

			updatedNewWallet, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, newOtherWallet.ID, newOtherWallet.CurrentBalanceMinor-shortfall, newOtherWallet.Version)
			if err != nil {
				return fmt.Errorf("update new other wallet balance: %w", err)
			}

			if err := s.audit.WithQuerier(tx).Record(ctx, newLeg.ID, in.UserID, AuditActionCreated, nil, newLeg); err != nil {
				return err
			}
			otherResp := toTransactionResponse(newLeg)
			otherWalletResp := toWalletSnapshot(updatedNewWallet)
			result.OtherTransaction = &otherResp
			result.OtherWallet = &otherWalletResp
		}

		result.VoucherTransaction = toTransactionResponse(updatedVoucherLeg)
		result.VoucherWallet = toWalletSnapshot(updatedVoucherWallet)
		return nil
	})
	if err == nil {
		s.bumpReportVersion(ctx, voucherWalletID)
		if oldOtherWalletID != uuid.Nil {
			s.bumpReportVersion(ctx, oldOtherWalletID)
		}
		if newOtherWalletID != uuid.Nil && newOtherWalletID != oldOtherWalletID {
			s.bumpReportVersion(ctx, newOtherWalletID)
		}
	}
	return result, err
}

// deleteVoucherExpense handles Delete for a voucher expense's STANDARD
// legs. voucherLeg/voucherWallet are always the MEAL_VOUCHER-wallet side;
// otherLeg/otherWallet are nil/zero when the expense had no shortfall leg.
// The returned snapshot is always the voucher wallet's — even when Delete
// was invoked via the shortfall leg's id — since that's the expense's
// semantic anchor (see UpdateVoucherExpense's doc comment).
func (s *Service) deleteVoucherExpense(ctx context.Context, tx pgx.Tx, userID uuid.UUID, voucherLeg Transaction, voucherWallet wallets.Wallet, otherLeg *Transaction, otherWallet wallets.Wallet) (walletSnapshot, error) {
	if err := s.reverseVoucherLotConsumption(ctx, tx, voucherLeg.ID); err != nil {
		return walletSnapshot{}, err
	}
	if err := s.transactions.WithQuerier(tx).SoftDelete(ctx, voucherLeg.ID, userID); err != nil {
		return walletSnapshot{}, err
	}
	newVoucherBalance := voucherWallet.CurrentBalanceMinor - SignedDelta(voucherLeg.Direction, voucherLeg.AmountMinor)
	updatedVoucherWallet, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, voucherWallet.ID, newVoucherBalance, voucherWallet.Version)
	if err != nil {
		return walletSnapshot{}, fmt.Errorf("update voucher wallet balance: %w", err)
	}
	if err := s.audit.WithQuerier(tx).Record(ctx, voucherLeg.ID, userID, AuditActionDeleted, voucherLeg, nil); err != nil {
		return walletSnapshot{}, err
	}

	if otherLeg != nil {
		if err := s.transactions.WithQuerier(tx).SoftDelete(ctx, otherLeg.ID, userID); err != nil {
			return walletSnapshot{}, err
		}
		newOtherBalance := otherWallet.CurrentBalanceMinor - SignedDelta(otherLeg.Direction, otherLeg.AmountMinor)
		if _, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, otherWallet.ID, newOtherBalance, otherWallet.Version); err != nil {
			return walletSnapshot{}, fmt.Errorf("update other wallet balance: %w", err)
		}
		if err := s.audit.WithQuerier(tx).Record(ctx, otherLeg.ID, userID, AuditActionDeleted, *otherLeg, nil); err != nil {
			return walletSnapshot{}, err
		}
	}

	return toWalletSnapshot(updatedVoucherWallet), nil
}
