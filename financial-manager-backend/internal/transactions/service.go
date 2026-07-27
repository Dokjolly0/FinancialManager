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
	ID             string  `json:"id"`
	WalletID       string  `json:"wallet_id"`
	Direction      string  `json:"direction"`
	Kind           string  `json:"kind"`
	AmountMinor    int64   `json:"amount_minor"`
	Currency       string  `json:"currency"`
	Title          string  `json:"title"`
	Description    *string `json:"description,omitempty"`
	CategoryID     *string `json:"category_id,omitempty"`
	TemplateID     *string `json:"template_id,omitempty"`
	MediaID        *string `json:"media_id,omitempty"`
	OccurredAt     string  `json:"occurred_at"`
	CreatedAt      string  `json:"created_at"`
	UpdatedAt      string  `json:"updated_at"`
	Version        int64   `json:"version"`
	TransferPairID *string `json:"transfer_pair_id,omitempty"`
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
	return transactionResponse{
		ID:             t.ID.String(),
		WalletID:       t.WalletID.String(),
		Direction:      t.Direction,
		Kind:           t.Kind,
		AmountMinor:    t.AmountMinor,
		Currency:       t.Currency,
		Title:          t.Title,
		Description:    t.Description,
		CategoryID:     categoryID,
		TemplateID:     templateID,
		MediaID:        mediaID,
		OccurredAt:     t.OccurredAt.Format(timeLayout),
		CreatedAt:      t.CreatedAt.Format(timeLayout),
		UpdatedAt:      t.UpdatedAt.Format(timeLayout),
		Version:        t.Version,
		TransferPairID: transferPairID,
	}
}

// walletSnapshot mirrors the shape of GET /v1/wallets/{id} so every
// endpoint that echoes a wallet back — create/update/delete/balance-
// adjustment/transfer here, and the wallets module's own GET — uses one
// consistent JSON shape. A partial shape here previously broke the
// Flutter client's shared Wallet.fromJson parser.
type walletSnapshot struct {
	ID                  string  `json:"id"`
	Name                string  `json:"name"`
	Currency            string  `json:"currency"`
	CurrentBalanceMinor int64   `json:"current_balance_minor"`
	Type                string  `json:"type"`
	Icon                string  `json:"icon"`
	Color               string  `json:"color"`
	Version             int64   `json:"version"`
	UpdatedAt           string  `json:"updated_at"`
	ArchivedAt          *string `json:"archived_at,omitempty"`
}

func toWalletSnapshot(w wallets.Wallet) walletSnapshot {
	var archivedAt *string
	if w.ArchivedAt != nil {
		s := w.ArchivedAt.Format(timeLayout)
		archivedAt = &s
	}
	return walletSnapshot{
		ID:                  w.ID.String(),
		Name:                w.Name,
		Currency:            w.Currency,
		CurrentBalanceMinor: w.CurrentBalanceMinor,
		Type:                w.Type,
		Icon:                w.Icon,
		Color:               w.Color,
		Version:             w.Version,
		UpdatedAt:           w.UpdatedAt.Format(timeLayout),
		ArchivedAt:          archivedAt,
	}
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

		wallet, err := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, in.WalletID, in.UserID)
		if errors.Is(err, wallets.ErrNotFound) {
			return apierror.NewValidation(map[string]string{"wallet_id": "WALLET_NOT_FOUND"})
		}
		if err != nil {
			return fmt.Errorf("lock wallet: %w", err)
		}
		walletID = wallet.ID
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
			OccurredAt: occurredAt, CreatedBySessionID: in.SessionID,
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
// transfer instead. The affected wallet is resolved from the transaction
// row itself, not a client-supplied ID, since this endpoint only takes a
// transaction id.
func (s *Service) Delete(ctx context.Context, userID, transactionID uuid.UUID) (walletSnapshot, error) {
	var result walletSnapshot
	var walletID uuid.UUID
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

		wallet, err := s.wallets.WithQuerier(tx).LockByIDForUpdate(ctx, existing.WalletID, userID)
		if err != nil {
			return fmt.Errorf("lock wallet: %w", err)
		}
		walletID = wallet.ID

		newBalance := wallet.CurrentBalanceMinor - SignedDelta(existing.Direction, existing.AmountMinor)

		if err := s.transactions.WithQuerier(tx).SoftDelete(ctx, transactionID, userID); err != nil {
			return err
		}

		updatedWallet, err := s.wallets.WithQuerier(tx).UpdateBalance(ctx, wallet.ID, newBalance, wallet.Version)
		if err != nil {
			return fmt.Errorf("update wallet balance: %w", err)
		}

		if err := s.audit.WithQuerier(tx).Record(ctx, transactionID, userID, AuditActionDeleted, existing, nil); err != nil {
			return err
		}

		result = toWalletSnapshot(updatedWallet)
		return nil
	})
	if err == nil {
		s.bumpReportVersion(ctx, walletID)
	}
	return result, err
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
}

func (s *Service) CreateWallet(ctx context.Context, in CreateWalletInput) ([]byte, int, error) {
	fieldErrors := wallets.ValidateFields(in.Name, in.Type, in.Icon, in.Color)
	if in.OpeningBalanceMinor < 0 {
		fieldErrors["opening_balance_minor"] = apierror.FieldNegativeNotAllowed
	}
	if in.IdempotencyKey == uuid.Nil {
		fieldErrors["idempotency_key"] = apierror.FieldRequired
	}
	if len(fieldErrors) > 0 {
		return nil, 0, apierror.NewValidation(fieldErrors)
	}

	now := s.clock.Now()
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

		wallet, err := s.wallets.WithQuerier(tx).Create(ctx, in.UserID, in.Name, "EUR", in.Type, in.Icon, in.Color, in.OpeningBalanceMinor)
		if err != nil {
			return fmt.Errorf("create wallet: %w", err)
		}

		// amount_minor must be > 0 per the transactions table constraint — a
		// zero opening balance is valid but simply has no OPENING_BALANCE
		// ledger row (mirrors registration's identical rule).
		if in.OpeningBalanceMinor > 0 {
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
