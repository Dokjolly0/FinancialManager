// Package reports implements read-only ledger analytics: summary, trend
// over time, breakdowns by title/template and category, and month-over-
// month comparison (plan.md section 4.1, 18). Nothing here mutates state —
// every query is scoped to the authenticated user's own wallet.
package reports

import (
	"fmt"
	"time"
)

const (
	PresetLast30Days   = "last_30_days"
	PresetLast12Months = "last_12_months"
	PresetAllTime      = "all_time"
	PresetCurrentMonth = "current_month"
	PresetCurrentYear  = "current_year"
	PresetCustom       = "custom"
)

func IsValidPreset(preset string) bool {
	switch preset {
	case PresetLast30Days, PresetLast12Months, PresetAllTime, PresetCurrentMonth, PresetCurrentYear, PresetCustom:
		return true
	default:
		return false
	}
}

// Period is a resolved, UTC-bounded report window (plan.md section 18.1).
// From is nil for "intera cronologia" — there is no earlier bound to
// compute an opening balance against, so callers treat a nil From as an
// opening balance of zero rather than querying for one.
type Period struct {
	From *time.Time
	To   time.Time
}

// ResolvePeriod turns a preset (or explicit custom dates) into a concrete
// UTC window. Custom dates are calendar dates in loc, converted to UTC by
// the backend (plan.md section 4.5: "I periodi personalizzati vengono
// convertiti in intervalli UTC dal backend usando il fuso dell'utente") —
// the end date is inclusive of the whole local day, so the UTC upper bound
// is the start of the following local day.
func ResolvePeriod(preset string, customFrom, customTo *time.Time, loc *time.Location, now time.Time) (Period, error) {
	nowLocal := now.In(loc)

	switch preset {
	case PresetLast30Days:
		from := now.AddDate(0, 0, -30)
		return Period{From: &from, To: now}, nil
	case PresetLast12Months:
		from := now.AddDate(-1, 0, 0)
		return Period{From: &from, To: now}, nil
	case PresetAllTime:
		return Period{From: nil, To: now}, nil
	case PresetCurrentMonth:
		from := time.Date(nowLocal.Year(), nowLocal.Month(), 1, 0, 0, 0, 0, loc).UTC()
		return Period{From: &from, To: now}, nil
	case PresetCurrentYear:
		from := time.Date(nowLocal.Year(), 1, 1, 0, 0, 0, 0, loc).UTC()
		return Period{From: &from, To: now}, nil
	case PresetCustom:
		if customFrom == nil || customTo == nil {
			return Period{}, fmt.Errorf("custom preset requires both from and to")
		}
		fromLocal := customFrom.In(loc)
		toLocal := customTo.In(loc)
		from := time.Date(fromLocal.Year(), fromLocal.Month(), fromLocal.Day(), 0, 0, 0, 0, loc).UTC()
		to := time.Date(toLocal.Year(), toLocal.Month(), toLocal.Day(), 0, 0, 0, 0, loc).
			AddDate(0, 0, 1).UTC()
		return Period{From: &from, To: to}, nil
	default:
		return Period{}, fmt.Errorf("unknown period preset %q", preset)
	}
}

// Granularity for the trend chart (plan.md section 7.12 "Grafico
// andamento"): daily under 46 days, monthly beyond that. The plan allows
// switching to annual past 400 days too, but a personal-finance MVP never
// realistically needs coarser-than-monthly buckets to stay readable, so
// this keeps a single, simpler rule.
const (
	GranularityDaily   = "daily"
	GranularityMonthly = "monthly"
)

func GranularityFor(period Period) string {
	if period.From == nil {
		return GranularityMonthly
	}
	days := period.To.Sub(*period.From).Hours() / 24
	if days <= 45 {
		return GranularityDaily
	}
	return GranularityMonthly
}

// SpansMultipleMonths reports whether the period covers at least two
// distinct calendar months in loc (plan.md section 18.8/7.12: monthly
// comparison is only meaningful — and only shown — when this is true).
func SpansMultipleMonths(period Period, loc *time.Location) bool {
	if period.From == nil {
		return true
	}
	fromLocal := period.From.In(loc)
	// period.To is an exclusive upper bound; the last included instant is
	// just before it.
	toLocal := period.To.Add(-time.Nanosecond).In(loc)
	return fromLocal.Year() != toLocal.Year() || fromLocal.Month() != toLocal.Month()
}
