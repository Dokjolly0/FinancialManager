package prompt

import (
	"strings"
	"testing"
)

func TestBuild_CompactGolden(t *testing.T) {
	for _, lang := range []Lang{LangIT, LangEN} {
		t.Run(string(lang), func(t *testing.T) {
			s := Trim(fixtureSnapshot(), LimitsFor(ProfileCompact), lang)
			p, err := Build(BuildInput{
				Lang: lang, Preset: PresetMonthlyCheckup, Sections: AllSections, Snapshot: s, Profile: ProfileCompact,
			})
			if err != nil {
				t.Fatal(err)
			}
			preset, _ := PresetFor(lang, PresetMonthlyCheckup)
			full := "=== SYSTEM ===\n" + p.System + "\n\n=== USER ===\n" + UserMessage(preset.Instructions, p.DataBlock) + "\n"
			goldenCompare(t, "monthly_checkup_"+string(lang)+"_compact.golden", full)
		})
	}
}

func TestBuild_CompactSystemIsShorter(t *testing.T) {
	std, _ := Build(BuildInput{Lang: LangIT, Preset: PresetSavings, Sections: AllSections, Snapshot: fixtureSnapshot()})
	cmp, _ := Build(BuildInput{Lang: LangIT, Preset: PresetSavings, Sections: AllSections, Snapshot: fixtureSnapshot(), Profile: ProfileCompact})
	if len(cmp.System) >= len(std.System) || !strings.Contains(cmp.System, "Usa SOLO i numeri presenti") {
		t.Fatalf("compact system prompt:\n%s", cmp.System)
	}
	if !strings.Contains(cmp.System, "<financial_data>") {
		t.Fatal("the compact rules keep the injection guard")
	}
	if cmp.Fingerprint == std.Fingerprint {
		t.Fatal("the profile must change the fingerprint")
	}
}

func groupsOf(n int) []Group {
	out := make([]Group, n)
	for i := range out {
		out[i] = Group{Label: strings.Repeat("x", i+1), AmountMinor: 100, Count: 1}
	}
	return out
}

func TestTrim_Groups(t *testing.T) {
	s := Snapshot{DebitCategories: append(groupsOf(10), Group{Label: "(altre voci)", AmountMinor: 500, Count: 5})}
	got := Trim(s, Limits{Categories: 3}, LangIT).DebitCategories
	if len(got) != 4 || got[3].Label != "(altre voci)" || got[3].AmountMinor != 7*100+500 || got[3].Count != 12 {
		t.Fatalf("groups = %+v", got)
	}
	if len(s.DebitCategories) != 11 {
		t.Fatal("Trim must not modify its input")
	}
	if same := Trim(s, Limits{}, LangIT); len(same.DebitCategories) != 11 {
		t.Fatal("zero limits keep everything")
	}
}

func TestTrim_MonthsTransactionsAndText(t *testing.T) {
	s := fixtureSnapshot()
	s.Months = []Month{
		{Month: "2026-01", CreditsMinor: 1, DebitsMinor: 10}, {Month: "2026-02", CreditsMinor: 2, DebitsMinor: 20},
		{Month: "2026-03", CreditsMinor: 3, DebitsMinor: 30}, {Month: "2026-04", CreditsMinor: 4, DebitsMinor: 40},
	}
	out := Trim(s, Limits{Months: 2, Transactions: 1, TextRunes: 6, ContextRunes: 10}, LangEN)
	if len(out.Months) != 3 || out.Months[0].Month != "2026-01..2026-02" || out.Months[0].DebitsMinor != 30 {
		t.Fatalf("months = %+v", out.Months)
	}
	if len(out.Transactions) != 1 || out.TransactionsOmitted != 411 {
		t.Fatalf("transactions = %d omitted %d", len(out.Transactions), out.TransactionsOmitted)
	}
	if title := out.Transactions[0].Title; len([]rune(title)) != 6 || !strings.HasSuffix(title, "…") {
		t.Fatalf("title not truncated: %q", title)
	}
	if got := *out.Context.AboutMe; len([]rune(got)) != 10 || !strings.HasSuffix(got, "…") {
		t.Fatalf("context = %q", got)
	}

	dropped := Trim(s, Limits{Transactions: -1, DropCreditTitles: true, DropTransfers: true}, LangEN)
	if dropped.Transactions != nil || dropped.TransactionsOmitted != 412 || !dropped.CreditTitlesOmitted || !dropped.TransfersOmitted {
		t.Fatalf("dropped = %+v", dropped)
	}
	p, _ := Build(BuildInput{Lang: LangEN, Preset: PresetCustom, Sections: AllSections, Snapshot: dropped})
	if strings.Count(p.DataBlock, "Left out for brevity.") != 2 {
		t.Fatalf("omitted notes missing:\n%s", p.DataBlock)
	}
}

func TestBudgetSteps_OnlyTighten(t *testing.T) {
	l := LimitsFor(ProfileCompact)
	for _, step := range BudgetSteps {
		before := l
		step.Apply(&l)
		if l == before {
			t.Errorf("step %s changed nothing on compact limits", step.Name)
		}
	}
	if l.Transactions != -1 || l.Categories != 5 || l.Titles != 5 || l.Months != 6 || l.Recurring != 4 || l.ContextRunes != 150 {
		t.Fatalf("final limits = %+v", l)
	}
	std := LimitsFor(ProfileStandard)
	BudgetSteps[3].Apply(&std)
	if std.Categories != 5 {
		t.Fatal("a step must also tighten an unlimited standard profile")
	}
}
