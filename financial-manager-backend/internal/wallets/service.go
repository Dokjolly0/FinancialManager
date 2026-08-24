package wallets

import (
	"context"
	"errors"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/platform/apierror"
)

var hexColorPattern = regexp.MustCompile(`^#[0-9A-Fa-f]{6}$`)

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

type walletResponse struct {
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
	// VoucherExpiringSoonCount is the number of active voucher lots
	// expiring within 30 days — nil (omitted) for non-MEAL_VOUCHER wallets.
	// Populated by List/Get, which need a Repository call per wallet; left
	// nil by any code path (e.g. transactions.Service's walletSnapshot)
	// that only echoes a wallet back after a mutation, where the extra
	// query isn't worth it.
	VoucherExpiringSoonCount *int `json:"voucher_expiring_soon_count,omitempty"`
}

const timeLayout = "2006-01-02T15:04:05Z07:00"

// voucherExpiringSoonWindow is the fixed lookahead for the "expiring soon"
// badge — not configurable per wallet, unlike the expiry policy itself
// (plan.md section 4.2).
const voucherExpiringSoonWindowDays = 30

func toWalletResponse(w Wallet) walletResponse {
	var archivedAt *string
	if w.ArchivedAt != nil {
		s := w.ArchivedAt.Format(timeLayout)
		archivedAt = &s
	}
	return walletResponse{
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

// ValidateFields is shared by this service and transactions.Service.CreateWallet
// (which needs the same checks before its cross-module opening-balance
// orchestration).
func ValidateFields(name, walletType, icon, color string) map[string]string {
	fieldErrors := map[string]string{}
	if strings.TrimSpace(name) == "" || len(name) > 80 {
		fieldErrors["name"] = apierror.FieldCategoryNameLength
	}
	if !IsValidType(walletType) {
		fieldErrors["type"] = "INVALID_WALLET_TYPE"
	}
	if !IsValidIcon(icon) {
		fieldErrors["icon"] = "INVALID_WALLET_ICON"
	}
	if !hexColorPattern.MatchString(color) {
		fieldErrors["color"] = apierror.FieldInvalidColorFormat
	}
	return fieldErrors
}

// ValidateVoucherUnitValue enforces that a MEAL_VOUCHER wallet has a
// positive face value, and that no other wallet type carries one — checked
// only at creation, since the field is immutable afterwards (Update never
// accepts it).
func ValidateVoucherUnitValue(walletType string, unitValueMinor *int64) map[string]string {
	fieldErrors := map[string]string{}
	if walletType == TypeMealVoucher {
		if unitValueMinor == nil || *unitValueMinor <= 0 {
			fieldErrors["voucher_unit_value_minor"] = apierror.FieldRequired
		}
	} else if unitValueMinor != nil {
		fieldErrors["voucher_unit_value_minor"] = apierror.FieldNotAllowedForWalletType
	}
	return fieldErrors
}

// ValidateVoucherExpiryFields enforces that a MEAL_VOUCHER wallet always
// carries a complete, in-range expiry policy, and that no other wallet type
// carries one. Shared by wallet creation and by Update, since — unlike the
// unit value — the policy stays editable for the life of the wallet.
func ValidateVoucherExpiryFields(walletType string, cutoffMonth, expiryMonth, expiryDay *int) map[string]string {
	fieldErrors := map[string]string{}
	if walletType != TypeMealVoucher {
		if cutoffMonth != nil || expiryMonth != nil || expiryDay != nil {
			fieldErrors["voucher_expiry_cutoff_month"] = apierror.FieldNotAllowedForWalletType
		}
		return fieldErrors
	}
	if cutoffMonth == nil || *cutoffMonth < 1 || *cutoffMonth > 12 {
		fieldErrors["voucher_expiry_cutoff_month"] = apierror.FieldInvalidMonth
	}
	if expiryMonth == nil || *expiryMonth < 1 || *expiryMonth > 12 {
		fieldErrors["voucher_expiry_month"] = apierror.FieldInvalidMonth
	}
	if expiryDay == nil || *expiryDay < 1 || *expiryDay > 31 {
		fieldErrors["voucher_expiry_day"] = apierror.FieldInvalidDay
	}
	return fieldErrors
}

// withVoucherExpiringSoonCount fills VoucherExpiringSoonCount for a
// MEAL_VOUCHER wallet response — a no-op for every other type.
func (s *Service) withVoucherExpiringSoonCount(ctx context.Context, w Wallet, resp walletResponse) (walletResponse, error) {
	if w.Type != TypeMealVoucher {
		return resp, nil
	}
	threshold := time.Now().UTC().AddDate(0, 0, voucherExpiringSoonWindowDays)
	count, err := s.repo.CountLotsExpiringBy(ctx, w.ID, threshold)
	if err != nil {
		return walletResponse{}, err
	}
	resp.VoucherExpiringSoonCount = &count
	return resp, nil
}

func (s *Service) List(ctx context.Context, userID uuid.UUID) ([]walletResponse, error) {
	list, err := s.repo.ListByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]walletResponse, 0, len(list))
	for _, w := range list {
		resp, err := s.withVoucherExpiringSoonCount(ctx, w, toWalletResponse(w))
		if err != nil {
			return nil, err
		}
		out = append(out, resp)
	}
	return out, nil
}

func (s *Service) Get(ctx context.Context, userID, walletID uuid.UUID) (walletResponse, error) {
	w, err := s.repo.GetByID(ctx, walletID, userID)
	if errors.Is(err, ErrNotFound) {
		return walletResponse{}, apierror.ErrNotFound
	}
	if err != nil {
		return walletResponse{}, err
	}
	return s.withVoucherExpiringSoonCount(ctx, w, toWalletResponse(w))
}

type CreateInput struct {
	UserID              uuid.UUID
	Name                string
	Type                string
	Icon                string
	Color               string
	OpeningBalanceMinor int64
}

func (s *Service) Create(ctx context.Context, in CreateInput) (walletResponse, error) {
	if fieldErrors := ValidateFields(in.Name, in.Type, in.Icon, in.Color); len(fieldErrors) > 0 {
		return walletResponse{}, apierror.NewValidation(fieldErrors)
	}
	if in.OpeningBalanceMinor < 0 {
		return walletResponse{}, apierror.NewValidation(map[string]string{"opening_balance_minor": apierror.FieldNegativeNotAllowed})
	}

	created, err := s.repo.Create(ctx, CreateRowInput{
		UserID: in.UserID, Name: in.Name, Currency: "EUR", Type: in.Type, Icon: in.Icon, Color: in.Color,
		OpeningBalanceMinor: in.OpeningBalanceMinor,
	})
	if err != nil {
		return walletResponse{}, err
	}
	return toWalletResponse(created), nil
}

type UpdateServiceInput struct {
	UserID          uuid.UUID
	WalletID        uuid.UUID
	Name            string
	Type            string
	Icon            string
	Color           string
	ExpectedVersion int64

	// Only meaningful when Type == TypeMealVoucher — see
	// ValidateVoucherExpiryFields. Never used to set the face value, which
	// is immutable (there is no VoucherUnitValueMinor field here).
	VoucherExpiryCutoffMonth *int
	VoucherExpiryMonth       *int
	VoucherExpiryDay         *int
}

func (s *Service) Update(ctx context.Context, in UpdateServiceInput) (walletResponse, error) {
	fieldErrors := ValidateFields(in.Name, in.Type, in.Icon, in.Color)
	for k, v := range ValidateVoucherExpiryFields(in.Type, in.VoucherExpiryCutoffMonth, in.VoucherExpiryMonth, in.VoucherExpiryDay) {
		fieldErrors[k] = v
	}
	if len(fieldErrors) > 0 {
		return walletResponse{}, apierror.NewValidation(fieldErrors)
	}

	existing, err := s.repo.GetByID(ctx, in.WalletID, in.UserID)
	if errors.Is(err, ErrNotFound) {
		return walletResponse{}, apierror.ErrNotFound
	}
	if err != nil {
		return walletResponse{}, err
	}
	// The wallet type can freely change among CASH/BANK/OTHER, but never
	// into or out of MEAL_VOUCHER: that would strand voucher_unit_value_minor
	// (which Update never sets) against a mismatched type, or silently turn
	// a free-form wallet into one the voucher machinery doesn't recognize.
	if (existing.Type == TypeMealVoucher) != (in.Type == TypeMealVoucher) {
		return walletResponse{}, apierror.NewValidation(map[string]string{"type": apierror.FieldNotAllowedForWalletType})
	}

	updated, err := s.repo.Update(ctx, in.WalletID, in.UserID, UpdateInput{
		Name: in.Name, Type: in.Type, Icon: in.Icon, Color: in.Color,
		VoucherExpiryCutoffMonth: in.VoucherExpiryCutoffMonth,
		VoucherExpiryMonth:       in.VoucherExpiryMonth,
		VoucherExpiryDay:         in.VoucherExpiryDay,
	}, in.ExpectedVersion)
	if errors.Is(err, ErrNotFound) {
		// Row exists but version didn't match vs. genuinely gone/not owned.
		if _, getErr := s.repo.GetByID(ctx, in.WalletID, in.UserID); getErr == nil {
			return walletResponse{}, apierror.ErrConflict
		}
		return walletResponse{}, apierror.ErrNotFound
	}
	if err != nil {
		return walletResponse{}, err
	}
	return toWalletResponse(updated), nil
}

func (s *Service) Archive(ctx context.Context, userID, walletID uuid.UUID, expectedVersion int64) (walletResponse, error) {
	archived, err := s.repo.Archive(ctx, walletID, userID, expectedVersion)
	if errors.Is(err, ErrNotFound) {
		if _, getErr := s.repo.GetByID(ctx, walletID, userID); getErr == nil {
			return walletResponse{}, apierror.ErrConflict
		}
		return walletResponse{}, apierror.ErrNotFound
	}
	if err != nil {
		return walletResponse{}, err
	}
	return toWalletResponse(archived), nil
}

// --- Cash denominations ------------------------------------------------

type denominationResponse struct {
	DenominationMinor int  `json:"denomination_minor"`
	Count             int  `json:"count"`
	Enabled           bool `json:"enabled"`
}

func toDenominationResponse(d DenominationCount) denominationResponse {
	return denominationResponse{DenominationMinor: d.DenominationMinor, Count: d.Count, Enabled: d.Enabled}
}

// requireCashWallet loads and ownership-checks the wallet, and rejects
// denomination access for non-CASH wallets — a light guardrail against
// accidentally attaching a cash breakdown to a bank/other wallet, not a
// hard architectural requirement (the table has no such constraint).
func (s *Service) requireCashWallet(ctx context.Context, userID, walletID uuid.UUID) (Wallet, error) {
	w, err := s.repo.GetByID(ctx, walletID, userID)
	if errors.Is(err, ErrNotFound) {
		return Wallet{}, apierror.ErrNotFound
	}
	if err != nil {
		return Wallet{}, err
	}
	if w.Type != TypeCash {
		return Wallet{}, apierror.New(http.StatusForbidden, "WALLET_NOT_CASH", "Denominations are only available for cash wallets.")
	}
	return w, nil
}

func (s *Service) GetDenominations(ctx context.Context, userID, walletID uuid.UUID) ([]denominationResponse, error) {
	if _, err := s.requireCashWallet(ctx, userID, walletID); err != nil {
		return nil, err
	}
	list, err := s.repo.GetDenominations(ctx, walletID)
	if err != nil {
		return nil, err
	}
	out := make([]denominationResponse, 0, len(list))
	for _, d := range list {
		out = append(out, toDenominationResponse(d))
	}
	return out, nil
}

// requireMealVoucherWallet loads and ownership-checks the wallet, and
// rejects voucher-lot access for non-MEAL_VOUCHER wallets — mirrors
// requireCashWallet.
func (s *Service) requireMealVoucherWallet(ctx context.Context, userID, walletID uuid.UUID) (Wallet, error) {
	w, err := s.repo.GetByID(ctx, walletID, userID)
	if errors.Is(err, ErrNotFound) {
		return Wallet{}, apierror.ErrNotFound
	}
	if err != nil {
		return Wallet{}, err
	}
	if w.Type != TypeMealVoucher {
		return Wallet{}, apierror.New(http.StatusForbidden, "WALLET_NOT_MEAL_VOUCHER", "Voucher lots are only available for meal-voucher wallets.")
	}
	return w, nil
}

type voucherLotResponse struct {
	ID                 string `json:"id"`
	QuantityTotal      int    `json:"quantity_total"`
	QuantityRemaining  int    `json:"quantity_remaining"`
	QuantityExpired    int    `json:"quantity_expired"`
	ExpiresAt          string `json:"expires_at"`
	CreatedByTxID      string `json:"created_by_transaction_id"`
	ExpiredByTxID      *string `json:"expired_by_transaction_id,omitempty"`
	CreatedAt          string `json:"created_at"`
}

const dateLayout = "2006-01-02"

func toVoucherLotResponse(l VoucherLot) voucherLotResponse {
	var expiredByTxID *string
	if l.ExpiredByTransactionID != nil {
		s := l.ExpiredByTransactionID.String()
		expiredByTxID = &s
	}
	return voucherLotResponse{
		ID:                l.ID.String(),
		QuantityTotal:     l.QuantityTotal,
		QuantityRemaining: l.QuantityRemaining,
		QuantityExpired:   l.QuantityExpired,
		ExpiresAt:         l.ExpiresAt.Format(dateLayout),
		CreatedByTxID:     l.CreatedByTransactionID.String(),
		ExpiredByTxID:     expiredByTxID,
		CreatedAt:         l.CreatedAt.Format(timeLayout),
	}
}

// GetVoucherLots returns every lot for the wallet (active and expired
// history) — the client buckets them into active/expiring-soon/expired
// (plan.md section 11.9).
func (s *Service) GetVoucherLots(ctx context.Context, userID, walletID uuid.UUID) ([]voucherLotResponse, error) {
	if _, err := s.requireMealVoucherWallet(ctx, userID, walletID); err != nil {
		return nil, err
	}
	list, err := s.repo.ListLots(ctx, walletID)
	if err != nil {
		return nil, err
	}
	out := make([]voucherLotResponse, 0, len(list))
	for _, l := range list {
		out = append(out, toVoucherLotResponse(l))
	}
	return out, nil
}

func (s *Service) ReplaceDenominations(ctx context.Context, userID, walletID uuid.UUID, counts []DenominationCount) ([]denominationResponse, error) {
	if _, err := s.requireCashWallet(ctx, userID, walletID); err != nil {
		return nil, err
	}
	for _, c := range counts {
		if !IsValidDenomination(c.DenominationMinor) {
			return nil, apierror.NewValidation(map[string]string{"denomination_minor": "INVALID_DENOMINATION"})
		}
		if c.Count < 0 {
			return nil, apierror.NewValidation(map[string]string{"count": apierror.FieldNegativeNotAllowed})
		}
	}

	if err := s.repo.ReplaceDenominations(ctx, walletID, counts); err != nil {
		return nil, err
	}
	return s.GetDenominations(ctx, userID, walletID)
}
