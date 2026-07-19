package reports

import "testing"

func TestToBreakdownItems_FoldsExcessGroupsIntoAltre(t *testing.T) {
	groups := make([]BreakdownGroup, 0, 10)
	for i := range 10 {
		groups = append(groups, BreakdownGroup{
			Key: string(rune('a' + i)), Label: string(rune('A' + i)),
			AmountMinor: int64(100 - i), TransactionCount: 1,
		})
	}

	items := toBreakdownItems(groups)

	// plan.md section 18.6: at most 6-8 named entries, the rest folded
	// into "Altre" — maxBreakdownGroups=7 named + 1 "Altre" = 8 rows.
	if len(items) != maxBreakdownGroups+1 {
		t.Fatalf("got %d items, want %d (7 named + Altre)", len(items), maxBreakdownGroups+1)
	}
	last := items[len(items)-1]
	if last.Key != "other" || last.Label != "Altre" {
		t.Fatalf("last item = %+v, want the Altre bucket", last)
	}
	wantOtherAmount := groups[7].AmountMinor + groups[8].AmountMinor + groups[9].AmountMinor
	if last.AmountMinor != wantOtherAmount {
		t.Errorf("Altre amount = %d, want %d (sum of groups 8-10)", last.AmountMinor, wantOtherAmount)
	}
	if last.TransactionCount != 3 {
		t.Errorf("Altre transaction count = %d, want 3", last.TransactionCount)
	}
}

func TestToBreakdownItems_NoAltreWhenWithinLimit(t *testing.T) {
	groups := []BreakdownGroup{
		{Key: "a", Label: "A", AmountMinor: 100, TransactionCount: 1},
		{Key: "b", Label: "B", AmountMinor: 50, TransactionCount: 1},
	}
	items := toBreakdownItems(groups)
	if len(items) != 2 {
		t.Fatalf("got %d items, want exactly 2 (no Altre needed)", len(items))
	}
}

func TestToBreakdownItems_PercentagesSumCloseTo100(t *testing.T) {
	groups := []BreakdownGroup{
		{Key: "a", Label: "A", AmountMinor: 300, TransactionCount: 1},
		{Key: "b", Label: "B", AmountMinor: 200, TransactionCount: 1},
		{Key: "c", Label: "C", AmountMinor: 500, TransactionCount: 1},
	}
	items := toBreakdownItems(groups)

	var sum float64
	for _, it := range items {
		sum += it.Percentage
	}
	if sum < 99.99 || sum > 100.01 {
		t.Errorf("percentages sum to %v, want ~100", sum)
	}
}

func TestRoundPercent(t *testing.T) {
	if got := roundPercent(0, 0); got != 0 {
		t.Errorf("roundPercent(0, 0) = %v, want 0 (avoid division by zero)", got)
	}
	if got := roundPercent(25, 100); got != 25 {
		t.Errorf("roundPercent(25, 100) = %v, want 25", got)
	}
	if got := roundPercent(1, 3); got != 33.33 {
		t.Errorf("roundPercent(1, 3) = %v, want 33.33", got)
	}
}
