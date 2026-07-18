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
	r.Get("/v1/transactions/{id}", h.get)
	r.Patch("/v1/transactions/{id}", h.update)
	r.Delete("/v1/transactions/{id}", h.delete)
	r.Post("/v1/wallet/balance-adjustments", h.createBalanceAdjustment)
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

type createRequest struct {
	Direction     string  `json:"direction"`
	AmountMinor   int64   `json:"amount_minor"`
	Currency      string  `json:"currency"`
	Title         string  `json:"title"`
	Description   *string `json:"description"`
	OccurredAt    string  `json:"occurred_at"`
	DeviceSession string  `json:"-"`
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
			"Idempotency-Key": "Header obbligatorio, deve essere un UUID.",
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
			"occurred_at": "Deve essere una data RFC3339 valida.",
		}))
		return
	}

	responseBody, status, err := h.service.CreateStandard(r.Context(), CreateStandardInput{
		UserID:         userID,
		Direction:      req.Direction,
		AmountMinor:    req.AmountMinor,
		Currency:       req.Currency,
		Title:          req.Title,
		Description:    req.Description,
		OccurredAt:     occurredAt,
		SessionID:      &sessionID,
		IdempotencyKey: idempotencyKey,
		RequestBody:    body,
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
		apierror.Write(w, r, apierror.NewValidation(map[string]string{"direction": "Deve essere CREDIT o DEBIT."}))
		return
	}

	result, err := h.service.List(r.Context(), ListFilter{
		UserID:    userID,
		Direction: direction,
		Kind:      query.Get("kind"),
		Limit:     limit,
		Cursor:    query.Get("cursor"),
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

type updateRequest struct {
	Direction       string  `json:"direction"`
	AmountMinor     int64   `json:"amount_minor"`
	Title           string  `json:"title"`
	Description     *string `json:"description"`
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
			"occurred_at": "Deve essere una data RFC3339 valida.",
		}))
		return
	}

	result, err := h.service.UpdateStandard(r.Context(), UpdateStandardInput{
		UserID:          userID,
		TransactionID:   id,
		Direction:       req.Direction,
		AmountMinor:     req.AmountMinor,
		Title:           req.Title,
		Description:     req.Description,
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

	idempotencyKey, err := uuid.Parse(r.Header.Get("Idempotency-Key"))
	if err != nil {
		apierror.Write(w, r, apierror.NewValidation(map[string]string{
			"Idempotency-Key": "Header obbligatorio, deve essere un UUID.",
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
			"occurred_at": "Deve essere una data RFC3339 valida.",
		}))
		return
	}

	responseBody, status, err := h.service.CreateBalanceAdjustment(r.Context(), CreateBalanceAdjustmentInput{
		UserID:             userID,
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
