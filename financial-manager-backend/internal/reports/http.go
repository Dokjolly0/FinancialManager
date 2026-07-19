package reports

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"

	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/reqctx"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// Mount registers /v1/reports routes. r must already be behind the auth
// middleware (plan.md section 14.9).
func (h *Handler) Mount(r chi.Router) {
	r.Get("/v1/reports/summary", h.summary)
	r.Get("/v1/reports/timeseries", h.timeseries)
	r.Get("/v1/reports/breakdown", h.breakdown)
	r.Get("/v1/reports/monthly-comparison", h.monthlyComparison)
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

// parseCommonParams reads the params shared by every report endpoint
// (plan.md section 14.9: "from, to, timezone, group_by, include_adjustments").
func parseCommonParams(r *http.Request) (contextInput, bool, error) {
	userID, ok := reqctx.UserID(r.Context())
	if !ok {
		return contextInput{}, false, apierror.ErrUnauthorized
	}

	query := r.URL.Query()
	in := contextInput{
		UserID:   userID,
		Preset:   query.Get("preset"),
		Timezone: query.Get("timezone"),
	}

	if raw := query.Get("from"); raw != "" {
		t, err := time.Parse(time.RFC3339, raw)
		if err != nil {
			return contextInput{}, false, apierror.NewValidation(map[string]string{"from": "Deve essere una data RFC3339 valida."})
		}
		in.CustomFrom = &t
	}
	if raw := query.Get("to"); raw != "" {
		t, err := time.Parse(time.RFC3339, raw)
		if err != nil {
			return contextInput{}, false, apierror.NewValidation(map[string]string{"to": "Deve essere una data RFC3339 valida."})
		}
		in.CustomTo = &t
	}

	includeAdjustments, _ := strconv.ParseBool(query.Get("include_adjustments"))
	return in, includeAdjustments, nil
}

func (h *Handler) summary(w http.ResponseWriter, r *http.Request) {
	ctxIn, includeAdjustments, err := parseCommonParams(r)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	result, err := h.service.Summary(r.Context(), SummaryInput{contextInput: ctxIn, IncludeAdjustments: includeAdjustments})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (h *Handler) timeseries(w http.ResponseWriter, r *http.Request) {
	ctxIn, includeAdjustments, err := parseCommonParams(r)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	result, err := h.service.Timeseries(r.Context(), TimeseriesInput{contextInput: ctxIn, IncludeAdjustments: includeAdjustments})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (h *Handler) breakdown(w http.ResponseWriter, r *http.Request) {
	ctxIn, includeAdjustments, err := parseCommonParams(r)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	groupBy := r.URL.Query().Get("group_by")
	if groupBy == "" {
		groupBy = GroupByTitle
	}
	result, err := h.service.Breakdown(r.Context(), BreakdownInput{
		contextInput: ctxIn, IncludeAdjustments: includeAdjustments, GroupBy: groupBy,
	})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (h *Handler) monthlyComparison(w http.ResponseWriter, r *http.Request) {
	ctxIn, includeAdjustments, err := parseCommonParams(r)
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	result, err := h.service.MonthlyComparison(r.Context(), MonthlyComparisonInput{contextInput: ctxIn, IncludeAdjustments: includeAdjustments})
	if err != nil {
		apierror.Write(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, result)
}
