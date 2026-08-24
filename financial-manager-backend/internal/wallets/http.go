package wallets

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/reqctx"
)

type Handler struct {
	repo    *Repository
	service *Service
}

func NewHandler(repo *Repository) *Handler {
	return &Handler{repo: repo, service: NewService(repo)}
}

// Mount registers routes that require the auth middleware to already be
// applied to r. POST /v1/wallets (creation) is mounted from
// transactions.Handler instead, since creating a wallet with a non-zero
// opening balance must also insert the matching OPENING_BALANCE ledger row
// in the same DB transaction — an orchestration transactions.Service
// already has the dependencies for (mirrors POST /v1/wallet/balance-
// adjustments living there despite being wallet-resource-shaped).
func (h *Handler) Mount(r chi.Router) {
	r.Get("/v1/wallet", h.getLegacySingleWallet)
	r.Get("/v1/wallets", h.list)
	r.Get("/v1/wallets/{id}", h.get)
	r.Patch("/v1/wallets/{id}", h.update)
	r.Post("/v1/wallets/{id}/archive", h.archive)
	r.Get("/v1/wallets/{id}/denominations", h.getDenominations)
	r.Put("/v1/wallets/{id}/denominations", h.replaceDenominations)
	r.Get("/v1/wallets/{id}/voucher-lots", h.getVoucherLots)
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

// getLegacySingleWallet preserves the pre-multi-wallet GET /v1/wallet
// shape (the user's oldest active wallet) for any caller not yet migrated
// to GET /v1/wallets.
func (h *Handler) getLegacySingleWallet(w http.ResponseWriter, r *http.Request) {
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
	writeJSON(w, http.StatusOK, toWalletResponse(wallet))
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}

	list, err := h.service.List(r.Context(), userID)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"wallets": list})
}

func (h *Handler) get(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		apierror.Write(w, r, apierror.ErrNotFound)
		return
	}

	resp, err := h.service.Get(r.Context(), userID, id)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

type walletRequest struct {
	Name  string `json:"name"`
	Type  string `json:"type"`
	Icon  string `json:"icon"`
	Color string `json:"color"`
}

type updateWalletRequest struct {
	walletRequest
	ExpectedVersion          int64 `json:"version"`
	VoucherExpiryCutoffMonth *int  `json:"voucher_expiry_cutoff_month,omitempty"`
	VoucherExpiryMonth       *int  `json:"voucher_expiry_month,omitempty"`
	VoucherExpiryDay         *int  `json:"voucher_expiry_day,omitempty"`
}

func (h *Handler) update(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		apierror.Write(w, r, apierror.ErrNotFound)
		return
	}

	var req updateWalletRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	updated, err := h.service.Update(r.Context(), UpdateServiceInput{
		UserID: userID, WalletID: id, Name: req.Name, Type: req.Type, Icon: req.Icon, Color: req.Color,
		ExpectedVersion:          req.ExpectedVersion,
		VoucherExpiryCutoffMonth: req.VoucherExpiryCutoffMonth,
		VoucherExpiryMonth:       req.VoucherExpiryMonth,
		VoucherExpiryDay:         req.VoucherExpiryDay,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, updated)
}

type archiveRequest struct {
	ExpectedVersion int64 `json:"version"`
}

func (h *Handler) archive(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		apierror.Write(w, r, apierror.ErrNotFound)
		return
	}

	var req archiveRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	archived, err := h.service.Archive(r.Context(), userID, id, req.ExpectedVersion)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, archived)
}

func (h *Handler) getDenominations(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		apierror.Write(w, r, apierror.ErrNotFound)
		return
	}

	list, err := h.service.GetDenominations(r.Context(), userID, id)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"denominations": list})
}

type denominationRequest struct {
	DenominationMinor int  `json:"denomination_minor"`
	Count             int  `json:"count"`
	Enabled           bool `json:"enabled"`
}

func (h *Handler) getVoucherLots(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		apierror.Write(w, r, apierror.ErrNotFound)
		return
	}

	list, err := h.service.GetVoucherLots(r.Context(), userID, id)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"voucher_lots": list})
}

func (h *Handler) replaceDenominations(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		apierror.Write(w, r, apierror.ErrNotFound)
		return
	}

	var req struct {
		Denominations []denominationRequest `json:"denominations"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	counts := make([]DenominationCount, len(req.Denominations))
	for i, d := range req.Denominations {
		counts[i] = DenominationCount{DenominationMinor: d.DenominationMinor, Count: d.Count, Enabled: d.Enabled}
	}

	updated, err := h.service.ReplaceDenominations(r.Context(), userID, id, counts)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"denominations": updated})
}
