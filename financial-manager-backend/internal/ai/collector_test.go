package ai

import (
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
		Transactions: []prompt.Transaction{{Title: "Netflix "}, {Title: "Affitto", Category: "Casa", Wallet: "Conto"}},
	}
	anonymize(&s, prompt.LangIT)
	if s.DebitTitles[0].Label != "Voce 1" || s.Recurring[0].Label != "Voce 1" || s.Transactions[0].Title != "Voce 1" {
		t.Errorf("the same title must get the same pseudonym: %+v", s)
	}
	if s.DebitTitles[1].Label != "(altre voci)" {
		t.Error("the folded row keeps its label")
	}
	if s.Transactions[1].Title != "Voce 2" || s.Transactions[1].Category != "Casa" || s.Transactions[1].Wallet != "Conto" {
		t.Errorf("categories and wallets are kept: %+v", s.Transactions[1])
	}
}
