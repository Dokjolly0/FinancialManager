package transactions

import (
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
	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/clock"
	"financial-manager-backend/internal/platform/database"
	"financial-manager-backend/internal/platform/idempotency"
	"financial-manager-backend/internal/templates"
	"financial-manager-backend/internal/wallets"
)

const (
	createTransactionEndpoint = "POST /v1/transactions"
	balanceAdjustmentEndpoint = "POST /v1/wallet/balance-adjustments"
	idempotencyTTL            = 24 * time.Hour

	// Sanity cap against overflow/anomalous input (plan.md section 4.3),
	// not a product-meaningful limit: 10 million units in minor currency.
	maxAmountMinor = 10_000_000_00
)

type Service struct {
	db           *database.Pool
	transactions *Repository
	wallets      *wallets.Repository
	audit        *AuditRepository
	categories   *categories.Repository
	templates    *templates.Repository
	clock        clock.Clock
}

type Deps struct {
	DB           *database.Pool
	Transactions *Repository
	Wallets      *wallets.Repository
	Audit        *AuditRepository
	Categories   *categories.Repository
	Templates    *templates.Repository
	Clock        clock.Clock
}

func NewService(d Deps) *Service {
	return &Service{
		db: d.DB, transactions: d.Transactions, wallets: d.Wallets, audit: d.Audit,
		categories: d.Categories, templates: d.Templates, clock: d.Clock,
	}
}

// resolveCategoryAndTemplate validates that an optional category_id is
// visible to the user (system or owned, plan.md section 14.7) and that an
// optional template_id belongs to the user, bumping its usage stats in the
// same DB transaction as the mutation (plan.md section 4.4: "ordinati per
// frequenza e utilizzo recente"). Both checks run against tx so a
// cross-user reference rolls back the whole mutation, not just the bump.
func (s *Service) resolveCategoryAndTemplate(ctx context.Context, tx pgx.Tx, userID uuid.UUID, categoryID, templateID *uuid.UUID) error {
	if categoryID != nil {
		if _, err := s.categories.WithQuerier(tx).GetByIDAndVisibility(ctx, *categoryID, userID); err != nil {
			if errors.Is(err, categories.ErrNotFound) {
				return apierror.NewValidation(map[string]string{"category_id": "Categoria non trovata."})
			}
			return err
		}
	}
	if templateID != nil {
		if err := s.templates.WithQuerier(tx).BumpUsage(ctx, *templateID, userID); err != nil {
			if errors.Is(err, templates.ErrNotFound) {
				return apierror.NewValidation(map[string]string{"template_id": "Modello non trovato."})
			}
			return err
		}
	}
	return nil
}

// --- DTOs shared by create/update/get/list --------------------------------

type transactionResponse struct {
	ID          string  `json:"id"`
	Direction   string  `json:"direction"`
	Kind        string  `json:"kind"`
	AmountMinor int64   `json:"amount_minor"`
	Currency    string  `json:"currency"`
	Title       string  `json:"title"`
	Description *string `json:"description,omitempty"`
	CategoryID  *string `json:"category_id,omitempty"`
	TemplateID  *string `json:"template_id,omitempty"`
	OccurredAt  string  `json:"occurred_at"`
	CreatedAt   string  `json:"created_at"`
	UpdatedAt   string  `json:"updated_at"`
	Version     int64   `json:"version"`
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
	return transactionResponse{
		ID:          t.ID.String(),
		Direction:   t.Direction,
		Kind:        t.Kind,
		AmountMinor: t.AmountMinor,
		Currency:    t.Currency,
		Title:       t.Title,
		Description: t.Description,
		CategoryID:  categoryID,
		TemplateID:  templateID,
		OccurredAt:  t.OccurredAt.Format(timeLayout),
		CreatedAt:   t.CreatedAt.Format(timeLayout),
		UpdatedAt:   t.UpdatedAt.Format(timeLayout),
		Version:     t.Version,
	}
}

// walletSnapshot mirrors the shape of GET /v1/wallet (plan.md section
// 14.4) so every endpoint that echoes the wallet back — create/update/
// delete/balance-adjustment here, and the wallet module's own GET — uses
// one consistent JSON shape. A partial shape here previously broke the
// Flutter client's shared Wallet.fromJson parser.
type walletSnapshot struct {
	ID                  string `json:"id"`
	Name                string `json:"name"`
	Currency            string `json:"currency"`
	CurrentBalanceMinor int64  `json:"current_balance_minor"`
	Version             int64  `json:"version"`
	UpdatedAt           string `json:"updated_at"`
}

func toWalletSnapshot(w wallets.Wallet) walletSnapshot {
	return walletSnapshot{
		ID:                  w.ID.String(),
		Name:                w.Name,
		Currency:            w.Currency,
		CurrentBalanceMinor: w.CurrentBalanceMinor,
		Version:             w.Version,
		UpdatedAt:           w.UpdatedAt.Format(timeLayout),
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
	Direction      string
	AmountMinor    int64
	Currency       string
	Title          string
	Description    *string
	CategoryID     *uuid.UUID
	TemplateID     *uuid.UUID
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
		fieldErrors["direction"] = "Deve essere CREDIT o DEBIT."
	}
	if amountMinor <= 0 {
		fieldErrors["amount_minor"] = "Deve essere maggiore di zero."
	} else if amountMinor > maxAmountMinor {
		fieldErrors["amount_minor"] = "Importo non plausibile."
	}
	if strings.TrimSpace(title) == "" || len(title) > 120 {
		fieldErrors["title"] = "Deve avere tra 1 e 120 caratteri."
	}
	return fieldErrors
}

// CreateStandard creates a STANDARD transaction and atomically applies its
// effect to the wallet balance (plan.md section 13.2), replaying the
// original response for a retried Idempotency-Key instead of duplicating
// the mutation (section 26.2: "Doppi tap o retry non creano duplicati").
func (s *Service) CreateStandard(ctx context.Context, in CreateStandardInput) ([]byte, int, error) {
	fieldErrors := validateTransactionFields(in.Direction, in.AmountMinor, in.Title)
	if in.Currency != "EUR" {
		fieldErrors["currency"] = "Solo EUR è supportato in questa versione."
	}
	if in.IdempotencyKey == uuid.Nil {
		fieldErrors["idempotency_key"] = "Campo obbligatorio."
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
	err := s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		idemStore := idempotency.NewStore(tx)
		claimed, existing, claimErr := idemStore.Claim(ctx, in.UserID.String(), createTransactionEndpoint, in.IdempotencyKey, requestHash, idempotencyTTL)
		if claimErr != nil {
			if errors.Is(claimErr, idempotency.ErrKeyReusedWithDifferentPayload) {
				return apierror.New(http.StatusUnprocessableEntity, "IDEMPOTENCY_KEY_REUSED",
					"La chiave di idempotenza è già stata usata con dati diversi.")
			}
			return claimErr
		}
		if !claimed {
			responseBody = existing.ResponseBody
			return nil
		}

		wallet, err := s.wallets.WithQuerier(tx).LockForUpdate(ctx, in.UserID)
		if err != nil {
			return fmt.Errorf("lock wallet: %w", err)
		}
		if in.Currency != wallet.Currency {
			return apierror.NewValidation(map[string]string{"currency": "Deve corrispondere alla valuta del portafoglio."})
		}
		if err := s.resolveCategoryAndTemplate(ctx, tx, in.UserID, in.CategoryID, in.TemplateID); err != nil {
			return err
		}

		newBalance := wallet.CurrentBalanceMinor + SignedDelta(in.Direction, in.AmountMinor)

		created, err := s.transactions.WithQuerier(tx).Create(ctx, CreateInput{
			WalletID: wallet.ID, UserID: in.UserID, Direction: in.Direction, Kind: KindStandard,
			AmountMinor: in.AmountMinor, Currency: in.Currency, Title: in.Title, Description: in.Description,
			CategoryID: in.CategoryID, TemplateID: in.TemplateID,
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
	Direction       string
	AmountMinor     int64
	Title           string
	Description     *string
	CategoryID      *uuid.UUID
	TemplateID      *uuid.UUID
	OccurredAt      time.Time
	ExpectedVersion int64
}

type TransactionWithWallet struct {
	Transaction transactionResponse `json:"transaction"`
	Wallet      walletSnapshot      `json:"wallet"`
}

// UpdateStandard recomputes the wallet's balance from the *difference*
// between the old and new impact, inside the same DB transaction (plan.md
// section 13.3, 26.3).
func (s *Service) UpdateStandard(ctx context.Context, in UpdateStandardInput) (TransactionWithWallet, error) {
	if fieldErrors := validateTransactionFields(in.Direction, in.AmountMinor, in.Title); len(fieldErrors) > 0 {
		return TransactionWithWallet{}, apierror.NewValidation(fieldErrors)
	}

	occurredAt := in.OccurredAt
	if occurredAt.IsZero() {
		occurredAt = s.clock.Now()
	}

	var result TransactionWithWallet
	err := s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		wallet, err := s.wallets.WithQuerier(tx).LockForUpdate(ctx, in.UserID)
		if err != nil {
			return fmt.Errorf("lock wallet: %w", err)
		}

		existing, err := s.transactions.WithQuerier(tx).LockByIDAndUserID(ctx, in.TransactionID, in.UserID)
		if errors.Is(err, ErrNotFound) {
			return apierror.ErrNotFound
		}
		if err != nil {
			return err
		}
		if existing.Kind != KindStandard {
			return apierror.New(http.StatusForbidden, "NOT_EDITABLE",
				"Solo le operazioni standard possono essere modificate.")
		}
		if err := s.resolveCategoryAndTemplate(ctx, tx, in.UserID, in.CategoryID, in.TemplateID); err != nil {
			return err
		}

		diff := SignedDelta(in.Direction, in.AmountMinor) - SignedDelta(existing.Direction, existing.AmountMinor)
		newBalance := wallet.CurrentBalanceMinor + diff

		updated, err := s.transactions.WithQuerier(tx).Update(ctx, in.TransactionID, in.UserID, in.ExpectedVersion, UpdateInput{
			Direction: in.Direction, AmountMinor: in.AmountMinor, Title: in.Title,
			Description: in.Description, CategoryID: in.CategoryID, TemplateID: in.TemplateID, OccurredAt: occurredAt,
		})
		if errors.Is(err, ErrNotFound) {
			// Row exists but version didn't match vs. genuinely gone.
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
	return result, err
}

// --- Delete --------------------------------------------------------------------

// Delete reverses the transaction's balance impact and soft-deletes it
// (plan.md section 13.4). OPENING_BALANCE cannot be deleted this way
// (section 13.4: "non dovrebbe essere eliminabile dalla UI ordinaria").
func (s *Service) Delete(ctx context.Context, userID, transactionID uuid.UUID) (walletSnapshot, error) {
	var result walletSnapshot
	err := s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		wallet, err := s.wallets.WithQuerier(tx).LockForUpdate(ctx, userID)
		if err != nil {
			return fmt.Errorf("lock wallet: %w", err)
		}

		existing, err := s.transactions.WithQuerier(tx).LockByIDAndUserID(ctx, transactionID, userID)
		if errors.Is(err, ErrNotFound) {
			return apierror.ErrNotFound
		}
		if err != nil {
			return err
		}
		if existing.Kind == KindOpeningBalance {
			return apierror.New(http.StatusForbidden, "OPENING_BALANCE_NOT_DELETABLE",
				"Il saldo iniziale non può essere eliminato direttamente.")
		}

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
	return result, err
}

// --- Balance adjustment ----------------------------------------------------

type CreateBalanceAdjustmentInput struct {
	UserID             uuid.UUID
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
	if in.IdempotencyKey == uuid.Nil {
		return nil, 0, apierror.NewValidation(map[string]string{"idempotency_key": "Campo obbligatorio."})
	}
	if in.TargetBalanceMinor < 0 {
		return nil, 0, apierror.NewValidation(map[string]string{"target_balance_minor": "Non può essere negativo."})
	}

	occurredAt := in.OccurredAt
	if occurredAt.IsZero() {
		occurredAt = s.clock.Now()
	}
	requestHash := sha256Sum(in.RequestBody)

	var responseBody []byte
	err := s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		idemStore := idempotency.NewStore(tx)
		claimed, existing, claimErr := idemStore.Claim(ctx, in.UserID.String(), balanceAdjustmentEndpoint, in.IdempotencyKey, requestHash, idempotencyTTL)
		if claimErr != nil {
			if errors.Is(claimErr, idempotency.ErrKeyReusedWithDifferentPayload) {
				return apierror.New(http.StatusUnprocessableEntity, "IDEMPOTENCY_KEY_REUSED",
					"La chiave di idempotenza è già stata usata con dati diversi.")
			}
			return claimErr
		}
		if !claimed {
			responseBody = existing.ResponseBody
			return nil
		}

		wallet, err := s.wallets.WithQuerier(tx).LockForUpdate(ctx, in.UserID)
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
