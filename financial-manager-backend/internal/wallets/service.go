package wallets

import (
	"context"
	"errors"
	"net/http"
	"regexp"
	"strings"

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
	ID                  string `json:"id"`
	Name                string `json:"name"`
	Currency            string `json:"currency"`
	CurrentBalanceMinor int64  `json:"current_balance_minor"`
	Type                string `json:"type"`
	Icon                string `json:"icon"`
	Color               string `json:"color"`
	Version             int64  `json:"version"`
	UpdatedAt           string `json:"updated_at"`
	ArchivedAt          *string `json:"archived_at,omitempty"`
}

const timeLayout = "2006-01-02T15:04:05Z07:00"

func toWalletResponse(w Wallet) walletResponse {
	var archivedAt *string
	if w.ArchivedAt != nil {
		s := w.ArchivedAt.Format(timeLayout)
		archivedAt = &s
	}
	return walletResponse{
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

func (s *Service) List(ctx context.Context, userID uuid.UUID) ([]walletResponse, error) {
	list, err := s.repo.ListByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]walletResponse, 0, len(list))
	for _, w := range list {
		out = append(out, toWalletResponse(w))
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
	return toWalletResponse(w), nil
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

	created, err := s.repo.Create(ctx, in.UserID, in.Name, "EUR", in.Type, in.Icon, in.Color, in.OpeningBalanceMinor)
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
}

func (s *Service) Update(ctx context.Context, in UpdateServiceInput) (walletResponse, error) {
	if fieldErrors := ValidateFields(in.Name, in.Type, in.Icon, in.Color); len(fieldErrors) > 0 {
		return walletResponse{}, apierror.NewValidation(fieldErrors)
	}

	updated, err := s.repo.Update(ctx, in.WalletID, in.UserID, UpdateInput{
		Name: in.Name, Type: in.Type, Icon: in.Icon, Color: in.Color,
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
