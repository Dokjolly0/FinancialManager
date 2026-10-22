package transactions_test

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"github.com/google/uuid"

	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/transactions"
	"financial-manager-backend/internal/wallets"
)

// Wallet purpose (migration 0030) round-trips through creation (which lives
// in transactions.Service) and through wallets.Service.Update, where an
// omitted purpose clears it like every other replaced field.
func TestWalletPurpose_CreateUpdateClear(t *testing.T) {
	h := newHarness(t, 0)
	ctx := context.Background()
	purpose := "  Spese quotidiane e spesa al supermercato  "

	body, status, err := h.service.CreateWallet(ctx, transactions.CreateWalletInput{
		UserID: h.userID, Name: "Conto spese", Type: wallets.TypeBank, Icon: "bank", Color: "#6750A4",
		Purpose: &purpose, IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	if err != nil {
		t.Fatalf("CreateWallet() error = %v", err)
	}
	if status != 201 {
		t.Fatalf("status = %d, want 201", status)
	}
	var decoded struct {
		Wallet struct {
			ID      string  `json:"id"`
			Purpose *string `json:"purpose"`
			Version int64   `json:"version"`
		} `json:"wallet"`
	}
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if decoded.Wallet.Purpose == nil || *decoded.Wallet.Purpose != "Spese quotidiane e spesa al supermercato" {
		t.Fatalf("created purpose = %v, want trimmed text", decoded.Wallet.Purpose)
	}

	walletID := uuid.MustParse(decoded.Wallet.ID)
	stored, err := h.wallets.GetByID(ctx, walletID, h.userID)
	if err != nil {
		t.Fatalf("GetByID: %v", err)
	}
	if stored.Purpose == nil || *stored.Purpose != "Spese quotidiane e spesa al supermercato" {
		t.Fatalf("stored purpose = %v", stored.Purpose)
	}

	walletService := wallets.NewService(h.wallets)
	newPurpose := "Fondo emergenze"
	updated, err := walletService.Update(ctx, wallets.UpdateServiceInput{
		UserID: h.userID, WalletID: walletID, Name: "Conto spese", Type: wallets.TypeBank, Icon: "bank",
		Color: "#6750A4", Purpose: &newPurpose, ExpectedVersion: stored.Version,
	})
	if err != nil {
		t.Fatalf("Update(purpose) error = %v", err)
	}
	if after, _ := h.wallets.GetByID(ctx, walletID, h.userID); after.Purpose == nil || *after.Purpose != newPurpose {
		t.Fatalf("purpose after update = %v, want %q", after.Purpose, newPurpose)
	}

	if _, err := walletService.Update(ctx, wallets.UpdateServiceInput{
		UserID: h.userID, WalletID: walletID, Name: "Conto spese", Type: wallets.TypeBank, Icon: "bank",
		Color: "#6750A4", ExpectedVersion: updated.Version,
	}); err != nil {
		t.Fatalf("Update(no purpose) error = %v", err)
	}
	if after, _ := h.wallets.GetByID(ctx, walletID, h.userID); after.Purpose != nil {
		t.Fatalf("purpose after clearing = %q, want nil", *after.Purpose)
	}
}

func TestWalletPurpose_TooLongRejected(t *testing.T) {
	h := newHarness(t, 0)
	long := make([]rune, wallets.MaxPurposeLength+1)
	for i := range long {
		long[i] = 'x'
	}
	purpose := string(long)

	_, _, err := h.service.CreateWallet(context.Background(), transactions.CreateWalletInput{
		UserID: h.userID, Name: "Troppo", Type: wallets.TypeOther, Icon: "wallet", Color: "#6750A4",
		Purpose: &purpose, IdempotencyKey: uuid.New(), RequestBody: []byte("{}"),
	})
	var apiErr *apierror.Error
	if !errors.As(err, &apiErr) || apiErr.FieldErrors["purpose"] != apierror.FieldPurposeLength {
		t.Fatalf("CreateWallet() error = %v, want validation purpose=%s", err, apierror.FieldPurposeLength)
	}
}
