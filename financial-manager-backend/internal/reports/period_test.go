package reports

import (
	"testing"
	"time"
)

func mustLoadRome(t *testing.T) *time.Location {
	t.Helper()
	loc, err := time.LoadLocation("Europe/Rome")
	if err != nil {
		t.Fatalf("load Europe/Rome: %v", err)
	}
	return loc
}

func TestResolvePeriod_Last30Days(t *testing.T) {
	loc := mustLoadRome(t)
	now := time.Date(2026, 3, 15, 12, 0, 0, 0, time.UTC)

	period, err := ResolvePeriod(PresetLast30Days, nil, nil, loc, now)
	if err != nil {
		t.Fatalf("ResolvePeriod() error = %v", err)
	}
	wantFrom := now.AddDate(0, 0, -30)
	if period.From == nil || !period.From.Equal(wantFrom) {
		t.Errorf("From = %v, want %v", period.From, wantFrom)
	}
	if !period.To.Equal(now) {
		t.Errorf("To = %v, want %v", period.To, now)
	}
}

func TestResolvePeriod_AllTimeHasNilFrom(t *testing.T) {
	loc := mustLoadRome(t)
	now := time.Date(2026, 3, 15, 12, 0, 0, 0, time.UTC)

	period, err := ResolvePeriod(PresetAllTime, nil, nil, loc, now)
	if err != nil {
		t.Fatalf("ResolvePeriod() error = %v", err)
	}
	if period.From != nil {
		t.Errorf("From = %v, want nil for all_time", period.From)
	}
}

func TestResolvePeriod_CurrentMonthStartsAtLocalMidnight(t *testing.T) {
	loc := mustLoadRome(t)
	// 2026-03-15 10:00 UTC = 2026-03-15 11:00 Europe/Rome (CET->CEST already
	// switched by March 15, so this is a good sanity check independent of
	// the DST-boundary test below).
	now := time.Date(2026, 3, 15, 10, 0, 0, 0, time.UTC)

	period, err := ResolvePeriod(PresetCurrentMonth, nil, nil, loc, now)
	if err != nil {
		t.Fatalf("ResolvePeriod() error = %v", err)
	}
	if period.From == nil {
		t.Fatal("From is nil, want start of March 1st")
	}
	fromLocal := period.From.In(loc)
	if fromLocal.Year() != 2026 || fromLocal.Month() != time.March || fromLocal.Day() != 1 || fromLocal.Hour() != 0 {
		t.Errorf("From in local time = %v, want 2026-03-01 00:00 Europe/Rome", fromLocal)
	}
}

func TestResolvePeriod_Custom_EndDateIsInclusiveOfWholeLocalDay(t *testing.T) {
	loc := mustLoadRome(t)
	now := time.Date(2026, 6, 20, 12, 0, 0, 0, time.UTC)
	from := time.Date(2026, 6, 1, 0, 0, 0, 0, loc)
	to := time.Date(2026, 6, 10, 0, 0, 0, 0, loc)

	period, err := ResolvePeriod(PresetCustom, &from, &to, loc, now)
	if err != nil {
		t.Fatalf("ResolvePeriod() error = %v", err)
	}
	// The exclusive upper bound must be the start of June 11th local time,
	// not June 10th — otherwise transactions on June 10th would be dropped.
	wantTo := time.Date(2026, 6, 11, 0, 0, 0, 0, loc)
	if !period.To.Equal(wantTo) {
		t.Errorf("To = %v, want %v (start of the day after the inclusive end date)", period.To, wantTo)
	}
}

func TestResolvePeriod_Custom_RequiresBothDates(t *testing.T) {
	loc := mustLoadRome(t)
	now := time.Now()
	from := now

	if _, err := ResolvePeriod(PresetCustom, &from, nil, loc, now); err == nil {
		t.Error("expected an error when 'to' is missing for a custom preset")
	}
}

func TestResolvePeriod_RejectsUnknownPreset(t *testing.T) {
	loc := mustLoadRome(t)
	if _, err := ResolvePeriod("sideways", nil, nil, loc, time.Now()); err == nil {
		t.Error("expected an error for an unknown preset")
	}
}

func TestGranularityFor(t *testing.T) {
	now := time.Date(2026, 5, 1, 0, 0, 0, 0, time.UTC)
	from45 := now.AddDate(0, 0, -45)
	from46 := now.AddDate(0, 0, -46)

	if got := GranularityFor(Period{From: &from45, To: now}); got != GranularityDaily {
		t.Errorf("45-day period granularity = %q, want daily", got)
	}
	if got := GranularityFor(Period{From: &from46, To: now}); got != GranularityMonthly {
		t.Errorf("46-day period granularity = %q, want monthly", got)
	}
	if got := GranularityFor(Period{From: nil, To: now}); got != GranularityMonthly {
		t.Errorf("all-time granularity = %q, want monthly", got)
	}
}

func TestSpansMultipleMonths(t *testing.T) {
	loc := mustLoadRome(t)

	sameMonthFrom := time.Date(2026, 3, 1, 0, 0, 0, 0, loc)
	sameMonthTo := time.Date(2026, 3, 31, 23, 59, 0, 0, loc)
	if SpansMultipleMonths(Period{From: &sameMonthFrom, To: sameMonthTo}, loc) {
		t.Error("a period entirely within March must not span multiple months")
	}

	twoMonthsFrom := time.Date(2026, 3, 15, 0, 0, 0, 0, loc)
	twoMonthsTo := time.Date(2026, 4, 5, 0, 0, 0, 0, loc)
	if !SpansMultipleMonths(Period{From: &twoMonthsFrom, To: twoMonthsTo}, loc) {
		t.Error("a period crossing March into April must span multiple months")
	}

	if !SpansMultipleMonths(Period{From: nil, To: time.Now()}, loc) {
		t.Error("all-time must always be treated as spanning multiple months")
	}
}

// plan.md section 18.10: "Testare cambio ora legale e confini di mese nel
// fuso Europe/Rome". Europe/Rome switches to CEST (UTC+2) on the last
// Sunday of March; 2026's switch is March 29th at 02:00 local, clocks jump
// to 03:00. Stepping day-by-day across that boundary via AddDate on a
// value already located in loc must still land on local midnight each day,
// not drift by an hour.
func TestGenerateBoundaries_CrossesDaylightSavingBoundaryCleanly(t *testing.T) {
	loc := mustLoadRome(t)
	from := time.Date(2026, 3, 27, 0, 0, 0, 0, loc)
	to := time.Date(2026, 4, 1, 0, 0, 0, 0, loc)

	boundaries := generateBoundaries(from, to, GranularityDaily, loc)
	if len(boundaries) != 5 {
		t.Fatalf("got %d boundaries, want 5 (27, 28, 29, 30, 31 March)", len(boundaries))
	}
	for i, b := range boundaries {
		local := b.In(loc)
		if local.Hour() != 0 || local.Minute() != 0 {
			t.Errorf("boundary %d = %v, want local midnight exactly", i, local)
		}
		wantDay := 27 + i
		if local.Day() != wantDay {
			t.Errorf("boundary %d day = %d, want %d", i, local.Day(), wantDay)
		}
	}
}

func TestGenerateBoundaries_MonthlyAcrossYearBoundary(t *testing.T) {
	loc := mustLoadRome(t)
	from := time.Date(2025, 11, 1, 0, 0, 0, 0, loc)
	to := time.Date(2026, 2, 1, 0, 0, 0, 0, loc)

	boundaries := generateBoundaries(from, to, GranularityMonthly, loc)
	wantMonths := []time.Month{time.November, time.December, time.January}
	if len(boundaries) != len(wantMonths) {
		t.Fatalf("got %d boundaries, want %d", len(boundaries), len(wantMonths))
	}
	for i, b := range boundaries {
		local := b.In(loc)
		if local.Month() != wantMonths[i] || local.Day() != 1 {
			t.Errorf("boundary %d = %v, want the 1st of %v", i, local, wantMonths[i])
		}
	}
}
