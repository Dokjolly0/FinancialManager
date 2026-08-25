package transactions

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"financial-manager-backend/internal/categories"
	"financial-manager-backend/internal/media"
	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/clock"
	"financial-manager-backend/internal/platform/database"
	"financial-manager-backend/internal/platform/idempotency"
	"financial-manager-backend/internal/templates"
	"financial-manager-backend/internal/wallets"
)

const (
	createTransactionEndpoint = "POST /v1/transactions"
	balanceAdjustmentEndpoint = "POST /v1/wallets/{id}/balance-adjustments"
	createWalletEndpoint      = "POST /v1/wallets"
	transferEndpoint          = "POST /v1/transfers"
	voucherCreditEndpoint     = "POST /v1/wallets/{id}/voucher-credits"
	voucherExpenseEndpoint    = "POST /v1/voucher-expenses"
	idempotencyTTL            = 24 * time.Hour

	// Sanity cap against overflow/anomalous input (plan.md section 4.3),
	// not a product-meaningful limit: 10 million units in minor currency.
	maxAmountMinor = 10_000_000_00
)

// orderedWalletIDs returns a, b reordered so the first has the
// lexicographically smaller UUID — a fixed, deterministic lock order for
// any code path that must hold row locks on two different wallets at once
// (moving a transaction between wallets, a transfer), so a concurrent
// mutation locking the same two wallets in the opposite order can't
// deadlock against this one (plan.md section 13.7, extended to
// multi-wallet).
func orderedWalletIDs(a, b uuid.UUID) (uuid.UUID, uuid.UUID) {
	if bytes.Compare(a[:], b[:]) <= 0 {
		return a, b
	}
	return b, a
}

// ReportVersionBumper invalidates cached report data for a wallet after a
// mutation touches its ledger (plan.md section 18.9). Optional: left unset
// (nil) in tests that don't exercise report caching.
type ReportVersionBumper interface {
	Bump(ctx context.Context, walletID uuid.UUID) error
}

type Service struct {
	db             *database.Pool
	transactions   *Repository
	wallets        *wallets.Repository
	audit          *AuditRepository
	categories     *categories.Repository
	templates      *templates.Repository
	media          *media.Repository
	clock          clock.Clock
	reportVersions ReportVersionBumper
}

type Deps struct {
	DB             *database.Pool
	Transactions   *Repository
	Wallets        *wallets.Repository
	Audit          *AuditRepository
	Categories     *categories.Repository
	Templates      *templates.Repository
	Media          *media.Repository
	Clock          clock.Clock
	ReportVersions ReportVersionBumper
}

func NewService(d Deps) *Service {
	return &Service{
		db: d.DB, transactions: d.Transactions, wallets: d.Wallets, audit: d.Audit,
		categories: d.Categories, templates: d.Templates, media: d.Media, clock: d.Clock,
		reportVersions: d.ReportVersions,
	}
}

// bumpReportVersion is a best-effort cache invalidation: a failure here
// only means a report cache serves briefly stale data until its TTL
// expires (plan.md section 18.9), never a reason to fail the mutation
// itself, so it's called after the DB transaction has already committed.
func (s *Service) bumpReportVersion(ctx context.Context, walletID uuid.UUID) {
	if s.reportVersions == nil {
		return
	}
	_ = s.reportVersions.Bump(ctx, walletID)
}

// resolveAttachments validates that an optional category_id is visible to
// the user (system or owned, plan.md section 14.7), that an optional
// template_id belongs to the user (bumping its usage stats, plan.md section
// 4.4: "ordered by frequency and recent use"), and that an optional
// media_id belongs to the user (bumping last_used_at, plan.md section
// 16.6). All checks run against tx so a cross-user reference rolls back the
// whole mutation, not just the side effect.
func (s *Service) resolveAttachments(ctx context.Context, tx pgx.Tx, userID uuid.UUID, categoryID, templateID, mediaID *uuid.UUID) error {
	if categoryID != nil {
		if _, err := s.categories.WithQuerier(tx).GetByIDAndVisibility(ctx, *categoryID, userID); err != nil {
			if errors.Is(err, categories.ErrNotFound) {
				return apierror.NewValidation(map[string]string{"category_id": "CATEGORY_NOT_FOUND"})
			}
			return err
		}
	}
	if templateID != nil {
		if err := s.templates.WithQuerier(tx).BumpUsage(ctx, *templateID, userID); err != nil {
			if errors.Is(err, templates.ErrNotFound) {
				return apierror.NewValidation(map[string]string{"template_id": "TEMPLATE_NOT_FOUND"})
			}
			return err
		}
	}
	if mediaID != nil {
		if err := s.media.WithQuerier(tx).MarkUsed(ctx, *mediaID, userID); err != nil {
			if errors.Is(err, media.ErrNotFound) {
				return apierror.NewValidation(map[string]string{"media_id": "MEDIA_NOT_FOUND"})
			}
			return err
		}
	}
	return nil
}

// --- DTOs shared by create/update/get/list --------------------------------

type transactionResponse struct {
	ID                  string  `json:"id"`
	WalletID            string  `json:"wallet_id"`
	Direction           string  `json:"direction"`
	Kind                string  `json:"kind"`
	AmountMinor         int64   `json:"amount_minor"`
	Currency            string  `json:"currency"`
	Title               string  `json:"title"`
	Description         *string `json:"description,omitempty"`
	CategoryID          *string `json:"category_id,omitempty"`
	TemplateID          *string `json:"template_id,omitempty"`
	MediaID             *string `json:"media_id,omitempty"`
	OccurredAt          string  `json:"occurred_at"`
	CreatedAt           string  `json:"created_at"`
	UpdatedAt           string  `json:"updated_at"`
	Version             int64   `json:"version"`
	TransferPairID      *string `json:"transfer_pair_id,omitempty"`
	LinkedTransactionID *string `json:"linked_transaction_id,omitempty"`
	SystemGenerated     bool    `json:"system_generated,omitempty"`
	PaymentGroupID      *string `json:"payment_group_id,omitempty"`
}

const timeLayout = "2006-01-02T15:04:05Z07:00"

func toTransactionResponse(t Transaction) transactionResponse {
	var categoryID *string
	if t.CategoryID != nil {
		s := t.CategoryID.String()
		categoryID = &s
	}
	var templateID *string
	if t.TemplateID != nil {
		s := t.TemplateID.String()
		templateID = &s
	}
	var mediaID *string
	if t.MediaID != nil {
		s := t.MediaID.String()
		mediaID = &s
	}
	var transferPairID *string
	if t.TransferPairID != nil {
		s := t.TransferPairID.String()
		transferPairID = &s
	}
	var linkedTransactionID *string
	if t.LinkedTransactionID != nil {
		s := t.LinkedTransactionID.String()
		linkedTransactionID = &s
	}
	var paymentGroupID *string
	if t.PaymentGroupID != nil {
		s := t.PaymentGroupID.String()
		paymentGroupID = &s
	}
	return transactionResponse{
		ID:                  t.ID.String(),
		WalletID:            t.WalletID.String(),
		Direction:           t.Direction,
		Kind:                t.Kind,
		AmountMinor:         t.AmountMinor,
		Currency:            t.Currency,
		Title:               t.Title,
		Description:         t.Description,
		CategoryID:          categoryID,
		TemplateID:          templateID,
		MediaID:             mediaID,
		OccurredAt:          t.OccurredAt.Format(timeLayout),
		CreatedAt:           t.CreatedAt.Format(timeLayout),
		UpdatedAt:           t.UpdatedAt.Format(timeLayout),
		Version:             t.Version,
		TransferPairID:      transferPairID,
		LinkedTransactionID: linkedTransactionID,
		SystemGenerated:     t.SystemGenerated,
		PaymentGroupID:      paymentGroupID,
	}
}

// walletSnapshot mirrors the shape of GET /v1/wallets/{id} so every
// endpoint that echoes a wallet back — create/update/delete/balance-
// adjustment/transfer here, and the wallets module's own GET — uses one
// consistent JSON shape. A partial shape here previously broke the
// Flutter client's shared Wallet.fromJson parser.
type walletSnapshot struct {
	ID                       string  `json:"id"`
	Name                     string  `json:"name"`
	Currency                 string  `json:"currency"`
	CurrentBalanceMinor      int64   `json:"current_balance_minor"`
	Type                     string  `json:"type"`
	Icon                     string  `json:"icon"`
	Color                    string  `json:"color"`
	Version                  int64   `json:"version"`
	UpdatedAt                string  `json:"updated_at"`
	ArchivedAt               *string `json:"archived_at,omitempty"`
	VoucherUnitValueMinor    *int64  `json:"voucher_unit_value_minor,omitempty"`
	VoucherExpiryCutoffMonth *int    `json:"voucher_expiry_cutoff_month,omitempty"`
	VoucherExpiryMonth       *int    `json:"voucher_expiry_month,omitempty"`
	VoucherExpiryDay         *int    `json:"voucher_expiry_day,omitempty"`
}

func toWalletSnapshot(w wallets.Wallet) walletSnapshot {
	var archivedAt *string
	if w.ArchivedAt != nil {
		s := w.ArchivedAt.Format(timeLayout)
		archivedAt = &s
	}
	return walletSnapshot{
		ID:                       w.ID.String(),
		Name:                     w.Name,
		Currency:                 w.Currency,
		CurrentBalanceMinor:      w.CurrentBalanceMinor,
		Type:                     w.Type,
		Icon:                     w.Icon,
		Color:                    w.Color,
		Version:                  w.Version,
		UpdatedAt:                w.UpdatedAt.Format(timeLayout),
		ArchivedAt:               archivedAt,
		VoucherUnitValueMinor:    w.VoucherUnitValueMinor,
		VoucherExpiryCutoffMonth: w.VoucherExpiryCutoffMonth,
		VoucherExpiryMonth:       w.VoucherExpiryMonth,
		VoucherExpiryDay:         w.VoucherExpiryDay,
	}
}

// rejectMealVoucherWallet gates the generic mutation endpoints (standard
// transaction, balance adjustment, transfer) off of MEAL_VOUCHER wallets:
// every mutation there must go through the dedicated voucher endpoints
// (CreateVoucherCredit, CreateVoucherExpense, ...) so the
// "balance == Σ active lots × unit value" invariant can never be broken by
// an arbitrary amount_minor.
func rejectMealVoucherWallet(w wallets.Wallet) error {
	if w.Type == wallets.TypeMealVoucher {
		return apierror.New(http.StatusForbidden, "WALLET_IS_MEAL_VOUCHER",
			"This operation isn't available for meal-voucher wallets; use the voucher-specific endpoints.")
	}
	return nil
}

func sha256Sum(b []byte) []byte {
	sum := sha256.Sum256(b)
	return sum[:]
}

func isValidDirection(d string) bool {
	return d == DirectionCredit || d == DirectionDebit
}

// --- Create standard transaction -------------------------------------------

type CreateStandardInput struct {
	UserID         uuid.UUID
	WalletID       uuid.UUID
	Direction      string
	AmountMinor    int64
	Currency       string
	Title          string
	Description    *string
	CategoryID     *uuid.UUID
	TemplateID     *uuid.UUID
	MediaID        *uuid.UUID
	OccurredAt     time.Time
	SessionID      *uuid.UUID
	IdempotencyKey uuid.UUID
	RequestBody    []byte

	// LinkToTransactionID, if set, marks the new transaction as an
	// installment of the same logical expense as an existing STANDARD
	// transaction the user already owns (plan.md linked-transactions
	// feature) — e.g. a saldo linked to a previously recorded acconto. Both
	// transactions are then grouped by a shared PaymentGroupID, purely for
	// display; neither's own accounting changes.
	LinkToTransactionID *uuid.UUID
}

// validateTransactionFields covers the rules shared by create and update
// (plan.md section 4.3/4.4). Idempotency-Key is validated separately since
// only creation-style mutations carry one.
func validateTransactionFields(direction string, amountMinor int64, title string) map[string]string {
	fieldErrors := map[string]string{}
	if !isValidDirection(direction) {
		fieldErrors["direction"] = apierror.FieldInvalidDirection
	}
	if amountMinor <= 0 {
		fieldErrors["amount_minor"] = apierror.FieldAmountNotPositive
	} else if amountMinor > maxAmountMinor {
		fieldErrors["amount_minor"] = apierror.FieldAmountImplausible
	}
	if strings.TrimSpace(title) == "" || len(title) > 120 {
		fieldErrors["title"] = apierror.FieldTitleLength
	}
	return fieldErrors
}

// CreateStandard creates a STANDARD transaction and atomically applies its
// effect to the wallet balance (plan.md section 13.2), replaying the
// original response for a retried Idempotency-Key instead of duplicating
// the mutation (section 26.2: "Double taps or retries don't create
// duplicates").
func (s *Service) CreateStandard(ctx context.Context, in CreateStandardInput) ([]byte, int, error) {
	fieldErrors := validateTransactionFields(in.Direction, in.AmountMinor, in.Title)
	if in.WalletID == uuid.Nil {
		fieldErrors["wallet_id"] = apierror.FieldRequired
	}
	if in.Currency != "EUR" {
		fieldErrors["currency"] = apierror.FieldCurrencyNotSupported
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
		claimed, existing, claimErr := idemStore.Claim(ctx, in.UserID.String(), createTransactionEndpoint, in.IdempotencyKey, requestHash, idempotencyTTL)
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

		// The link target's row must be locked BEFORE any wallet lock in
		// this transaction, matching the row-then-wallet order used
		// everywhere else a mutation locks both (UpdateStandard, Delete) —
		// locking wallet-then-row here instead would deadlock against a
		// concurrent Delete/UpdateStandard of the target that locks its own
		// wallet then its own row. The FOR UPDATE lock also makes "reuse the
		// target's existing payment group vs. mint a new one" race-safe: a
		// second concurrent link to the same target blocks here and then
		// observes the first link's freshly-written PaymentGroupID instead
		// of minting a duplicate group.
		var paymentGroupID *uuid.UUID
		if in.LinkToTransactionID != nil {
			target, err := s.transactions.WithQuerier(tx).LockByIDAndUserID(ctx, *in.LinkToTransactionID, in.UserID)
			if errors.Is(err, ErrNotFound) {
				return apierror.NewValidation(map[string]string{"link_to_transaction_id": "LINK_TARGET_NOT_FOUND"})
			}
			if err != nil {
				return fmt.Errorf("lock link target: %w", err)
			}
			if target.Kind != KindStandard || target.SystemGenerated || target.LinkedTransactionID != nil {
				return apierror.NewValidation(map[string]string{"link_to_transaction_id": "LINK_TARGET_NOT_LINKABLE"})
			}
			targetWallet, err := s.wallets.WithQuerier(tx).GetByID(ctx, target.WalletID, in.UserID)
			if err != nil {
				return fmt.Errorf("load link target wallet: %w", err)
			}
			if targetWallet.Type == wallets.TypeMealVoucher {
				return apierror.NewValidation(map[string]string{"link_to_transaction_id": "LINK_TARGET_NOT_LINKABLE"})
			}

			if target.PaymentGroupID != nil {
				paymentGroupID = target.PaymentGroupID
			} else {
				newGroupID := uuid.New()
				if err := s.transactions.WithQuerier(tx).SetPaymentGroupID(ctx, target.ID, &newGroupID); err != nil {
					return fmt.Errorf("set payment group id on link target: %w", err)
				}
				paymentGroupID = &newGroupID
			}
		}

		wallet, err := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, in.WalletID, in.UserID)
		if errors.Is(err, wallets.ErrNotFound) {
			return apierror.NewValidation(map[string]string{"wallet_id": "WALLET_NOT_FOUND"})
		}
		if err != nil {
			return fmt.Errorf("lock wallet: %w", err)
		}
		walletID = wallet.ID
		if err := rejectMealVoucherWallet(wallet); err != nil {
			return err
		}
		if in.Currency != wallet.Currency {
			return apierror.NewValidation(map[string]string{"currency": apierror.FieldCurrencyMismatch})
		}
		if err := s.resolveAttachments(ctx, tx, in.UserID, in.CategoryID, in.TemplateID, in.MediaID); err != nil {
			return err
		}

		newBalance := wallet.CurrentBalanceMinor + SignedDelta(in.Direction, in.AmountMinor)

		created, err := s.transactions.WithQuerier(tx).Create(ctx, CreateInput{
			WalletID: wallet.ID, UserID: in.UserID, Direction: in.Direction, Kind: KindStandard,
			AmountMinor: in.AmountMinor, Currency: in.Currency, Title: in.Title, Description: in.Description,
			CategoryID: in.CategoryID, TemplateID: in.TemplateID, MediaID: in.MediaID,
			OccurredAt: occurredAt, CreatedBySessionID: in.SessionID, PaymentGroupID: paymentGroupID,
		})
		if err != nil {
			return fmt.Errorf("create transaction: %w", err)
		}

		updatedWallet, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, wallet.ID, newBalance, wallet.Version)
		if err != nil {
			return fmt.Errorf("update wallet balance: %w", err)
		}

		if err := s.audit.WithQuerier(tx).Record(ctx, created.ID, in.UserID, AuditActionCreated, nil, created); err != nil {
			return err
		}

		body, err := json.Marshal(struct {
			Transaction transactionResponse `json:"transaction"`
			Wallet      walletSnapshot      `json:"wallet"`
		}{Transaction: toTransactionResponse(created), Wallet: toWalletSnapshot(updatedWallet)})
		if err != nil {
			return fmt.Errorf("encode response: %w", err)
		}
		responseBody = body

		return idemStore.Fill(ctx, in.UserID.String(), createTransactionEndpoint, in.IdempotencyKey, http.StatusCreated, body)
	})
	if err != nil {
		return nil, 0, err
	}
	if walletID != uuid.Nil {
		s.bumpReportVersion(ctx, walletID)
	}
	return responseBody, http.StatusCreated, nil
}

// --- Get / list --------------------------------------------------------------

func (s *Service) Get(ctx context.Context, userID, id uuid.UUID) (transactionResponse, error) {
	t, err := s.transactions.GetByIDAndUserID(ctx, id, userID)
	if errors.Is(err, ErrNotFound) {
		return transactionResponse{}, apierror.ErrNotFound
	}
	if err != nil {
		return transactionResponse{}, err
	}
	return toTransactionResponse(t), nil
}

type ListResult struct {
	Transactions []transactionResponse `json:"transactions"`
	NextCursor   string                `json:"next_cursor,omitempty"`
	HasMore      bool                  `json:"has_more"`
}

func (s *Service) List(ctx context.Context, filter ListFilter) (ListResult, error) {
	page, err := s.transactions.List(ctx, filter)
	if err != nil {
		return ListResult{}, err
	}

	out := make([]transactionResponse, 0, len(page.Transactions))
	for _, t := range page.Transactions {
		out = append(out, toTransactionResponse(t))
	}
	return ListResult{Transactions: out, NextCursor: page.NextCursor, HasMore: page.HasMore}, nil
}

// ListPaymentGroupMembers returns every transaction that shares groupID —
// i.e. every installment linked to the same logical expense — for the
// "pagamenti collegati" section of a transaction's detail view.
func (s *Service) ListPaymentGroupMembers(ctx context.Context, userID, groupID uuid.UUID) (ListResult, error) {
	return s.List(ctx, ListFilter{UserID: userID, PaymentGroupID: groupID})
}

type paymentGroupSummaryResponse struct {
	PaymentGroupID      string `json:"payment_group_id"`
	MemberCount         int    `json:"member_count"`
	NetAmountMinor      int64  `json:"net_amount_minor"`
	Currency            string `json:"currency"`
	RepresentativeID    string `json:"representative_transaction_id"`
	RepresentativeTitle string `json:"representative_title"`
}

// ListPaymentGroups returns every group of 2+ linked transactions for the
// new "pagamenti collegati" list screen (plan.md linked-transactions
// feature).
func (s *Service) ListPaymentGroups(ctx context.Context, userID uuid.UUID) ([]paymentGroupSummaryResponse, error) {
	summaries, err := s.transactions.ListPaymentGroupSummaries(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]paymentGroupSummaryResponse, 0, len(summaries))
	for _, sm := range summaries {
		out = append(out, paymentGroupSummaryResponse{
			PaymentGroupID:      sm.PaymentGroupID.String(),
			MemberCount:         sm.MemberCount,
			NetAmountMinor:      sm.NetAmountMinor,
			Currency:            sm.Currency,
			RepresentativeID:    sm.RepresentativeID.String(),
			RepresentativeTitle: sm.RepresentativeTitle,
		})
	}
	return out, nil
}

// UnlinkPaymentGroup detaches a single transaction from its payment group
// without deleting it — a pure metadata change with no effect on any
// wallet's balance, so it needs only the one row locked (never a wallet).
// If this leaves the group with exactly one other member, that member is
// dissolved back to standalone too (dissolveGroupIfSingleton).
func (s *Service) UnlinkPaymentGroup(ctx context.Context, userID, transactionID uuid.UUID) (transactionResponse, error) {
	var result transactionResponse
	err := s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		existing, err := s.transactions.WithQuerier(tx).LockByIDAndUserID(ctx, transactionID, userID)
		if errors.Is(err, ErrNotFound) {
			return apierror.ErrNotFound
		}
		if err != nil {
			return err
		}
		if existing.PaymentGroupID == nil {
			return apierror.New(http.StatusConflict, "NOT_IN_PAYMENT_GROUP",
				"This transaction isn't linked to any other payment.")
		}
		groupID := *existing.PaymentGroupID
		if err := s.transactions.WithQuerier(tx).SetPaymentGroupID(ctx, transactionID, nil); err != nil {
			return err
		}
		if err := s.dissolveGroupIfSingleton(ctx, tx, userID, groupID); err != nil {
			return err
		}
		updated, err := s.transactions.WithQuerier(tx).GetByIDAndUserID(ctx, transactionID, userID)
		if err != nil {
			return err
		}
		result = toTransactionResponse(updated)
		return nil
	})
	return result, err
}

// --- Update ------------------------------------------------------------------

type UpdateStandardInput struct {
	UserID          uuid.UUID
	TransactionID   uuid.UUID
	WalletID        uuid.UUID
	Direction       string
	AmountMinor     int64
	Title           string
	Description     *string
	CategoryID      *uuid.UUID
	TemplateID      *uuid.UUID
	MediaID         *uuid.UUID
	OccurredAt      time.Time
	ExpectedVersion int64
}

type TransactionWithWallet struct {
	Transaction transactionResponse `json:"transaction"`
	Wallet      walletSnapshot      `json:"wallet"`
}

// UpdateStandard recomputes the affected wallet's balance from the
// *difference* between the old and new impact, inside the same DB
// transaction (plan.md section 13.3, 26.3). If WalletID differs from the
// transaction's current wallet, the transaction is moving: both wallets
// are locked (in a fixed order to avoid deadlocking against a concurrent
// move in the opposite direction) and have their balances adjusted —
// the old wallet loses the transaction's old impact, the new wallet gains
// its new impact.
func (s *Service) UpdateStandard(ctx context.Context, in UpdateStandardInput) (TransactionWithWallet, error) {
	fieldErrors := validateTransactionFields(in.Direction, in.AmountMinor, in.Title)
	if in.WalletID == uuid.Nil {
		fieldErrors["wallet_id"] = apierror.FieldRequired
	}
	if len(fieldErrors) > 0 {
		return TransactionWithWallet{}, apierror.NewValidation(fieldErrors)
	}

	occurredAt := in.OccurredAt
	if occurredAt.IsZero() {
		occurredAt = s.clock.Now()
	}

	var result TransactionWithWallet
	var affectedWalletIDs []uuid.UUID
	err := s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		existing, err := s.transactions.WithQuerier(tx).LockByIDAndUserID(ctx, in.TransactionID, in.UserID)
		if errors.Is(err, ErrNotFound) {
			return apierror.ErrNotFound
		}
		if err != nil {
			return err
		}
		if existing.Kind != KindStandard {
			return apierror.New(http.StatusForbidden, "NOT_EDITABLE",
				"Only standard transactions can be edited.")
		}
		// A voucher-expense leg is also Kind=STANDARD (so it counts in
		// reports) but must only be edited through UpdateVoucherExpense,
		// which knows how to rebalance the meal-voucher lots it consumed.
		if existing.LinkedTransactionID != nil {
			return apierror.New(http.StatusForbidden, "NOT_EDITABLE",
				"Voucher expenses can only be edited through the voucher expense endpoint.")
		}
		if err := s.resolveAttachments(ctx, tx, in.UserID, in.CategoryID, in.TemplateID, in.MediaID); err != nil {
			return err
		}

		if existing.WalletID == in.WalletID {
			wallet, err := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, in.WalletID, in.UserID)
			if errors.Is(err, wallets.ErrNotFound) {
				return apierror.NewValidation(map[string]string{"wallet_id": "WALLET_NOT_FOUND"})
			}
			if err != nil {
				return fmt.Errorf("lock wallet: %w", err)
			}
			affectedWalletIDs = append(affectedWalletIDs, wallet.ID)
			if err := rejectMealVoucherWallet(wallet); err != nil {
				return err
			}

			diff := SignedDelta(in.Direction, in.AmountMinor) - SignedDelta(existing.Direction, existing.AmountMinor)
			newBalance := wallet.CurrentBalanceMinor + diff

			updated, err := s.transactions.WithQuerier(tx).Update(ctx, in.TransactionID, in.UserID, in.ExpectedVersion, UpdateInput{
				WalletID: wallet.ID, Direction: in.Direction, AmountMinor: in.AmountMinor, Title: in.Title,
				Description: in.Description, CategoryID: in.CategoryID, TemplateID: in.TemplateID, MediaID: in.MediaID,
				OccurredAt: occurredAt,
			})
			if errors.Is(err, ErrNotFound) {
				if _, getErr := s.transactions.WithQuerier(tx).GetByIDAndUserID(ctx, in.TransactionID, in.UserID); getErr == nil {
					return apierror.ErrConflict
				}
				return apierror.ErrNotFound
			}
			if err != nil {
				return err
			}

			updatedWallet, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, wallet.ID, newBalance, wallet.Version)
			if err != nil {
				return fmt.Errorf("update wallet balance: %w", err)
			}

			if err := s.audit.WithQuerier(tx).Record(ctx, updated.ID, in.UserID, AuditActionUpdated, existing, updated); err != nil {
				return err
			}

			result = TransactionWithWallet{Transaction: toTransactionResponse(updated), Wallet: toWalletSnapshot(updatedWallet)}
			return nil
		}

		firstID, secondID := orderedWalletIDs(existing.WalletID, in.WalletID)
		firstWallet, err := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, firstID, in.UserID)
		if errors.Is(err, wallets.ErrNotFound) {
			return apierror.NewValidation(map[string]string{"wallet_id": "WALLET_NOT_FOUND"})
		}
		if err != nil {
			return fmt.Errorf("lock wallet: %w", err)
		}
		secondWallet, err := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, secondID, in.UserID)
		if errors.Is(err, wallets.ErrNotFound) {
			return apierror.NewValidation(map[string]string{"wallet_id": "WALLET_NOT_FOUND"})
		}
		if err != nil {
			return fmt.Errorf("lock wallet: %w", err)
		}

		oldWallet, newWallet := firstWallet, secondWallet
		if oldWallet.ID != existing.WalletID {
			oldWallet, newWallet = secondWallet, firstWallet
		}
		affectedWalletIDs = append(affectedWalletIDs, oldWallet.ID, newWallet.ID)
		if err := rejectMealVoucherWallet(oldWallet); err != nil {
			return err
		}
		if err := rejectMealVoucherWallet(newWallet); err != nil {
			return err
		}

		oldBalance := oldWallet.CurrentBalanceMinor - SignedDelta(existing.Direction, existing.AmountMinor)
		newBalance := newWallet.CurrentBalanceMinor + SignedDelta(in.Direction, in.AmountMinor)

		updated, err := s.transactions.WithQuerier(tx).Update(ctx, in.TransactionID, in.UserID, in.ExpectedVersion, UpdateInput{
			WalletID: newWallet.ID, Direction: in.Direction, AmountMinor: in.AmountMinor, Title: in.Title,
			Description: in.Description, CategoryID: in.CategoryID, TemplateID: in.TemplateID, MediaID: in.MediaID,
			OccurredAt: occurredAt,
		})
		if errors.Is(err, ErrNotFound) {
			if _, getErr := s.transactions.WithQuerier(tx).GetByIDAndUserID(ctx, in.TransactionID, in.UserID); getErr == nil {
				return apierror.ErrConflict
			}
			return apierror.ErrNotFound
		}
		if err != nil {
			return err
		}

		if _, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, oldWallet.ID, oldBalance, oldWallet.Version); err != nil {
			return fmt.Errorf("update source wallet balance: %w", err)
		}
		updatedNewWallet, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, newWallet.ID, newBalance, newWallet.Version)
		if err != nil {
			return fmt.Errorf("update destination wallet balance: %w", err)
		}

		if err := s.audit.WithQuerier(tx).Record(ctx, updated.ID, in.UserID, AuditActionUpdated, existing, updated); err != nil {
			return err
		}

		result = TransactionWithWallet{Transaction: toTransactionResponse(updated), Wallet: toWalletSnapshot(updatedNewWallet)}
		return nil
	})
	if err == nil {
		for _, id := range affectedWalletIDs {
			s.bumpReportVersion(ctx, id)
		}
	}
	return result, err
}

// --- Update opening balance ---------------------------------------------------

type UpdateOpeningBalanceInput struct {
	UserID          uuid.UUID
	TransactionID   uuid.UUID
	AmountMinor     int64
	OccurredAt      time.Time
	ExpectedVersion int64
}

// UpdateOpeningBalance lets the user correct a wallet's OPENING_BALANCE
// entry — the amount and date only, never wallet/title/category/direction,
// which are structural to what makes it an opening balance rather than an
// ordinary transaction. Kept separate from UpdateStandard (which requires
// KindStandard) rather than relaxing that check, since the two share almost
// no editable surface. Recomputes the wallet balance from the *difference*
// like UpdateStandard, inside the same locked DB transaction.
func (s *Service) UpdateOpeningBalance(ctx context.Context, in UpdateOpeningBalanceInput) (TransactionWithWallet, error) {
	fieldErrors := map[string]string{}
	if in.AmountMinor <= 0 {
		fieldErrors["amount_minor"] = apierror.FieldAmountNotPositive
	} else if in.AmountMinor > maxAmountMinor {
		fieldErrors["amount_minor"] = apierror.FieldAmountImplausible
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
		if existing.Kind != KindOpeningBalance {
			return apierror.New(http.StatusForbidden, "NOT_EDITABLE",
				"Only the initial balance can be edited through this endpoint.")
		}

		wallet, err := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, existing.WalletID, in.UserID)
		if err != nil {
			return fmt.Errorf("lock wallet: %w", err)
		}
		walletID = wallet.ID

		diff := SignedDelta(existing.Direction, in.AmountMinor) - SignedDelta(existing.Direction, existing.AmountMinor)
		newBalance := wallet.CurrentBalanceMinor + diff

		updated, err := s.transactions.WithQuerier(tx).Update(ctx, in.TransactionID, in.UserID, in.ExpectedVersion, UpdateInput{
			WalletID: existing.WalletID, Direction: existing.Direction, AmountMinor: in.AmountMinor, Title: existing.Title,
			Description: existing.Description, CategoryID: existing.CategoryID, TemplateID: existing.TemplateID, MediaID: existing.MediaID,
			OccurredAt: occurredAt,
		})
		if errors.Is(err, ErrNotFound) {
			if _, getErr := s.transactions.WithQuerier(tx).GetByIDAndUserID(ctx, in.TransactionID, in.UserID); getErr == nil {
				return apierror.ErrConflict
			}
			return apierror.ErrNotFound
		}
		if err != nil {
			return err
		}

		updatedWallet, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, wallet.ID, newBalance, wallet.Version)
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

// --- Delete --------------------------------------------------------------------

// Delete reverses the transaction's balance impact and soft-deletes it
// (plan.md section 13.4). OPENING_BALANCE cannot be deleted this way
// (section 13.4: "should not be deletable from the ordinary UI"), and
// neither can TRANSFER — deleting one leg of a linked pair without the
// other would corrupt the pairing; a transfer must be reversed with a new
// transfer instead. A system-generated row (the automatic "Buoni scaduti"
// voucher-expiry write-off) can never be deleted — it's a realized loss,
// not a correction.
//
// A meal-voucher credit/removal or expense additionally needs its lot
// bookkeeping reversed, and a voucher expense may have a second, linked leg
// on another wallet that must be deleted alongside it — see
// deleteVoucherCreditOrRemoval/deleteVoucherExpense in voucher.go. Locking
// resolves both wallets up front (in a fixed order, mirroring
// CreateTransfer) whenever a linked leg exists, so this never deadlocks
// against a concurrent operation touching the same two wallets.
func (s *Service) Delete(ctx context.Context, userID, transactionID uuid.UUID) (walletSnapshot, error) {
	var result walletSnapshot
	var walletIDs []uuid.UUID
	err := s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		existing, err := s.transactions.WithQuerier(tx).LockByIDAndUserID(ctx, transactionID, userID)
		if errors.Is(err, ErrNotFound) {
			return apierror.ErrNotFound
		}
		if err != nil {
			return err
		}
		if existing.Kind == KindOpeningBalance {
			return apierror.New(http.StatusForbidden, "OPENING_BALANCE_NOT_DELETABLE",
				"The initial balance cannot be deleted directly.")
		}
		if existing.Kind == KindTransfer {
			return apierror.New(http.StatusForbidden, "TRANSFER_NOT_DELETABLE",
				"Transfers cannot be deleted directly.")
		}
		if existing.SystemGenerated {
			return apierror.New(http.StatusForbidden, "VOUCHER_AUTO_ADJUSTMENT_NOT_DELETABLE",
				"Automatic voucher expiry adjustments cannot be deleted.")
		}

		var linked *Transaction
		if existing.LinkedTransactionID != nil {
			l, err := s.transactions.WithQuerier(tx).LockByIDAndUserID(ctx, *existing.LinkedTransactionID, userID)
			if err != nil {
				return fmt.Errorf("lock linked transaction: %w", err)
			}
			linked = &l
		}

		var primaryWallet, linkedWallet wallets.Wallet
		if linked == nil {
			primaryWallet, err = s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, existing.WalletID, userID)
			if err != nil {
				return fmt.Errorf("lock wallet: %w", err)
			}
		} else {
			firstID, secondID := orderedWalletIDs(existing.WalletID, linked.WalletID)
			firstWallet, err := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, firstID, userID)
			if err != nil {
				return fmt.Errorf("lock wallet: %w", err)
			}
			secondWallet, err := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, secondID, userID)
			if err != nil {
				return fmt.Errorf("lock wallet: %w", err)
			}
			if firstWallet.ID == existing.WalletID {
				primaryWallet, linkedWallet = firstWallet, secondWallet
			} else {
				primaryWallet, linkedWallet = secondWallet, firstWallet
			}
		}
		walletIDs = append(walletIDs, primaryWallet.ID)
		if linked != nil {
			walletIDs = append(walletIDs, linkedWallet.ID)
		}

		switch {
		case primaryWallet.Type == wallets.TypeMealVoucher && existing.Kind == KindBalanceAdjustment:
			snap, err := s.deleteVoucherCreditOrRemoval(ctx, tx, userID, existing, primaryWallet)
			if err != nil {
				return err
			}
			result = snap

		case primaryWallet.Type == wallets.TypeMealVoucher && existing.Kind == KindStandard:
			// existing IS the voucher-wallet leg; linked (if any) is the
			// shortfall leg on another wallet.
			var otherLeg *Transaction
			var otherWallet wallets.Wallet
			if linked != nil {
				otherLeg, otherWallet = linked, linkedWallet
			}
			snap, err := s.deleteVoucherExpense(ctx, tx, userID, existing, primaryWallet, otherLeg, otherWallet)
			if err != nil {
				return err
			}
			result = snap

		case existing.Kind == KindStandard && linked != nil:
			// existing is the shortfall leg (primaryWallet isn't
			// MEAL_VOUCHER, ruled out above); linked is the voucher leg —
			// LinkedTransactionID is only ever set on a voucher-expense
			// pair, so this is unambiguous.
			voucherLeg := *linked
			otherLeg := existing
			snap, err := s.deleteVoucherExpense(ctx, tx, userID, voucherLeg, linkedWallet, &otherLeg, primaryWallet)
			if err != nil {
				return err
			}
			result = snap

		default:
			newBalance := primaryWallet.CurrentBalanceMinor - SignedDelta(existing.Direction, existing.AmountMinor)
			if err := s.transactions.WithQuerier(tx).SoftDelete(ctx, transactionID, userID); err != nil {
				return err
			}
			updatedWallet, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, primaryWallet.ID, newBalance, primaryWallet.Version)
			if err != nil {
				return fmt.Errorf("update wallet balance: %w", err)
			}
			if err := s.audit.WithQuerier(tx).Record(ctx, transactionID, userID, AuditActionDeleted, existing, nil); err != nil {
				return err
			}
			// This is the only branch a payment-group member can ever reach:
			// CreateStandard's link-target validation already rejects a
			// meal-voucher-wallet target and any transaction with a
			// LinkedTransactionID, which is what would otherwise route a
			// group member into the voucher-expense branches above — a
			// transfer leg is rejected even earlier (line ~815) and is never
			// deletable through this endpoint at all.
			if existing.PaymentGroupID != nil {
				if err := s.dissolveGroupIfSingleton(ctx, tx, userID, *existing.PaymentGroupID); err != nil {
					return err
				}
			}
			result = toWalletSnapshot(updatedWallet)
		}
		return nil
	})
	if err == nil {
		for _, id := range walletIDs {
			s.bumpReportVersion(ctx, id)
		}
	}
	return result, err
}

// dissolveGroupIfSingleton reverts a payment group back to a plain
// standalone transaction once deleting/unlinking a member leaves it with
// exactly one — a group of one is meaningless, and leaving payment_group_id
// set would make that lone survivor render an empty "linked payments"
// section forever. Shared by Delete's cleanup and UnlinkPaymentGroup so the
// two paths can't drift apart.
func (s *Service) dissolveGroupIfSingleton(ctx context.Context, tx pgx.Tx, userID, groupID uuid.UUID) error {
	page, err := s.transactions.WithQuerier(tx).List(ctx, ListFilter{UserID: userID, PaymentGroupID: groupID, Limit: 2})
	if err != nil {
		return fmt.Errorf("list remaining payment group members: %w", err)
	}
	if len(page.Transactions) == 1 {
		if err := s.transactions.WithQuerier(tx).SetPaymentGroupID(ctx, page.Transactions[0].ID, nil); err != nil {
			return fmt.Errorf("dissolve payment group: %w", err)
		}
	}
	return nil
}

// --- Balance adjustment ----------------------------------------------------

type CreateBalanceAdjustmentInput struct {
	UserID             uuid.UUID
	WalletID           uuid.UUID
	TargetBalanceMinor int64
	Reason             string
	OccurredAt         time.Time
	SessionID          *uuid.UUID
	IdempotencyKey     uuid.UUID
	RequestBody        []byte
}

// CreateBalanceAdjustment computes the delta between the current and
// desired balance *inside* the locked transaction — the client sends the
// target, never the delta, which it cannot compute authoritatively
// (plan.md section 13.5). A zero delta is a no-op: no BALANCE_ADJUSTMENT
// row is created, since amount_minor must be > 0.
func (s *Service) CreateBalanceAdjustment(ctx context.Context, in CreateBalanceAdjustmentInput) ([]byte, int, error) {
	if in.WalletID == uuid.Nil {
		return nil, 0, apierror.NewValidation(map[string]string{"wallet_id": apierror.FieldRequired})
	}
	if in.IdempotencyKey == uuid.Nil {
		return nil, 0, apierror.NewValidation(map[string]string{"idempotency_key": apierror.FieldRequired})
	}
	if in.TargetBalanceMinor < 0 {
		return nil, 0, apierror.NewValidation(map[string]string{"target_balance_minor": apierror.FieldNegativeNotAllowed})
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
		claimed, existing, claimErr := idemStore.Claim(ctx, in.UserID.String(), balanceAdjustmentEndpoint, in.IdempotencyKey, requestHash, idempotencyTTL)
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
		if err := rejectMealVoucherWallet(wallet); err != nil {
			return err
		}

		delta := in.TargetBalanceMinor - wallet.CurrentBalanceMinor

		var body []byte
		if delta == 0 {
			encoded, encErr := json.Marshal(struct {
				Transaction *transactionResponse `json:"transaction"`
				Wallet      walletSnapshot       `json:"wallet"`
			}{Transaction: nil, Wallet: toWalletSnapshot(wallet)})
			if encErr != nil {
				return encErr
			}
			body = encoded
		} else {
			direction := DirectionCredit
			amount := delta
			if delta < 0 {
				direction = DirectionDebit
				amount = -delta
			}

			var description *string
			if strings.TrimSpace(in.Reason) != "" {
				description = &in.Reason
			}

			created, createErr := s.transactions.WithQuerier(tx).Create(ctx, CreateInput{
				WalletID: wallet.ID, UserID: in.UserID, Direction: direction, Kind: KindBalanceAdjustment,
				AmountMinor: amount, Currency: wallet.Currency, Title: "Rettifica saldo",
				Description: description, OccurredAt: occurredAt, CreatedBySessionID: in.SessionID,
			})
			if createErr != nil {
				return fmt.Errorf("create balance adjustment: %w", createErr)
			}

			updatedWallet, updErr := s.wallets.WithQuerier(tx).UpdateBalance(ctx, wallet.ID, in.TargetBalanceMinor, wallet.Version)
			if updErr != nil {
				return fmt.Errorf("update wallet balance: %w", updErr)
			}
			walletID = wallet.ID

			if auditErr := s.audit.WithQuerier(tx).Record(ctx, created.ID, in.UserID, AuditActionCreated, nil, created); auditErr != nil {
				return auditErr
			}

			encoded, encErr := json.Marshal(struct {
				Transaction transactionResponse `json:"transaction"`
				Wallet      walletSnapshot      `json:"wallet"`
			}{Transaction: toTransactionResponse(created), Wallet: toWalletSnapshot(updatedWallet)})
			if encErr != nil {
				return encErr
			}
			body = encoded
		}

		responseBody = body
		return idemStore.Fill(ctx, in.UserID.String(), balanceAdjustmentEndpoint, in.IdempotencyKey, http.StatusCreated, body)
	})
	if err != nil {
		return nil, 0, err
	}
	if walletID != uuid.Nil {
		s.bumpReportVersion(ctx, walletID)
	}
	return responseBody, http.StatusCreated, nil
}

// --- Create wallet -----------------------------------------------------------

// CreateWalletInput creates a wallet and, if given a non-zero opening
// balance, the matching OPENING_BALANCE ledger row in the same DB
// transaction — mirroring what registration does for a user's first wallet
// (internal/auth), so every wallet's balance stays reconcilable against its
// ledger (plan.md section 13.6) regardless of whether it was created at
// signup or later from the wallets screen. Lives here rather than in
// wallets.Service because it needs both wallets.Repository and
// transactions.Repository under one DB transaction, which only this
// service already depends on (mirrors CreateBalanceAdjustment living here
// despite being wallet-resource-shaped).
type CreateWalletInput struct {
	UserID              uuid.UUID
	Name                string
	Type                string
	Icon                string
	Color               string
	OpeningBalanceMinor int64
	SessionID           *uuid.UUID
	IdempotencyKey      uuid.UUID
	RequestBody         []byte

	// Only meaningful (and only accepted) when Type == wallets.TypeMealVoucher.
	// The three expiry fields default to wallets.DefaultVoucherExpiry* when
	// omitted, so a client can create a voucher wallet without deciding on
	// a policy up front. InitialVoucherQuantity (default 0) creates the
	// first lot atomically alongside the wallet, dated VoucherLoadedAt
	// (default now) — the same operation CreateVoucherCredit performs for
	// every later top-up.
	VoucherUnitValueMinor    *int64
	VoucherExpiryCutoffMonth *int
	VoucherExpiryMonth       *int
	VoucherExpiryDay         *int
	InitialVoucherQuantity   int
	VoucherLoadedAt          time.Time
}

func (s *Service) CreateWallet(ctx context.Context, in CreateWalletInput) ([]byte, int, error) {
	fieldErrors := wallets.ValidateFields(in.Name, in.Type, in.Icon, in.Color)
	for k, v := range wallets.ValidateVoucherUnitValue(in.Type, in.VoucherUnitValueMinor) {
		fieldErrors[k] = v
	}

	cutoffMonth, expiryMonth, expiryDay := in.VoucherExpiryCutoffMonth, in.VoucherExpiryMonth, in.VoucherExpiryDay
	if in.Type == wallets.TypeMealVoucher {
		if cutoffMonth == nil {
			d := wallets.DefaultVoucherExpiryCutoffMonth
			cutoffMonth = &d
		}
		if expiryMonth == nil {
			d := wallets.DefaultVoucherExpiryMonth
			expiryMonth = &d
		}
		if expiryDay == nil {
			d := wallets.DefaultVoucherExpiryDay
			expiryDay = &d
		}
	}
	for k, v := range wallets.ValidateVoucherExpiryFields(in.Type, cutoffMonth, expiryMonth, expiryDay) {
		fieldErrors[k] = v
	}

	if in.Type == wallets.TypeMealVoucher {
		if in.OpeningBalanceMinor != 0 {
			fieldErrors["opening_balance_minor"] = apierror.FieldNotAllowedForWalletType
		}
		if in.InitialVoucherQuantity < 0 {
			fieldErrors["initial_voucher_quantity"] = apierror.FieldNegativeNotAllowed
		}
	} else {
		if in.OpeningBalanceMinor < 0 {
			fieldErrors["opening_balance_minor"] = apierror.FieldNegativeNotAllowed
		}
		if in.InitialVoucherQuantity != 0 {
			fieldErrors["initial_voucher_quantity"] = apierror.FieldNotAllowedForWalletType
		}
	}
	if in.IdempotencyKey == uuid.Nil {
		fieldErrors["idempotency_key"] = apierror.FieldRequired
	}
	if len(fieldErrors) > 0 {
		return nil, 0, apierror.NewValidation(fieldErrors)
	}

	now := s.clock.Now()
	loadedAt := in.VoucherLoadedAt
	if loadedAt.IsZero() {
		loadedAt = now
	}
	requestHash := sha256Sum(in.RequestBody)

	var responseBody []byte
	err := s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		idemStore := idempotency.NewStore(tx)
		claimed, existing, claimErr := idemStore.Claim(ctx, in.UserID.String(), createWalletEndpoint, in.IdempotencyKey, requestHash, idempotencyTTL)
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

		wallet, err := s.wallets.WithQuerier(tx).Create(ctx, wallets.CreateRowInput{
			UserID: in.UserID, Name: in.Name, Currency: "EUR", Type: in.Type, Icon: in.Icon, Color: in.Color,
			OpeningBalanceMinor:      in.OpeningBalanceMinor,
			VoucherUnitValueMinor:    in.VoucherUnitValueMinor,
			VoucherExpiryCutoffMonth: cutoffMonth, VoucherExpiryMonth: expiryMonth, VoucherExpiryDay: expiryDay,
		})
		if err != nil {
			return fmt.Errorf("create wallet: %w", err)
		}

		switch {
		case in.Type == wallets.TypeMealVoucher && in.InitialVoucherQuantity > 0:
			created, err := s.transactions.WithQuerier(tx).Create(ctx, CreateInput{
				WalletID: wallet.ID, UserID: in.UserID, Direction: DirectionCredit, Kind: KindBalanceAdjustment,
				AmountMinor: int64(in.InitialVoucherQuantity) * (*in.VoucherUnitValueMinor), Currency: "EUR",
				Title: "Buoni ricevuti", OccurredAt: loadedAt, CreatedBySessionID: in.SessionID,
			})
			if err != nil {
				return fmt.Errorf("create initial voucher credit: %w", err)
			}
			expiresAt := wallets.ComputeLotExpiry(*cutoffMonth, *expiryMonth, *expiryDay, loadedAt)
			if _, err := s.wallets.WithQuerier(tx).CreateVoucherLot(ctx, wallet.ID, in.InitialVoucherQuantity, expiresAt, created.ID); err != nil {
				return fmt.Errorf("create initial voucher lot: %w", err)
			}
			newBalance := int64(in.InitialVoucherQuantity) * (*in.VoucherUnitValueMinor)
			wallet, err = s.wallets.WithQuerier(tx).UpdateBalance(ctx, wallet.ID, newBalance, wallet.Version)
			if err != nil {
				return fmt.Errorf("update wallet balance: %w", err)
			}
			if err := s.audit.WithQuerier(tx).Record(ctx, created.ID, in.UserID, AuditActionCreated, nil, created); err != nil {
				return err
			}

		// amount_minor must be > 0 per the transactions table constraint — a
		// zero opening balance is valid but simply has no OPENING_BALANCE
		// ledger row (mirrors registration's identical rule).
		case in.Type != wallets.TypeMealVoucher && in.OpeningBalanceMinor > 0:
			created, err := s.transactions.WithQuerier(tx).Create(ctx, CreateInput{
				WalletID: wallet.ID, UserID: in.UserID, Direction: DirectionCredit, Kind: KindOpeningBalance,
				AmountMinor: in.OpeningBalanceMinor, Currency: "EUR", Title: "Saldo iniziale",
				OccurredAt: now, CreatedBySessionID: in.SessionID,
			})
			if err != nil {
				return fmt.Errorf("create opening balance transaction: %w", err)
			}
			if err := s.audit.WithQuerier(tx).Record(ctx, created.ID, in.UserID, AuditActionCreated, nil, created); err != nil {
				return err
			}
		}

		body, err := json.Marshal(struct {
			Wallet walletSnapshot `json:"wallet"`
		}{Wallet: toWalletSnapshot(wallet)})
		if err != nil {
			return fmt.Errorf("encode response: %w", err)
		}
		responseBody = body

		return idemStore.Fill(ctx, in.UserID.String(), createWalletEndpoint, in.IdempotencyKey, http.StatusCreated, body)
	})
	if err != nil {
		return nil, 0, err
	}
	return responseBody, http.StatusCreated, nil
}

// --- Transfers -----------------------------------------------------------

// CreateTransferInput moves money between two of the same user's wallets
// atomically: a DEBIT row on the source and a CREDIT row on the
// destination, both kind=TRANSFER and linked via transfer_pair_id (plan.md
// section 11.10's TRANSFER kind, reserved since migration 0006 but unused
// until now). Deliberately excluded from expense/income report totals —
// internal/reports only ever queries STANDARD/BALANCE_ADJUSTMENT kinds, so
// TRANSFER rows are invisible there by construction, no extra filtering
// needed.
type CreateTransferInput struct {
	UserID              uuid.UUID
	SourceWalletID      uuid.UUID
	DestinationWalletID uuid.UUID
	AmountMinor         int64
	Note                *string
	OccurredAt          time.Time
	SessionID           *uuid.UUID
	IdempotencyKey      uuid.UUID
	RequestBody         []byte
}

func (s *Service) CreateTransfer(ctx context.Context, in CreateTransferInput) ([]byte, int, error) {
	fieldErrors := map[string]string{}
	if in.SourceWalletID == uuid.Nil {
		fieldErrors["source_wallet_id"] = apierror.FieldRequired
	}
	if in.DestinationWalletID == uuid.Nil {
		fieldErrors["destination_wallet_id"] = apierror.FieldRequired
	}
	if in.SourceWalletID != uuid.Nil && in.SourceWalletID == in.DestinationWalletID {
		fieldErrors["destination_wallet_id"] = "SAME_AS_SOURCE"
	}
	if in.AmountMinor <= 0 {
		fieldErrors["amount_minor"] = apierror.FieldAmountNotPositive
	} else if in.AmountMinor > maxAmountMinor {
		fieldErrors["amount_minor"] = apierror.FieldAmountImplausible
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
	const title = "Trasferimento"

	var responseBody []byte
	var sourceWalletID, destWalletID uuid.UUID
	err := s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		idemStore := idempotency.NewStore(tx)
		claimed, existing, claimErr := idemStore.Claim(ctx, in.UserID.String(), transferEndpoint, in.IdempotencyKey, requestHash, idempotencyTTL)
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

		// Lock both wallets in a fixed order (ascending UUID) so a
		// concurrent transfer touching the same two wallets in the opposite
		// direction can't deadlock against this one.
		firstID, secondID := orderedWalletIDs(in.SourceWalletID, in.DestinationWalletID)
		firstWallet, err := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, firstID, in.UserID)
		if errors.Is(err, wallets.ErrNotFound) {
			return apierror.NewValidation(map[string]string{"source_wallet_id": "WALLET_NOT_FOUND"})
		}
		if err != nil {
			return fmt.Errorf("lock wallet: %w", err)
		}
		secondWallet, err := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, secondID, in.UserID)
		if errors.Is(err, wallets.ErrNotFound) {
			return apierror.NewValidation(map[string]string{"destination_wallet_id": "WALLET_NOT_FOUND"})
		}
		if err != nil {
			return fmt.Errorf("lock wallet: %w", err)
		}

		source, dest := firstWallet, secondWallet
		if source.ID != in.SourceWalletID {
			source, dest = secondWallet, firstWallet
		}
		sourceWalletID, destWalletID = source.ID, dest.ID

		if err := rejectMealVoucherWallet(source); err != nil {
			return err
		}
		if err := rejectMealVoucherWallet(dest); err != nil {
			return err
		}
		if source.Currency != dest.Currency {
			return apierror.NewValidation(map[string]string{"destination_wallet_id": apierror.FieldCurrencyMismatch})
		}

		debit, err := s.transactions.WithQuerier(tx).Create(ctx, CreateInput{
			WalletID: source.ID, UserID: in.UserID, Direction: DirectionDebit, Kind: KindTransfer,
			AmountMinor: in.AmountMinor, Currency: source.Currency, Title: title, Description: in.Note,
			OccurredAt: occurredAt, CreatedBySessionID: in.SessionID,
		})
		if err != nil {
			return fmt.Errorf("create transfer debit: %w", err)
		}

		credit, err := s.transactions.WithQuerier(tx).Create(ctx, CreateInput{
			WalletID: dest.ID, UserID: in.UserID, Direction: DirectionCredit, Kind: KindTransfer,
			AmountMinor: in.AmountMinor, Currency: dest.Currency, Title: title, Description: in.Note,
			OccurredAt: occurredAt, CreatedBySessionID: in.SessionID, TransferPairID: &debit.ID,
		})
		if err != nil {
			return fmt.Errorf("create transfer credit: %w", err)
		}
		if err := s.transactions.WithQuerier(tx).SetTransferPairID(ctx, debit.ID, credit.ID); err != nil {
			return err
		}
		debit.TransferPairID = &credit.ID

		newSourceBalance := source.CurrentBalanceMinor - in.AmountMinor
		newDestBalance := dest.CurrentBalanceMinor + in.AmountMinor

		updatedSource, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, source.ID, newSourceBalance, source.Version)
		if err != nil {
			return fmt.Errorf("update source wallet balance: %w", err)
		}
		updatedDest, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, dest.ID, newDestBalance, dest.Version)
		if err != nil {
			return fmt.Errorf("update destination wallet balance: %w", err)
		}

		if err := s.audit.WithQuerier(tx).Record(ctx, debit.ID, in.UserID, AuditActionCreated, nil, debit); err != nil {
			return err
		}
		if err := s.audit.WithQuerier(tx).Record(ctx, credit.ID, in.UserID, AuditActionCreated, nil, credit); err != nil {
			return err
		}

		body, err := json.Marshal(struct {
			DebitTransaction  transactionResponse `json:"debit_transaction"`
			CreditTransaction transactionResponse `json:"credit_transaction"`
			SourceWallet      walletSnapshot      `json:"source_wallet"`
			DestinationWallet walletSnapshot      `json:"destination_wallet"`
		}{
			DebitTransaction:  toTransactionResponse(debit),
			CreditTransaction: toTransactionResponse(credit),
			SourceWallet:      toWalletSnapshot(updatedSource),
			DestinationWallet: toWalletSnapshot(updatedDest),
		})
		if err != nil {
			return fmt.Errorf("encode response: %w", err)
		}
		responseBody = body

		return idemStore.Fill(ctx, in.UserID.String(), transferEndpoint, in.IdempotencyKey, http.StatusCreated, body)
	})
	if err != nil {
		return nil, 0, err
	}
	s.bumpReportVersion(ctx, sourceWalletID)
	s.bumpReportVersion(ctx, destWalletID)
	return responseBody, http.StatusCreated, nil
}

// TransferWithWallets mirrors CreateTransfer's response shape so the
// client's TransferResult parser works for both create and update.
type TransferWithWallets struct {
	DebitTransaction  transactionResponse `json:"debit_transaction"`
	CreditTransaction transactionResponse `json:"credit_transaction"`
	SourceWallet      walletSnapshot      `json:"source_wallet"`
	DestinationWallet walletSnapshot      `json:"destination_wallet"`
}

type UpdateTransferInput struct {
	UserID          uuid.UUID
	TransactionID   uuid.UUID // either leg of the pair
	AmountMinor     int64
	OccurredAt      time.Time
	ExpectedVersion int64 // version of the leg identified by TransactionID
}

// UpdateTransfer lets the user correct a transfer's amount and date — the
// same narrow scope as UpdateOpeningBalance, and for the same reason:
// source/destination wallet, title, and the DEBIT/CREDIT pairing are
// structural to what makes the two rows a linked transfer, never editable.
// TransactionID may be either leg (the transaction detail screen shows one
// row per wallet, so the user could open either); both legs are located,
// locked, and updated together so the pair never drifts out of sync.
// Deletion stays forbidden (Delete already rejects KindTransfer) — a
// transfer is reversed with a new transfer in the other direction, not by
// deleting one leg without the other.
func (s *Service) UpdateTransfer(ctx context.Context, in UpdateTransferInput) (TransferWithWallets, error) {
	fieldErrors := map[string]string{}
	if in.AmountMinor <= 0 {
		fieldErrors["amount_minor"] = apierror.FieldAmountNotPositive
	} else if in.AmountMinor > maxAmountMinor {
		fieldErrors["amount_minor"] = apierror.FieldAmountImplausible
	}
	if len(fieldErrors) > 0 {
		return TransferWithWallets{}, apierror.NewValidation(fieldErrors)
	}

	occurredAt := in.OccurredAt
	if occurredAt.IsZero() {
		occurredAt = s.clock.Now()
	}

	var result TransferWithWallets
	var sourceWalletID, destWalletID uuid.UUID
	err := s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		existing, err := s.transactions.WithQuerier(tx).LockByIDAndUserID(ctx, in.TransactionID, in.UserID)
		if errors.Is(err, ErrNotFound) {
			return apierror.ErrNotFound
		}
		if err != nil {
			return err
		}
		if existing.Kind != KindTransfer {
			return apierror.New(http.StatusForbidden, "NOT_EDITABLE",
				"Only transfers can be edited through this endpoint.")
		}

		pair, err := s.transactions.WithQuerier(tx).LockByIDAndUserID(ctx, *existing.TransferPairID, in.UserID)
		if err != nil {
			return fmt.Errorf("lock transfer pair: %w", err)
		}

		debitTx, creditTx := existing, pair
		if existing.Direction == DirectionCredit {
			debitTx, creditTx = pair, existing
		}

		// Lock both wallets in a fixed order, mirroring CreateTransfer, so a
		// concurrent transfer touching the same two wallets can't deadlock
		// against this one.
		firstID, secondID := orderedWalletIDs(debitTx.WalletID, creditTx.WalletID)
		firstWallet, err := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, firstID, in.UserID)
		if err != nil {
			return fmt.Errorf("lock wallet: %w", err)
		}
		secondWallet, err := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, secondID, in.UserID)
		if err != nil {
			return fmt.Errorf("lock wallet: %w", err)
		}
		source, dest := firstWallet, secondWallet
		if source.ID != debitTx.WalletID {
			source, dest = secondWallet, firstWallet
		}
		sourceWalletID, destWalletID = source.ID, dest.ID

		expectedDebitVersion, expectedCreditVersion := debitTx.Version, creditTx.Version
		if in.TransactionID == debitTx.ID {
			expectedDebitVersion = in.ExpectedVersion
		} else {
			expectedCreditVersion = in.ExpectedVersion
		}

		updatedDebit, err := s.transactions.WithQuerier(tx).Update(ctx, debitTx.ID, in.UserID, expectedDebitVersion, UpdateInput{
			WalletID: debitTx.WalletID, Direction: DirectionDebit, AmountMinor: in.AmountMinor, Title: debitTx.Title,
			Description: debitTx.Description, CategoryID: debitTx.CategoryID, TemplateID: debitTx.TemplateID, MediaID: debitTx.MediaID,
			OccurredAt: occurredAt,
		})
		if errors.Is(err, ErrNotFound) {
			if _, getErr := s.transactions.WithQuerier(tx).GetByIDAndUserID(ctx, debitTx.ID, in.UserID); getErr == nil {
				return apierror.ErrConflict
			}
			return apierror.ErrNotFound
		}
		if err != nil {
			return err
		}

		updatedCredit, err := s.transactions.WithQuerier(tx).Update(ctx, creditTx.ID, in.UserID, expectedCreditVersion, UpdateInput{
			WalletID: creditTx.WalletID, Direction: DirectionCredit, AmountMinor: in.AmountMinor, Title: creditTx.Title,
			Description: creditTx.Description, CategoryID: creditTx.CategoryID, TemplateID: creditTx.TemplateID, MediaID: creditTx.MediaID,
			OccurredAt: occurredAt,
		})
		if errors.Is(err, ErrNotFound) {
			if _, getErr := s.transactions.WithQuerier(tx).GetByIDAndUserID(ctx, creditTx.ID, in.UserID); getErr == nil {
				return apierror.ErrConflict
			}
			return apierror.ErrNotFound
		}
		if err != nil {
			return err
		}

		sourceDiff := SignedDelta(DirectionDebit, in.AmountMinor) - SignedDelta(DirectionDebit, debitTx.AmountMinor)
		destDiff := SignedDelta(DirectionCredit, in.AmountMinor) - SignedDelta(DirectionCredit, creditTx.AmountMinor)

		updatedSource, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, source.ID, source.CurrentBalanceMinor+sourceDiff, source.Version)
		if err != nil {
			return fmt.Errorf("update source wallet balance: %w", err)
		}
		updatedDest, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, dest.ID, dest.CurrentBalanceMinor+destDiff, dest.Version)
		if err != nil {
			return fmt.Errorf("update destination wallet balance: %w", err)
		}

		if err := s.audit.WithQuerier(tx).Record(ctx, updatedDebit.ID, in.UserID, AuditActionUpdated, debitTx, updatedDebit); err != nil {
			return err
		}
		if err := s.audit.WithQuerier(tx).Record(ctx, updatedCredit.ID, in.UserID, AuditActionUpdated, creditTx, updatedCredit); err != nil {
			return err
		}

		result = TransferWithWallets{
			DebitTransaction:  toTransactionResponse(updatedDebit),
			CreditTransaction: toTransactionResponse(updatedCredit),
			SourceWallet:      toWalletSnapshot(updatedSource),
			DestinationWallet: toWalletSnapshot(updatedDest),
		}
		return nil
	})
	if err == nil {
		s.bumpReportVersion(ctx, sourceWalletID)
		s.bumpReportVersion(ctx, destWalletID)
	}
	return result, err
}

// --- Reconciliation ----------------------------------------------------------

// Mismatch describes a wallet whose denormalized balance disagrees with
// the ledger (plan.md section 13.6). Detection only — repair is a
// separate, explicitly audited operation, never automatic.
type Mismatch struct {
	WalletID        uuid.UUID
	UserID          uuid.UUID
	StoredBalance   int64
	RecalculatedSum int64
}

// Reconcile compares every active wallet's stored balance against the sum
// of its non-deleted ledger entries.
func (s *Service) Reconcile(ctx context.Context) ([]Mismatch, error) {
	rows, err := s.db.Query(ctx, `SELECT id, user_id, current_balance_minor FROM wallets WHERE archived_at IS NULL`)
	if err != nil {
		return nil, fmt.Errorf("list wallets for reconciliation: %w", err)
	}
	defer rows.Close()

	type walletRow struct {
		id      uuid.UUID
		userID  uuid.UUID
		balance int64
	}
	var walletRows []walletRow
	for rows.Next() {
		var w walletRow
		if err := rows.Scan(&w.id, &w.userID, &w.balance); err != nil {
			return nil, fmt.Errorf("scan wallet row: %w", err)
		}
		walletRows = append(walletRows, w)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	var mismatches []Mismatch
	for _, w := range walletRows {
		sum, err := s.transactions.SumNetForWallet(ctx, w.id)
		if err != nil {
			return nil, err
		}
		if sum != w.balance {
			mismatches = append(mismatches, Mismatch{
				WalletID: w.id, UserID: w.userID, StoredBalance: w.balance, RecalculatedSum: sum,
			})
		}
	}
	return mismatches, nil
}
