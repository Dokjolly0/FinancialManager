package reports

import (
	"context"
	"math"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/clock"
	"financial-manager-backend/internal/platform/reportcache"
	"financial-manager-backend/internal/transactions"
	"financial-manager-backend/internal/users"
	"financial-manager-backend/internal/wallets"
)

const timeLayout = "2006-01-02T15:04:05Z07:00"

// maxBreakdownGroups caps how many individual entries a breakdown shows
// before folding the rest into "Altre" (plan.md section 18.6: "mostrare al
// massimo 6-8 voci principali").
const maxBreakdownGroups = 7

var allKinds = []string{transactions.KindStandard, transactions.KindOpeningBalance, transactions.KindBalanceAdjustment}

func kindsFor(includeAdjustments bool) []string {
	if includeAdjustments {
		return []string{transactions.KindStandard, transactions.KindBalanceAdjustment}
	}
	return []string{transactions.KindStandard}
}

type Service struct {
	repo    *Repository
	wallets *wallets.Repository
	users   *users.Repository
	clock   clock.Clock
	cache   *reportcache.Store
}

type Deps struct {
	Repo    *Repository
	Wallets *wallets.Repository
	Users   *users.Repository
	Clock   clock.Clock
	// Cache is optional: a nil Store (the zero value left by tests that
	// don't wire Redis) simply bypasses caching (plan.md section 18.9).
	Cache *reportcache.Store
}

func NewService(d Deps) *Service {
	return &Service{repo: d.Repo, wallets: d.Wallets, users: d.Users, clock: d.Clock, cache: d.Cache}
}

// paramsKey builds the cache key's variable part from everything besides
// the wallet/version, which reportcache.Cached folds in separately (plan.md
// section 18.9: "utente; portafoglio; intervallo; fuso; grouping; flag
// rettifiche"). The user is implied by the wallet lookup in resolveContext,
// so it isn't repeated here.
func paramsKey(in contextInput, endpoint string, extra ...string) string {
	from, to := "", ""
	if in.CustomFrom != nil {
		from = in.CustomFrom.Format(timeLayout)
	}
	if in.CustomTo != nil {
		to = in.CustomTo.Format(timeLayout)
	}
	parts := append([]string{endpoint, in.Preset, from, to, in.Timezone}, extra...)
	return strings.Join(parts, "|")
}

// reportContext is what every report endpoint needs after resolving the
// request's period/timezone/preset against the user's own wallet.
type reportContext struct {
	wallet wallets.Wallet
	loc    *time.Location
	period Period
}

type contextInput struct {
	UserID     uuid.UUID
	Preset     string
	CustomFrom *time.Time
	CustomTo   *time.Time
	Timezone   string
}

func (s *Service) resolveContext(ctx context.Context, in contextInput) (reportContext, error) {
	wallet, err := s.wallets.GetByUserID(ctx, in.UserID)
	if err != nil {
		return reportContext{}, err
	}

	tzName := in.Timezone
	if tzName == "" {
		if user, err := s.users.GetByID(ctx, in.UserID); err == nil && user.Timezone != "" {
			tzName = user.Timezone
		} else {
			tzName = "Europe/Rome"
		}
	}
	loc, err := time.LoadLocation(tzName)
	if err != nil {
		return reportContext{}, apierror.NewValidation(map[string]string{"timezone": apierror.FieldInvalidTimezone})
	}

	preset := in.Preset
	if preset == "" {
		preset = PresetLast30Days
	}
	if !IsValidPreset(preset) {
		return reportContext{}, apierror.NewValidation(map[string]string{"preset": apierror.FieldInvalidPreset})
	}

	period, err := ResolvePeriod(preset, in.CustomFrom, in.CustomTo, loc, s.clock.Now())
	if err != nil {
		return reportContext{}, apierror.NewValidation(map[string]string{"from": apierror.FieldCustomRangeRequired})
	}

	return reportContext{wallet: wallet, loc: loc, period: period}, nil
}

// --- Summary -----------------------------------------------------------------

type SummaryInput struct {
	contextInput
	IncludeAdjustments bool
}

type summaryResponse struct {
	OpeningBalanceMinor int64    `json:"opening_balance_minor"`
	ClosingBalanceMinor int64    `json:"closing_balance_minor"`
	TotalCreditsMinor   int64    `json:"total_credits_minor"`
	TotalDebitsMinor    int64    `json:"total_debits_minor"`
	NetMinor            int64    `json:"net_minor"`
	SavingsRatePercent  *float64 `json:"savings_rate_percent,omitempty"`
	TransactionCount    int64    `json:"transaction_count"`
	Currency            string   `json:"currency"`
	From                *string  `json:"from,omitempty"`
	To                  string   `json:"to"`
}

// Summary implements plan.md section 18.3, 7.12 "Sezione riepilogo".
func (s *Service) Summary(ctx context.Context, in SummaryInput) (summaryResponse, error) {
	rc, err := s.resolveContext(ctx, in.contextInput)
	if err != nil {
		return summaryResponse{}, err
	}
	key := paramsKey(in.contextInput, "summary", strconv.FormatBool(in.IncludeAdjustments))
	return reportcache.Cached(ctx, s.cache, rc.wallet.ID, "summary", key, func() (summaryResponse, error) {
		return s.computeSummary(ctx, rc, in)
	})
}

func (s *Service) computeSummary(ctx context.Context, rc reportContext, in SummaryInput) (summaryResponse, error) {
	var opening int64
	var err error
	if rc.period.From != nil {
		opening, err = s.repo.SignedImpact(ctx, rc.wallet.ID, nil, rc.period.From)
		if err != nil {
			return summaryResponse{}, err
		}
	}

	impact, err := s.repo.SignedImpact(ctx, rc.wallet.ID, rc.period.From, &rc.period.To)
	if err != nil {
		return summaryResponse{}, err
	}

	totals, err := s.repo.Totals(ctx, rc.wallet.ID, kindsFor(in.IncludeAdjustments), rc.period.From, rc.period.To)
	if err != nil {
		return summaryResponse{}, err
	}

	net := totals.CreditsMinor - totals.DebitsMinor
	var savingsRate *float64
	if totals.CreditsMinor > 0 {
		rate := roundPercent(net, totals.CreditsMinor)
		savingsRate = &rate
	}

	var fromStr *string
	if rc.period.From != nil {
		f := rc.period.From.Format(timeLayout)
		fromStr = &f
	}

	return summaryResponse{
		OpeningBalanceMinor: opening,
		ClosingBalanceMinor: opening + impact,
		TotalCreditsMinor:   totals.CreditsMinor,
		TotalDebitsMinor:    totals.DebitsMinor,
		NetMinor:            net,
		SavingsRatePercent:  savingsRate,
		TransactionCount:    totals.Count,
		Currency:            rc.wallet.Currency,
		From:                fromStr,
		To:                  rc.period.To.Format(timeLayout),
	}, nil
}

// --- Timeseries ----------------------------------------------------------------

type TimeseriesInput struct {
	contextInput
	IncludeAdjustments bool
}

type timeseriesPoint struct {
	PeriodStart  string `json:"period_start"`
	CreditsMinor int64  `json:"credits_minor"`
	DebitsMinor  int64  `json:"debits_minor"`
	NetMinor     int64  `json:"net_minor"`
	BalanceMinor int64  `json:"balance_minor"`
}

type timeseriesResponse struct {
	Granularity string            `json:"granularity"`
	Points      []timeseriesPoint `json:"points"`
}

// Timeseries implements plan.md section 18.7's bucketing (auto daily/
// monthly granularity, gap-filled with zero — section 7.12 "Grafico
// andamento"). The cumulative balance line always reflects every kind
// (including rettifiche) regardless of IncludeAdjustments, since the real
// balance did move — only the displayed credits/debits bars respect the
// toggle (plan.md section 18.2: "mostrare separatamente il loro impatto
// sul saldo").
func (s *Service) Timeseries(ctx context.Context, in TimeseriesInput) (timeseriesResponse, error) {
	rc, err := s.resolveContext(ctx, in.contextInput)
	if err != nil {
		return timeseriesResponse{}, err
	}
	key := paramsKey(in.contextInput, "timeseries", strconv.FormatBool(in.IncludeAdjustments))
	return reportcache.Cached(ctx, s.cache, rc.wallet.ID, "timeseries", key, func() (timeseriesResponse, error) {
		return s.computeTimeseries(ctx, rc, in)
	})
}

func (s *Service) computeTimeseries(ctx context.Context, rc reportContext, in TimeseriesInput) (timeseriesResponse, error) {
	granularity := GranularityFor(rc.period)

	displayBuckets, err := s.repo.Buckets(ctx, rc.wallet.ID, kindsFor(in.IncludeAdjustments), rc.period.From, rc.period.To, granularity, rc.loc.String())
	if err != nil {
		return timeseriesResponse{}, err
	}
	balanceBuckets, err := s.repo.Buckets(ctx, rc.wallet.ID, allKinds, rc.period.From, rc.period.To, granularity, rc.loc.String())
	if err != nil {
		return timeseriesResponse{}, err
	}

	var opening int64
	if rc.period.From != nil {
		opening, err = s.repo.SignedImpact(ctx, rc.wallet.ID, nil, rc.period.From)
		if err != nil {
			return timeseriesResponse{}, err
		}
	}

	boundaries := timelineBoundaries(rc.period, granularity, rc.loc, displayBuckets, balanceBuckets)
	displayMap := bucketMap(displayBuckets)
	balanceMap := bucketMap(balanceBuckets)

	points := make([]timeseriesPoint, 0, len(boundaries))
	running := opening
	for _, boundary := range boundaries {
		key := bucketKey(boundary)
		display := displayMap[key]
		balance := balanceMap[key]
		running += balance.CreditsMinor - balance.DebitsMinor
		points = append(points, timeseriesPoint{
			PeriodStart:  boundary.Format(timeLayout),
			CreditsMinor: display.CreditsMinor,
			DebitsMinor:  display.DebitsMinor,
			NetMinor:     display.CreditsMinor - display.DebitsMinor,
			BalanceMinor: running,
		})
	}

	return timeseriesResponse{Granularity: granularity, Points: points}, nil
}

// --- Breakdown -----------------------------------------------------------------

const (
	GroupByTitle    = "title"
	GroupByCategory = "category"
)

type BreakdownInput struct {
	contextInput
	IncludeAdjustments bool
	GroupBy            string
}

type breakdownItem struct {
	Key              string  `json:"key"`
	Label            string  `json:"label"`
	AmountMinor      int64   `json:"amount_minor"`
	Percentage       float64 `json:"percentage"`
	TransactionCount int64   `json:"transaction_count"`
}

type breakdownResponse struct {
	GroupBy string          `json:"group_by"`
	Credits []breakdownItem `json:"credits"`
	Debits  []breakdownItem `json:"debits"`
}

// Breakdown implements plan.md section 18.4 (group_by=title, coalescing by
// template when present) and 18.5 (group_by=category). Credits and debits
// are returned as separate lists with independent denominators — never
// merged into one pie (section 18.4: "Do not add income and expenses
// into a single pie, since they have opposite meanings").
func (s *Service) Breakdown(ctx context.Context, in BreakdownInput) (breakdownResponse, error) {
	if in.GroupBy != GroupByTitle && in.GroupBy != GroupByCategory {
		return breakdownResponse{}, apierror.NewValidation(map[string]string{"group_by": apierror.FieldInvalidGroupBy})
	}

	rc, err := s.resolveContext(ctx, in.contextInput)
	if err != nil {
		return breakdownResponse{}, err
	}
	key := paramsKey(in.contextInput, "breakdown", in.GroupBy, strconv.FormatBool(in.IncludeAdjustments))
	return reportcache.Cached(ctx, s.cache, rc.wallet.ID, "breakdown", key, func() (breakdownResponse, error) {
		return s.computeBreakdown(ctx, rc, in)
	})
}

func (s *Service) computeBreakdown(ctx context.Context, rc reportContext, in BreakdownInput) (breakdownResponse, error) {
	kinds := kindsFor(in.IncludeAdjustments)

	query := s.repo.BreakdownByTitle
	if in.GroupBy == GroupByCategory {
		query = s.repo.BreakdownByCategory
	}

	credits, err := query(ctx, rc.wallet.ID, transactions.DirectionCredit, kinds, rc.period.From, rc.period.To)
	if err != nil {
		return breakdownResponse{}, err
	}
	debits, err := query(ctx, rc.wallet.ID, transactions.DirectionDebit, kinds, rc.period.From, rc.period.To)
	if err != nil {
		return breakdownResponse{}, err
	}

	return breakdownResponse{
		GroupBy: in.GroupBy,
		Credits: toBreakdownItems(credits),
		Debits:  toBreakdownItems(debits),
	}, nil
}

func toBreakdownItems(groups []BreakdownGroup) []breakdownItem {
	var total int64
	for _, g := range groups {
		total += g.AmountMinor
	}

	items := make([]breakdownItem, 0, len(groups))
	var otherAmount, otherCount int64
	for i, g := range groups {
		if i < maxBreakdownGroups {
			items = append(items, breakdownItem{
				Key: g.Key, Label: g.Label, AmountMinor: g.AmountMinor,
				Percentage: roundPercent(g.AmountMinor, total), TransactionCount: g.TransactionCount,
			})
			continue
		}
		otherAmount += g.AmountMinor
		otherCount += g.TransactionCount
	}
	if otherAmount > 0 || otherCount > 0 {
		items = append(items, breakdownItem{
			Key: "other", Label: "Altre", AmountMinor: otherAmount,
			Percentage: roundPercent(otherAmount, total), TransactionCount: otherCount,
		})
	}
	return items
}

// --- Monthly comparison ---------------------------------------------------------

type MonthlyComparisonInput struct {
	contextInput
	IncludeAdjustments bool
}

type monthlyComparisonRow struct {
	Month        string `json:"month"`
	CreditsMinor int64  `json:"credits_minor"`
	DebitsMinor  int64  `json:"debits_minor"`
	NetMinor     int64  `json:"net_minor"`
}

type monthlyComparisonResponse struct {
	Months              []monthlyComparisonRow `json:"months"`
	SpansMultipleMonths bool                   `json:"spans_multiple_months"`
}

// MonthlyComparison implements plan.md section 18.7. SpansMultipleMonths
// tells the client whether to show this section at all (section 18.8/7.12)
// without duplicating the calendar-month math client-side.
func (s *Service) MonthlyComparison(ctx context.Context, in MonthlyComparisonInput) (monthlyComparisonResponse, error) {
	rc, err := s.resolveContext(ctx, in.contextInput)
	if err != nil {
		return monthlyComparisonResponse{}, err
	}
	key := paramsKey(in.contextInput, "monthly-comparison", strconv.FormatBool(in.IncludeAdjustments))
	return reportcache.Cached(ctx, s.cache, rc.wallet.ID, "monthly-comparison", key, func() (monthlyComparisonResponse, error) {
		return s.computeMonthlyComparison(ctx, rc, in)
	})
}

func (s *Service) computeMonthlyComparison(ctx context.Context, rc reportContext, in MonthlyComparisonInput) (monthlyComparisonResponse, error) {
	buckets, err := s.repo.Buckets(ctx, rc.wallet.ID, kindsFor(in.IncludeAdjustments), rc.period.From, rc.period.To, GranularityMonthly, rc.loc.String())
	if err != nil {
		return monthlyComparisonResponse{}, err
	}

	boundaries := timelineBoundaries(rc.period, GranularityMonthly, rc.loc, buckets)
	bucketsByKey := bucketMap(buckets)

	rows := make([]monthlyComparisonRow, 0, len(boundaries))
	for _, boundary := range boundaries {
		b := bucketsByKey[bucketKey(boundary)]
		rows = append(rows, monthlyComparisonRow{
			Month:        boundary.Format(timeLayout),
			CreditsMinor: b.CreditsMinor,
			DebitsMinor:  b.DebitsMinor,
			NetMinor:     b.CreditsMinor - b.DebitsMinor,
		})
	}

	return monthlyComparisonResponse{
		Months:              rows,
		SpansMultipleMonths: SpansMultipleMonths(rc.period, rc.loc),
	}, nil
}

// --- Shared helpers --------------------------------------------------------------

func roundPercent(part, total int64) float64 {
	if total == 0 {
		return 0
	}
	return math.Round(float64(part)/float64(total)*10000) / 100
}

func bucketKey(t time.Time) string {
	return t.UTC().Format(time.RFC3339)
}

func bucketMap(buckets []Bucket) map[string]Bucket {
	m := make(map[string]Bucket, len(buckets))
	for _, b := range buckets {
		m[bucketKey(b.PeriodStart)] = b
	}
	return m
}

// timelineBoundaries returns every bucket start expected across the period
// (plan.md section 18.7: "riempire i mesi senza operazioni con zero"). For
// an open-ended "intera cronologia" period there is no natural lower bound
// to generate from, so it falls back to the union of whatever bucket sets
// actually came back from the database.
func timelineBoundaries(period Period, granularity string, loc *time.Location, bucketSets ...[]Bucket) []time.Time {
	if period.From != nil {
		return generateBoundaries(*period.From, period.To, granularity, loc)
	}

	seen := map[string]time.Time{}
	for _, set := range bucketSets {
		for _, b := range set {
			seen[bucketKey(b.PeriodStart)] = b.PeriodStart
		}
	}
	boundaries := make([]time.Time, 0, len(seen))
	for _, t := range seen {
		boundaries = append(boundaries, t)
	}
	sort.Slice(boundaries, func(i, j int) bool { return boundaries[i].Before(boundaries[j]) })
	return boundaries
}

// generateBoundaries walks from..to in loc's calendar, one bucket at a
// time. Stepping with AddDate on a time already located in loc keeps the
// wall-clock date correct across DST transitions (plan.md section 18.10:
// "Testare cambio ora legale ... nel fuso Europe/Rome").
func generateBoundaries(from, to time.Time, granularity string, loc *time.Location) []time.Time {
	fromLocal := from.In(loc)
	var cursor time.Time
	if granularity == GranularityMonthly {
		cursor = time.Date(fromLocal.Year(), fromLocal.Month(), 1, 0, 0, 0, 0, loc)
	} else {
		cursor = time.Date(fromLocal.Year(), fromLocal.Month(), fromLocal.Day(), 0, 0, 0, 0, loc)
	}

	var boundaries []time.Time
	for cursor.Before(to) {
		boundaries = append(boundaries, cursor.UTC())
		if granularity == GranularityMonthly {
			cursor = cursor.AddDate(0, 1, 0)
		} else {
			cursor = cursor.AddDate(0, 0, 1)
		}
	}
	return boundaries
}
