package wallets

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"

	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/reqctx"
)

type Handler struct {
	repo *Repository
}

func NewHandler(repo *Repository) *Handler {
	return &Handler{repo: repo}
}

func (h *Handler) Mount(r chi.Router) {
	r.Get("/v1/wallet", h.getWallet)
}

type walletResponse struct {
	ID                  string `json:"id"`
	Name                string `json:"name"`
	Currency            string `json:"currency"`
	CurrentBalanceMinor int64  `json:"current_balance_minor"`
	Version             int64  `json:"version"`
	UpdatedAt           string `json:"updated_at"`
}

func (h *Handler) getWallet(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}

	wallet, err := h.repo.GetByUserID(r.Context(), userID)
	if errors.Is(err, ErrNotFound) {
		apierror.Write(w, r, apierror.ErrNotFound)
		return
	}
	if err != nil {
		apierror.Write(w, r, err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(walletResponse{
		ID:                  wallet.ID.String(),
		Name:                wallet.Name,
		Currency:            wallet.Currency,
		CurrentBalanceMinor: wallet.CurrentBalanceMinor,
		Version:             wallet.Version,
		UpdatedAt:           wallet.UpdatedAt.Format("2006-01-02T15:04:05Z07:00"),
	})
}
