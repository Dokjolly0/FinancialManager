package transactions

import (
	"encoding/json"
	"io"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/reqctx"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// Mount registers routes that require the auth middleware to already be
// applied to r (plan.md section 19.1: every ID is resolved against the
// authenticated user, never trusted from the client).
func (h *Handler) Mount(r chi.Router) {
	r.Post("/v1/transactions", h.create)
	r.Get("/v1/transactions", h.list)
	r.Get("/v1/transactions/payment-groups", h.listPaymentGroups)
	r.Get("/v1/transactions/{id}", h.get)
	r.Patch("/v1/transactions/{id}", h.update)
	r.Patch("/v1/transactions/{id}/opening-balance", h.updateOpeningBalance)
	r.Patch("/v1/transactions/{id}/transfer", h.updateTransfer)
	r.Delete("/v1/transactions/{id}", h.delete)
	r.Delete("/v1/transactions/{id}/payment-group-link", h.unlinkPaymentGroup)
	r.Post("/v1/wallets", h.createWallet)
	r.Post("/v1/wallets/{id}/balance-adjustments", h.createBalanceAdjustment)
	r.Post("/v1/transfers", h.createTransfer)
	r.Post("/v1/wallets/{id}/voucher-credits", h.createVoucherCredit)
	r.Patch("/v1/wallets/{id}/voucher-credits/{creditId}", h.updateVoucherCredit)
	r.Post("/v1/voucher-expenses", h.createVoucherExpense)
	r.Patch("/v1/voucher-expenses/{id}", h.updateVoucherExpense)
}

// requireWalletID parses a required wallet_id-shaped field, distinguishing
// "missing" from "malformed" so the client gets the more specific error.
func requireWalletID(raw string) (uuid.UUID, *apierror.Error) {
	if raw == "" {
		return uuid.Nil, apierror.NewValidation(map[string]string{"wallet_id": apierror.FieldRequired})
	}
	id, err := uuid.Parse(raw)
	if err != nil {
		return uuid.Nil, apierror.NewValidation(map[string]string{"wallet_id": apierror.FieldInvalidUUID})
	}
	return id, nil
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

func parseOccurredAt(raw string) (time.Time, bool) {
	if raw == "" {
		return time.Time{}, true
	}
	t, err := time.Parse(time.RFC3339, raw)
	return t, err == nil
}

// parseOptionalUUID lets category_id/template_id be omitted or "" for "no
// category/template", while still rejecting a malformed non-empty value.
func parseOptionalUUID(raw string) (*uuid.UUID, bool) {
	if raw == "" {
		return nil, true
	}
	id, err := uuid.Parse(raw)
	if err != nil {
		return nil, false
	}
	return &id, true
}

type createRequest struct {
	WalletID            string  `json:"wallet_id"`
	Direction           string  `json:"direction"`
	AmountMinor         int64   `json:"amount_minor"`
	Currency            string  `json:"currency"`
	Title               string  `json:"title"`
	Description         *string `json:"description"`
	CategoryID          string  `json:"category_id"`
	TemplateID          string  `json:"template_id"`
	MediaID             string  `json:"media_id"`
	OccurredAt          string  `json:"occurred_at"`
	LinkToTransactionID string  `json:"link_to_transaction_id"`
	DeviceSession       string  `json:"-"`
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}
	sessionID, _ := reqctx.SessionID(r.Context())

	idempotencyKey, err := uuid.Parse(r.Header.Get("Idempotency-Key"))
	if err != nil {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{
			"Idempotency-Key": apierror.FieldInvalidUUID,
		}))
		return
	}

	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<16))
	if err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	var req createRequest
	if err := json.Unmarshal(body, &req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	occurredAt, ok := parseOccurredAt(req.OccurredAt)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{
			"occurred_at": apierror.FieldInvalidRFC3339Date,
		}))
		return
	}
	walletID, walletErr := requireWalletID(req.WalletID)
	if walletErr != nil {
		apierror.Write(w, r, walletErr)
		return
	}
	categoryID, ok := parseOptionalUUID(req.CategoryID)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{"category_id": apierror.FieldInvalidUUID}))
		return
	}
	templateID, ok := parseOptionalUUID(req.TemplateID)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{"template_id": apierror.FieldInvalidUUID}))
		return
	}
	mediaID, ok := parseOptionalUUID(req.MediaID)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{"media_id": apierror.FieldInvalidUUID}))
		return
	}
	linkToTransactionID, ok := parseOptionalUUID(req.LinkToTransactionID)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{"link_to_transaction_id": apierror.FieldInvalidUUID}))
		return
	}

	responseBody, status, err := h.service.CreateStandard(r.Context(), CreateStandardInput{
		UserID:              userID,
		WalletID:            walletID,
		Direction:           req.Direction,
		AmountMinor:         req.AmountMinor,
		Currency:            req.Currency,
		Title:               req.Title,
		Description:         req.Description,
		CategoryID:          categoryID,
		TemplateID:          templateID,
		MediaID:             mediaID,
		OccurredAt:          occurredAt,
		SessionID:           &sessionID,
		IdempotencyKey:      idempotencyKey,
		RequestBody:         body,
		LinkToTransactionID: linkToTransactionID,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = w.Write(responseBody)
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

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}

	query := r.URL.Query()
	limit := 20
	if raw := query.Get("limit"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil {
			limit = parsed
		}
	}

	direction := query.Get("direction")
	if direction != "" && !isValidDirection(direction) {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{"direction": apierror.FieldInvalidDirection}))
		return
	}

	var categoryID uuid.UUID
	if raw := query.Get("category_id"); raw != "" {
		parsed, err := uuid.Parse(raw)
		if err != nil {
			apierror.Write(w, r, apierror.NewValidation(map[string]string{"category_id": apierror.FieldInvalidUUID}))
			return
		}
		categoryID = parsed
	}

	var walletID uuid.UUID
	if raw := query.Get("wallet_id"); raw != "" {
		parsed, err := uuid.Parse(raw)
		if err != nil {
			apierror.Write(w, r, apierror.NewValidation(map[string]string{"wallet_id": apierror.FieldInvalidUUID}))
			return
		}
		walletID = parsed
	}

	var paymentGroupID uuid.UUID
	if raw := query.Get("payment_group_id"); raw != "" {
		parsed, err := uuid.Parse(raw)
		if err != nil {
			apierror.Write(w, r, apierror.NewValidation(map[string]string{"payment_group_id": apierror.FieldInvalidUUID}))
			return
		}
		paymentGroupID = parsed
	}

	var amountMin, amountMax int64
	if raw := query.Get("amount_min_minor"); raw != "" {
		parsed, err := strconv.ParseInt(raw, 10, 64)
		if err != nil {
			apierror.Write(w, r, apierror.NewValidation(map[string]string{"amount_min_minor": apierror.FieldMustBeInteger}))
			return
		}
		amountMin = parsed
	}
	if raw := query.Get("amount_max_minor"); raw != "" {
		parsed, err := strconv.ParseInt(raw, 10, 64)
		if err != nil {
			apierror.Write(w, r, apierror.NewValidation(map[string]string{"amount_max_minor": apierror.FieldMustBeInteger}))
			return
		}
		amountMax = parsed
	}

	var occurredFrom, occurredTo time.Time
	if raw := query.Get("occurred_from"); raw != "" {
		parsed, ok := parseOccurredAt(raw)
		if !ok {
			apierror.Write(w, r, apierror.NewValidation(map[string]string{"occurred_from": apierror.FieldInvalidRFC3339Date}))
			return
		}
		occurredFrom = parsed
	}
	if raw := query.Get("occurred_to"); raw != "" {
		parsed, ok := parseOccurredAt(raw)
		if !ok {
			apierror.Write(w, r, apierror.NewValidation(map[string]string{"occurred_to": apierror.FieldInvalidRFC3339Date}))
			return
		}
		occurredTo = parsed
	}

	result, err := h.service.List(r.Context(), ListFilter{
		UserID:         userID,
		WalletID:       walletID,
		Direction:      direction,
		Kind:           query.Get("kind"),
		CategoryID:     categoryID,
		Title:          query.Get("title"),
		AmountMinMinor: amountMin,
		AmountMaxMinor: amountMax,
		OccurredFrom:   occurredFrom,
		OccurredTo:     occurredTo,
		PaymentGroupID: paymentGroupID,
		Limit:          limit,
		Cursor:         query.Get("cursor"),
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (h *Handler) listPaymentGroups(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}

	result, err := h.service.ListPaymentGroups(r.Context(), userID)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"payment_groups": result})
}

func (h *Handler) unlinkPaymentGroup(w http.ResponseWriter, r *http.Request) {
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

	result, err := h.service.UnlinkPaymentGroup(r.Context(), userID, id)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

type updateRequest struct {
	WalletID        string  `json:"wallet_id"`
	Direction       string  `json:"direction"`
	AmountMinor     int64   `json:"amount_minor"`
	Title           string  `json:"title"`
	Description     *string `json:"description"`
	CategoryID      string  `json:"category_id"`
	TemplateID      string  `json:"template_id"`
	MediaID         string  `json:"media_id"`
	OccurredAt      string  `json:"occurred_at"`
	ExpectedVersion int64   `json:"version"`
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

	var req updateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	occurredAt, ok := parseOccurredAt(req.OccurredAt)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{
			"occurred_at": apierror.FieldInvalidRFC3339Date,
		}))
		return
	}
	walletID, walletErr := requireWalletID(req.WalletID)
	if walletErr != nil {
		apierror.Write(w, r, walletErr)
		return
	}
	categoryID, ok := parseOptionalUUID(req.CategoryID)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{"category_id": apierror.FieldInvalidUUID}))
		return
	}
	templateID, ok := parseOptionalUUID(req.TemplateID)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{"template_id": apierror.FieldInvalidUUID}))
		return
	}
	mediaID, ok := parseOptionalUUID(req.MediaID)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{"media_id": apierror.FieldInvalidUUID}))
		return
	}

	result, err := h.service.UpdateStandard(r.Context(), UpdateStandardInput{
		UserID:          userID,
		TransactionID:   id,
		WalletID:        walletID,
		Direction:       req.Direction,
		AmountMinor:     req.AmountMinor,
		Title:           req.Title,
		Description:     req.Description,
		CategoryID:      categoryID,
		TemplateID:      templateID,
		MediaID:         mediaID,
		OccurredAt:      occurredAt,
		ExpectedVersion: req.ExpectedVersion,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

type updateOpeningBalanceRequest struct {
	AmountMinor     int64  `json:"amount_minor"`
	OccurredAt      string `json:"occurred_at"`
	ExpectedVersion int64  `json:"version"`
}

func (h *Handler) updateOpeningBalance(w http.ResponseWriter, r *http.Request) {
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

	var req updateOpeningBalanceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	occurredAt, ok := parseOccurredAt(req.OccurredAt)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{
			"occurred_at": apierror.FieldInvalidRFC3339Date,
		}))
		return
	}

	result, err := h.service.UpdateOpeningBalance(r.Context(), UpdateOpeningBalanceInput{
		UserID:          userID,
		TransactionID:   id,
		AmountMinor:     req.AmountMinor,
		OccurredAt:      occurredAt,
		ExpectedVersion: req.ExpectedVersion,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

type updateTransferRequest struct {
	AmountMinor     int64  `json:"amount_minor"`
	OccurredAt      string `json:"occurred_at"`
	ExpectedVersion int64  `json:"version"`
}

func (h *Handler) updateTransfer(w http.ResponseWriter, r *http.Request) {
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

	var req updateTransferRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	occurredAt, ok := parseOccurredAt(req.OccurredAt)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{
			"occurred_at": apierror.FieldInvalidRFC3339Date,
		}))
		return
	}

	result, err := h.service.UpdateTransfer(r.Context(), UpdateTransferInput{
		UserID:          userID,
		TransactionID:   id,
		AmountMinor:     req.AmountMinor,
		OccurredAt:      occurredAt,
		ExpectedVersion: req.ExpectedVersion,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (h *Handler) delete(w http.ResponseWriter, r *http.Request) {
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

	wallet, err := h.service.Delete(r.Context(), userID, id)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"wallet": wallet})
}

type balanceAdjustmentRequest struct {
	TargetBalanceMinor int64  `json:"target_balance_minor"`
	Reason             string `json:"reason"`
	OccurredAt         string `json:"occurred_at"`
}

func (h *Handler) createBalanceAdjustment(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}
	sessionID, _ := reqctx.SessionID(r.Context())

	walletID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		apierror.Write(w, r, apierror.ErrNotFound)
		return
	}

	idempotencyKey, err := uuid.Parse(r.Header.Get("Idempotency-Key"))
	if err != nil {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{
			"Idempotency-Key": apierror.FieldInvalidUUID,
		}))
		return
	}

	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<16))
	if err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	var req balanceAdjustmentRequest
	if err := json.Unmarshal(body, &req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	occurredAt, ok := parseOccurredAt(req.OccurredAt)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{
			"occurred_at": apierror.FieldInvalidRFC3339Date,
		}))
		return
	}

	responseBody, status, err := h.service.CreateBalanceAdjustment(r.Context(), CreateBalanceAdjustmentInput{
		UserID:             userID,
		WalletID:           walletID,
		TargetBalanceMinor: req.TargetBalanceMinor,
		Reason:             req.Reason,
		OccurredAt:         occurredAt,
		SessionID:          &sessionID,
		IdempotencyKey:     idempotencyKey,
		RequestBody:        body,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = w.Write(responseBody)
}

type createWalletRequest struct {
	Name                string `json:"name"`
	Type                string `json:"type"`
	Icon                string `json:"icon"`
	Color               string `json:"color"`
	OpeningBalanceMinor int64  `json:"opening_balance_minor"`

	// Only meaningful when Type == "MEAL_VOUCHER".
	VoucherUnitValueMinor    *int64 `json:"voucher_unit_value_minor,omitempty"`
	VoucherExpiryCutoffMonth *int   `json:"voucher_expiry_cutoff_month,omitempty"`
	VoucherExpiryMonth       *int   `json:"voucher_expiry_month,omitempty"`
	VoucherExpiryDay         *int   `json:"voucher_expiry_day,omitempty"`
	InitialVoucherQuantity   int    `json:"initial_voucher_quantity"`
	VoucherLoadedAt          string `json:"voucher_loaded_at"`
}

func (h *Handler) createWallet(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}
	sessionID, _ := reqctx.SessionID(r.Context())

	idempotencyKey, err := uuid.Parse(r.Header.Get("Idempotency-Key"))
	if err != nil {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{
			"Idempotency-Key": apierror.FieldInvalidUUID,
		}))
		return
	}

	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<16))
	if err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	var req createWalletRequest
	if err := json.Unmarshal(body, &req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	voucherLoadedAt, ok := parseOccurredAt(req.VoucherLoadedAt)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{
			"voucher_loaded_at": apierror.FieldInvalidRFC3339Date,
		}))
		return
	}

	responseBody, status, err := h.service.CreateWallet(r.Context(), CreateWalletInput{
		UserID:              userID,
		Name:                req.Name,
		Type:                req.Type,
		Icon:                req.Icon,
		Color:               req.Color,
		OpeningBalanceMinor: req.OpeningBalanceMinor,
		SessionID:           &sessionID,
		IdempotencyKey:      idempotencyKey,
		RequestBody:         body,

		VoucherUnitValueMinor:    req.VoucherUnitValueMinor,
		VoucherExpiryCutoffMonth: req.VoucherExpiryCutoffMonth,
		VoucherExpiryMonth:       req.VoucherExpiryMonth,
		VoucherExpiryDay:         req.VoucherExpiryDay,
		InitialVoucherQuantity:   req.InitialVoucherQuantity,
		VoucherLoadedAt:          voucherLoadedAt,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = w.Write(responseBody)
}

type createTransferRequest struct {
	SourceWalletID      string  `json:"source_wallet_id"`
	DestinationWalletID string  `json:"destination_wallet_id"`
	AmountMinor         int64   `json:"amount_minor"`
	Note                *string `json:"note"`
	OccurredAt          string  `json:"occurred_at"`
}

func (h *Handler) createTransfer(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}
	sessionID, _ := reqctx.SessionID(r.Context())

	idempotencyKey, err := uuid.Parse(r.Header.Get("Idempotency-Key"))
	if err != nil {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{
			"Idempotency-Key": apierror.FieldInvalidUUID,
		}))
		return
	}

	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<16))
	if err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	var req createTransferRequest
	if err := json.Unmarshal(body, &req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	occurredAt, ok := parseOccurredAt(req.OccurredAt)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{
			"occurred_at": apierror.FieldInvalidRFC3339Date,
		}))
		return
	}

	var sourceWalletID, destWalletID uuid.UUID
	if req.SourceWalletID != "" {
		sourceWalletID, err = uuid.Parse(req.SourceWalletID)
		if err != nil {
			apierror.Write(w, r, apierror.NewValidation(map[string]string{"source_wallet_id": apierror.FieldInvalidUUID}))
			return
		}
	}
	if req.DestinationWalletID != "" {
		destWalletID, err = uuid.Parse(req.DestinationWalletID)
		if err != nil {
			apierror.Write(w, r, apierror.NewValidation(map[string]string{"destination_wallet_id": apierror.FieldInvalidUUID}))
			return
		}
	}

	responseBody, status, err := h.service.CreateTransfer(r.Context(), CreateTransferInput{
		UserID:              userID,
		SourceWalletID:      sourceWalletID,
		DestinationWalletID: destWalletID,
		AmountMinor:         req.AmountMinor,
		Note:                req.Note,
		OccurredAt:          occurredAt,
		SessionID:           &sessionID,
		IdempotencyKey:      idempotencyKey,
		RequestBody:         body,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = w.Write(responseBody)
}

type voucherCreditRequest struct {
	Quantity   int    `json:"quantity"`
	Reason     string `json:"reason"`
	OccurredAt string `json:"occurred_at"`
}

func (h *Handler) createVoucherCredit(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}
	sessionID, _ := reqctx.SessionID(r.Context())

	walletID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		apierror.Write(w, r, apierror.ErrNotFound)
		return
	}

	idempotencyKey, err := uuid.Parse(r.Header.Get("Idempotency-Key"))
	if err != nil {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{
			"Idempotency-Key": apierror.FieldInvalidUUID,
		}))
		return
	}

	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<16))
	if err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	var req voucherCreditRequest
	if err := json.Unmarshal(body, &req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	occurredAt, ok := parseOccurredAt(req.OccurredAt)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{
			"occurred_at": apierror.FieldInvalidRFC3339Date,
		}))
		return
	}

	responseBody, status, err := h.service.CreateVoucherCredit(r.Context(), CreateVoucherCreditInput{
		UserID: userID, WalletID: walletID, Quantity: req.Quantity, Reason: req.Reason,
		OccurredAt: occurredAt, SessionID: &sessionID, IdempotencyKey: idempotencyKey, RequestBody: body,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = w.Write(responseBody)
}

type updateVoucherCreditRequest struct {
	Quantity        int    `json:"quantity"`
	Reason          string `json:"reason"`
	OccurredAt      string `json:"occurred_at"`
	ExpectedVersion int64  `json:"version"`
}

func (h *Handler) updateVoucherCredit(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}

	walletID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		apierror.Write(w, r, apierror.ErrNotFound)
		return
	}
	creditID, err := uuid.Parse(chi.URLParam(r, "creditId"))
	if err != nil {
		apierror.Write(w, r, apierror.ErrNotFound)
		return
	}

	var req updateVoucherCreditRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	occurredAt, ok := parseOccurredAt(req.OccurredAt)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{
			"occurred_at": apierror.FieldInvalidRFC3339Date,
		}))
		return
	}

	result, err := h.service.UpdateVoucherCredit(r.Context(), UpdateVoucherCreditInput{
		UserID: userID, WalletID: walletID, TransactionID: creditID, Quantity: req.Quantity, Reason: req.Reason,
		OccurredAt: occurredAt, ExpectedVersion: req.ExpectedVersion,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

type createVoucherExpenseRequest struct {
	VoucherWalletID   string  `json:"voucher_wallet_id"`
	VoucherQuantity   int     `json:"voucher_quantity"`
	TotalExpenseMinor int64   `json:"total_expense_minor"`
	OtherWalletID     string  `json:"other_wallet_id"`
	Title             string  `json:"title"`
	Description       *string `json:"description"`
	CategoryID        string  `json:"category_id"`
	TemplateID        string  `json:"template_id"`
	MediaID           string  `json:"media_id"`
	OccurredAt        string  `json:"occurred_at"`
}

func (h *Handler) createVoucherExpense(w http.ResponseWriter, r *http.Request) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		apierror.Write(w, r, apierror.ErrUnauthorized)
		return
	}
	sessionID, _ := reqctx.SessionID(r.Context())

	idempotencyKey, err := uuid.Parse(r.Header.Get("Idempotency-Key"))
	if err != nil {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{
			"Idempotency-Key": apierror.FieldInvalidUUID,
		}))
		return
	}

	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<16))
	if err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	var req createVoucherExpenseRequest
	if err := json.Unmarshal(body, &req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	occurredAt, ok := parseOccurredAt(req.OccurredAt)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{
			"occurred_at": apierror.FieldInvalidRFC3339Date,
		}))
		return
	}
	voucherWalletID, walletErr := requireWalletID(req.VoucherWalletID)
	if walletErr != nil {
		apierror.Write(w, r, walletErr)
		return
	}
	var otherWalletID *uuid.UUID
	if req.OtherWalletID != "" {
		id, err := uuid.Parse(req.OtherWalletID)
		if err != nil {
			apierror.Write(w, r, apierror.NewValidation(map[string]string{"other_wallet_id": apierror.FieldInvalidUUID}))
			return
		}
		otherWalletID = &id
	}
	categoryID, ok := parseOptionalUUID(req.CategoryID)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{"category_id": apierror.FieldInvalidUUID}))
		return
	}
	templateID, ok := parseOptionalUUID(req.TemplateID)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{"template_id": apierror.FieldInvalidUUID}))
		return
	}
	mediaID, ok := parseOptionalUUID(req.MediaID)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{"media_id": apierror.FieldInvalidUUID}))
		return
	}

	responseBody, status, err := h.service.CreateVoucherExpense(r.Context(), CreateVoucherExpenseInput{
		UserID: userID, VoucherWalletID: voucherWalletID, VoucherQuantity: req.VoucherQuantity,
		TotalExpenseMinor: req.TotalExpenseMinor, OtherWalletID: otherWalletID, Title: req.Title, Description: req.Description,
		CategoryID: categoryID, TemplateID: templateID, MediaID: mediaID, OccurredAt: occurredAt,
		SessionID: &sessionID, IdempotencyKey: idempotencyKey, RequestBody: body,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = w.Write(responseBody)
}

type updateVoucherExpenseRequest struct {
	VoucherQuantity   int     `json:"voucher_quantity"`
	TotalExpenseMinor int64   `json:"total_expense_minor"`
	OtherWalletID     string  `json:"other_wallet_id"`
	Title             string  `json:"title"`
	Description       *string `json:"description"`
	CategoryID        string  `json:"category_id"`
	TemplateID        string  `json:"template_id"`
	MediaID           string  `json:"media_id"`
	OccurredAt        string  `json:"occurred_at"`
	ExpectedVersion   int64   `json:"version"`
}

func (h *Handler) updateVoucherExpense(w http.ResponseWriter, r *http.Request) {
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

	var req updateVoucherExpenseRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		apierror.Write(w, r, apierror.ErrBadRequest)
		return
	}

	occurredAt, ok := parseOccurredAt(req.OccurredAt)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{
			"occurred_at": apierror.FieldInvalidRFC3339Date,
		}))
		return
	}
	var otherWalletID *uuid.UUID
	if req.OtherWalletID != "" {
		wid, err := uuid.Parse(req.OtherWalletID)
		if err != nil {
			apierror.Write(w, r, apierror.NewValidation(map[string]string{"other_wallet_id": apierror.FieldInvalidUUID}))
			return
		}
		otherWalletID = &wid
	}
	categoryID, ok := parseOptionalUUID(req.CategoryID)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{"category_id": apierror.FieldInvalidUUID}))
		return
	}
	templateID, ok := parseOptionalUUID(req.TemplateID)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{"template_id": apierror.FieldInvalidUUID}))
		return
	}
	mediaID, ok := parseOptionalUUID(req.MediaID)
	if !ok {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{"media_id": apierror.FieldInvalidUUID}))
		return
	}

	result, err := h.service.UpdateVoucherExpense(r.Context(), UpdateVoucherExpenseInput{
		UserID: userID, TransactionID: id, VoucherQuantity: req.VoucherQuantity, TotalExpenseMinor: req.TotalExpenseMinor,
		OtherWalletID: otherWalletID, Title: req.Title, Description: req.Description,
		CategoryID: categoryID, TemplateID: templateID, MediaID: mediaID, OccurredAt: occurredAt,
		ExpectedVersion: req.ExpectedVersion,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}
