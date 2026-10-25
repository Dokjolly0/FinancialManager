package ai

import (
	"fmt"
	"testing"
	"time"

	"financial-manager-backend/internal/ai/prompt"
	"financial-manager-backend/internal/reports"
)

func TestDetectRecurring(t *testing.T) {
	rows := []MonthlyTitleRow{
		// Same price every month: stable.
		{Key: "a", Label: "Palestra", Month: "2026-07", AmountMinor: 4500},
		{Key: "a", Label: "Palestra", Month: "2026-08", AmountMinor: 4500},
		{Key: "a", Label: "Palestra", Month: "2026-09", AmountMinor: 4500},
		// Price rise: recurring but not stable; label from the last month.
		{Key: "b", Label: "netflix", Month: "2026-06", AmountMinor: 999},
		{Key: "b", Label: "netflix", Month: "2026-07", AmountMinor: 999},
		{Key: "b", Label: "Netflix", Month: "2026-08", AmountMinor: 1799},
		// Only two months: not recurring.
		{Key: "c", Label: "Regalo", Month: "2026-08", AmountMinor: 5000},
		{Key: "c", Label: "Regalo", Month: "2026-09", AmountMinor: 5000},
	}
	got := detectRecurring(rows)
	if len(got) != 2 {
		t.Fatalf("got %d items: %+v", len(got), got)
	}
	gym, tv := got[0], got[1]
	if gym.Label != "Palestra" || !gym.AmountsVaryLittle || gym.Months != 3 || gym.AvgAmountMinor != 4500 {
		t.Errorf("gym = %+v", gym)
	}
	if tv.Label != "Netflix" || tv.AmountsVaryLittle || tv.LastAmountMinor != 1799 || tv.LastSeenMonth != "2026-08" {
		t.Errorf("tv = %+v", tv)
	}
}

// everyday is n small one-month expenses, the bulk of a real ledger.
func everyday(n int, amountMinor int64) []MonthlyTitleRow {
	rows := make([]MonthlyTitleRow, n)
	for i := range rows {
		rows[i] = MonthlyTitleRow{Key: fmt.Sprint("e", i), Label: fmt.Sprint("Spesa ", i), Month: "2026-09", AmountMinor: amountMinor}
	}
	return rows
}

func TestDetectNonMonthly(t *testing.T) {
	// With the small expenses below the median item-month is 12.20, so a
	// one-off needs at least 36.60.
	rows := append(everyday(8, 300), []MonthlyTitleRow{
		// Monthly items: recurring, not listed here.
		{Key: "m", Label: "Abbonamento ChatGPT", Month: "2026-08", AmountMinor: 2300},
		{Key: "m", Label: "Abbonamento ChatGPT", Month: "2026-09", AmountMinor: 2300},
		{Key: "m", Label: "Abbonamento ChatGPT", Month: "2026-10", AmountMinor: 2300},
		{Key: "s", Label: "Caffè", Month: "2026-08", AmountMinor: 120},
		{Key: "s", Label: "Caffè", Month: "2026-09", AmountMinor: 120},
		{Key: "s", Label: "Caffè", Month: "2026-10", AmountMinor: 120},
		{Key: "v", Label: "Rinnovo vps", Month: "2026-08", AmountMinor: 1220},
		{Key: "v", Label: "Rinnovo vps", Month: "2026-09", AmountMinor: 1220},
		{Key: "v", Label: "Rinnovo vps", Month: "2026-10", AmountMinor: 13094},
		// Twelve months apart: yearly, whatever the title.
		{Key: "a", Label: "Assicurazione auto", Month: "2025-10", AmountMinor: 45000},
		{Key: "a", Label: "Assicurazione auto", Month: "2026-10", AmountMinor: 48000},
		// Two months but close together: not yearly, not one-off.
		{Key: "g", Label: "Regalo", Month: "2026-08", AmountMinor: 5000},
		{Key: "g", Label: "Regalo", Month: "2026-09", AmountMinor: 5000},
		// The title says it is yearly, even below the one-off threshold.
		{Key: "u", Label: "Abbonamento annuale Udemy", Month: "2026-08", AmountMinor: 1500},
		// One month, large: one-off.
		{Key: "h", Label: "Acquisto vps per homelab", Month: "2026-10", AmountMinor: 3953},
		// One month, small: ignored...
		{Key: "k", Label: "Acquisto cuffie", Month: "2026-10", AmountMinor: 1900},
		// ...unless it is a domain name, billed by the year.
		{Key: "d", Label: "Acquisto dominio alexviolatto.dev", Month: "2026-10", AmountMinor: 2294},
		// "Capodanno" is not the word "anno".
		{Key: "c", Label: "Cena di Capodanno", Month: "2026-01", AmountMinor: 1000},
	}...)
	got := detectNonMonthly(rows)
	// Yearly items first, then one-offs, each by amount.
	want := []prompt.NonMonthly{
		{Label: "Assicurazione auto", Months: 2, LastAmountMinor: 48000, LastSeenMonth: "2026-10", Signal: prompt.SignalAnnualGap, MonthlyEquivalentMinor: 4000},
		{Label: "Acquisto dominio alexviolatto.dev", Months: 1, LastAmountMinor: 2294, LastSeenMonth: "2026-10", Signal: prompt.SignalAnnualWord, MonthlyEquivalentMinor: 191},
		{Label: "Abbonamento annuale Udemy", Months: 1, LastAmountMinor: 1500, LastSeenMonth: "2026-08", Signal: prompt.SignalAnnualWord, MonthlyEquivalentMinor: 125},
		{Label: "Acquisto vps per homelab", Months: 1, LastAmountMinor: 3953, LastSeenMonth: "2026-10", Signal: prompt.SignalOneOff},
	}
	if len(got) != len(want) {
		t.Fatalf("got %d items: %+v", len(got), got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("item %d = %+v, want %+v", i, got[i], want[i])
		}
	}
}

func TestDetectNonMonthly_OneOffThresholdFollowsTheMedian(t *testing.T) {
	// Big everyday amounts (median 100.00) raise the threshold to 300.00.
	rows := []MonthlyTitleRow{
		{Key: "a", Label: "Spesa", Month: "2026-08", AmountMinor: 10000},
		{Key: "b", Label: "Spesa grande", Month: "2026-08", AmountMinor: 10000},
		{Key: "c", Label: "Televisore", Month: "2026-09", AmountMinor: 29999},
		{Key: "d", Label: "Divano", Month: "2026-09", AmountMinor: 30000},
	}
	got := detectNonMonthly(rows)
	if len(got) != 1 || got[0].Label != "Divano" {
		t.Fatalf("got %+v", got)
	}
	if detectNonMonthly(nil) != nil {
		t.Error("no rows, no items")
	}
}

func TestDetectNonMonthly_Capped(t *testing.T) {
	rows := everyday(40, 100)
	for i := 0; i < maxNonMonthly+5; i++ {
		rows = append(rows, MonthlyTitleRow{Key: fmt.Sprint(i), Label: fmt.Sprint("Acquisto ", i), Month: "2026-09", AmountMinor: int64(5000 + i)})
	}
	got := detectNonMonthly(rows)
	if len(got) != maxNonMonthly || got[0].LastAmountMinor != int64(5000+maxNonMonthly+4) {
		t.Fatalf("got %d items, first %+v", len(got), got[0])
	}
}

func TestFillMonths(t *testing.T) {
	loc, _ := time.LoadLocation("Europe/Rome")
	// A bucket starting at local midnight of 1 August.
	aug := time.Date(2026, 8, 1, 0, 0, 0, 0, loc)
	buckets := []reports.Bucket{{PeriodStart: aug, CreditsMinor: 100, DebitsMinor: 40}}
	from := time.Date(2026, 1, 1, 0, 0, 0, 0, loc)
	to := time.Date(2026, 10, 15, 0, 0, 0, 0, loc)

	got := fillMonths(buckets, &from, to, loc)
	want := []string{"2026-08", "2026-09", "2026-10"}
	if len(got) != len(want) {
		t.Fatalf("months = %+v", got)
	}
	for i, m := range got {
		if m.Month != want[i] {
			t.Errorf("month %d = %s, want %s", i, m.Month, want[i])
		}
	}
	if got[0].CreditsMinor != 100 || got[1].CreditsMinor != 0 {
		t.Errorf("amounts = %+v", got)
	}
	if fillMonths(nil, &from, to, loc) != nil {
		t.Error("no buckets, no months")
	}
}

func TestAnonymize(t *testing.T) {
	s := prompt.Snapshot{
		DebitTitles:  []prompt.Group{{Label: "Netflix"}, {Label: "(altre voci)"}},
		Recurring:    []prompt.Recurring{{Label: "netflix"}},
		NonMonthly:   []prompt.NonMonthly{{Label: "Netflix"}},
		Transactions: []prompt.Transaction{{Title: "Netflix "}, {Title: "Affitto", Category: "Casa", Wallet: "Conto"}},
	}
	anonymize(&s, prompt.LangIT)
	if s.DebitTitles[0].Label != "Voce 1" || s.Recurring[0].Label != "Voce 1" || s.NonMonthly[0].Label != "Voce 1" ||
		s.Transactions[0].Title != "Voce 1" {
		t.Errorf("the same title must get the same pseudonym: %+v", s)
	}
	if s.DebitTitles[1].Label != "(altre voci)" {
		t.Error("the folded row keeps its label")
	}
	if s.Transactions[1].Title != "Voce 2" || s.Transactions[1].Category != "Casa" || s.Transactions[1].Wallet != "Conto" {
		t.Errorf("categories and wallets are kept: %+v", s.Transactions[1])
	}
}
