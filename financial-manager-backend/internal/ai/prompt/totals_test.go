package prompt

import (
	"strings"
	"testing"
	"time"
)

func TestRenderQuestionTotals(t *testing.T) {
	// "Quanto spendo in media al mese di benzina?" asked on 28 October:
	// fuel in August and September, nothing yet in October.
	got := RenderQuestionTotals(LangIT, []TermTotals{
		{Term: "benzi", Months: []MonthTotal{
			{Month: "2026-08", DebitsMinor: 6000, Count: 2},
			{Month: "2026-09", DebitsMinor: 21000, Count: 4},
		}},
		{Term: "auto"},
	}, TotalsPeriod{LastDay: time.Date(2026, 10, 28, 23, 59, 59, 0, time.UTC)})
	for _, want := range []string{
		"<financial_data>\n## Totali calcolati per la domanda\n",
		"### Parola \"benzi\"\nmese | uscite | entrate | movimenti\n2026-08 | 60.00 | 0.00 | 2\n2026-09 | 210.00 | 0.00 | 4\n2026-10 | 0.00 | 0.00 | 0\n",
		"Totale: uscite 270.00, entrate 0.00, 6 movimenti.",
		"Media mensile delle uscite: 90.00 su 3 mesi (dal 2026-08 al 2026-10, compresi i mesi senza movimenti). Contando solo i mesi con almeno un'uscita (2): 135.00.",
		"Il mese 2026-10 è ancora in corso: i dati arrivano al 2026-10-28.",
		"### Parola \"auto\"\nNessun movimento del periodo contiene \"auto\" nel titolo o nella categoria.",
	} {
		if !strings.Contains(got, want) {
			t.Errorf("missing %q in:\n%s", want, got)
		}
	}
	if strings.Contains(got, "entrate:") || strings.Contains(got, "Media mensile delle entrate") {
		t.Errorf("no income average without income:\n%s", got)
	}
	if !strings.HasSuffix(got, "</financial_data>") {
		t.Errorf("not closed:\n%s", got)
	}
}

func TestRenderQuestionTotals_SingleMonthAndClosedPeriod(t *testing.T) {
	got := RenderQuestionTotals(LangEN, []TermTotals{
		{Term: "stipend", Months: []MonthTotal{{Month: "2026-09", CreditsMinor: 260000, Count: 1}}},
	}, TotalsPeriod{LastDay: time.Date(2026, 9, 30, 23, 59, 59, 0, time.UTC)})
	if !strings.Contains(got, "Total: expenses 0.00, income 2600.00, 1 transactions.") {
		t.Errorf("total missing:\n%s", got)
	}
	if strings.Contains(got, "Monthly average") || strings.Contains(got, "still running") {
		t.Errorf("one closed month needs no average nor running note:\n%s", got)
	}
	if RenderQuestionTotals(LangEN, nil, TotalsPeriod{}) != "" {
		t.Error("no words, no block")
	}
}

func TestRenderQuestionTotals_KeepsTheLastMonthsOfALongTable(t *testing.T) {
	var months []MonthTotal
	for m := time.Date(2023, 1, 1, 0, 0, 0, 0, time.UTC); m.Year() < 2026; m = m.AddDate(0, 1, 0) {
		months = append(months, MonthTotal{Month: m.Format("2006-01"), DebitsMinor: 1000, Count: 1})
	}
	got := RenderQuestionTotals(LangEN, []TermTotals{{Term: "gym", Months: months}},
		TotalsPeriod{LastDay: time.Date(2025, 12, 31, 12, 0, 0, 0, time.UTC)})
	if strings.Contains(got, "2023-12 |") || !strings.Contains(got, "Last 24 months:\n") || !strings.Contains(got, "2024-01 |") {
		t.Errorf("table not cut to the last 24 months:\n%s", got)
	}
	if !strings.Contains(got, "Total: expenses 360.00") || !strings.Contains(got, "10.00 over 36 months") {
		t.Errorf("totals must still cover every month:\n%s", got)
	}
}
