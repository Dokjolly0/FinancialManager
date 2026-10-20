package prompt

import (
	"unicode/utf8"
)

// Profiles of the data block (plan.md section 33): standard sends
// everything the collector gathered; compact keeps the prompt small enough
// for a model running on a phone, whose context and prompt-reading speed
// are limited.
const (
	ProfileStandard = "standard"
	ProfileCompact  = "compact"
)

// IsValidProfile reports whether p is a known profile ("" is standard).
func IsValidProfile(p string) bool {
	return p == "" || p == ProfileStandard || p == ProfileCompact
}

// Limits caps each part of the data block. Zero means "no limit" for the
// counts and lengths; the Drop flags remove a part entirely.
type Limits struct {
	Categories   int // rows per category list
	Titles       int // rows per title list
	Months       int // most recent months kept; older ones are summed
	Recurring    int
	Transfers    int
	Transactions int // -1 drops the list, 0 keeps it as collected
	TextRunes    int // titles, categories and wallet names in tables
	PurposeRunes int
	ContextRunes int // each personal-context field

	DropCreditTitles bool
	DropTransfers    bool
}

// LimitsFor returns the base limits of a profile.
func LimitsFor(profile string) Limits {
	if profile == ProfileCompact {
		return Limits{
			Categories: 8, Titles: 10, Months: 12, Recurring: 8, Transfers: 5, Transactions: 100,
			TextRunes: 40, PurposeRunes: 80, ContextRunes: 300,
		}
	}
	return Limits{}
}

// BudgetStep tightens limits to save tokens. Steps are applied in order,
// one more each time the prompt is still over budget.
type BudgetStep struct {
	Name  string
	Apply func(*Limits)
}

// BudgetSteps is the fixed order in which detail is given up: first the
// raw transactions, then the least useful aggregates, and the personal
// context last.
var BudgetSteps = []BudgetStep{
	{"transactions_30", func(l *Limits) { l.Transactions = tighter(l.Transactions, 30) }},
	{"transactions_0", func(l *Limits) { l.Transactions = -1 }},
	{"credit_titles", func(l *Limits) { l.DropCreditTitles = true }},
	{"groups_5", func(l *Limits) { l.Categories, l.Titles = tighter(l.Categories, 5), tighter(l.Titles, 5) }},
	{"months_6", func(l *Limits) { l.Months = tighter(l.Months, 6) }},
	{"transfers", func(l *Limits) { l.DropTransfers = true }},
	{"recurring_4", func(l *Limits) { l.Recurring = tighter(l.Recurring, 4) }},
	{"context_150", func(l *Limits) { l.ContextRunes = tighter(l.ContextRunes, 150) }},
}

func tighter(current, limit int) int {
	if current <= 0 || current > limit {
		return limit
	}
	return current
}

// Trim applies limits to a snapshot. It is pure: the same snapshot and
// limits always give the same result, so a run reproduces its preview's
// fingerprint. otherLabel names the row that sums groups cut from a list.
func Trim(s Snapshot, l Limits, lang Lang) Snapshot {
	other := "(other items)"
	if lang == LangIT {
		other = "(altre voci)"
	}
	out := s
	out.DebitCategories = trimGroups(s.DebitCategories, l.Categories, l.TextRunes, other)
	out.CreditCategories = trimGroups(s.CreditCategories, l.Categories, l.TextRunes, other)
	out.DebitTitles = trimGroups(s.DebitTitles, l.Titles, l.TextRunes, other)
	out.CreditTitles = trimGroups(s.CreditTitles, l.Titles, l.TextRunes, other)
	if l.DropCreditTitles {
		out.CreditTitles = nil
		out.CreditTitlesOmitted = len(s.CreditTitles) > 0
	}

	if l.Months > 0 && len(s.Months) > l.Months {
		cut := len(s.Months) - l.Months
		earlier := Month{Month: s.Months[0].Month + ".." + s.Months[cut-1].Month}
		for _, m := range s.Months[:cut] {
			earlier.CreditsMinor += m.CreditsMinor
			earlier.DebitsMinor += m.DebitsMinor
		}
		out.Months = append([]Month{earlier}, s.Months[cut:]...)
	}

	if l.DropTransfers {
		out.Transfers = nil
		out.TransfersOmitted = len(s.Transfers) > 0
	} else if l.Transfers > 0 && len(s.Transfers) > l.Transfers {
		out.Transfers = s.Transfers[:l.Transfers]
	}
	if l.Recurring > 0 && len(s.Recurring) > l.Recurring {
		out.Recurring = s.Recurring[:l.Recurring]
	}
	if l.TextRunes > 0 {
		out.Recurring = append([]Recurring(nil), out.Recurring...)
		for i := range out.Recurring {
			out.Recurring[i].Label = truncateRunes(out.Recurring[i].Label, l.TextRunes)
		}
		out.Wallets = append([]Wallet(nil), s.Wallets...)
		for i := range out.Wallets {
			out.Wallets[i].Name = truncateRunes(out.Wallets[i].Name, l.TextRunes)
			out.Wallets[i].Purpose = truncateRunes(out.Wallets[i].Purpose, l.PurposeRunes)
		}
	}

	switch {
	case l.Transactions < 0:
		out.TransactionsOmitted = s.TransactionsOmitted + len(s.Transactions)
		out.Transactions = nil
	case l.Transactions > 0 && len(s.Transactions) > l.Transactions:
		out.TransactionsOmitted = s.TransactionsOmitted + len(s.Transactions) - l.Transactions
		out.Transactions = s.Transactions[:l.Transactions]
	}
	if l.TextRunes > 0 && len(out.Transactions) > 0 {
		out.Transactions = append([]Transaction(nil), out.Transactions...)
		for i := range out.Transactions {
			out.Transactions[i].Title = truncateRunes(out.Transactions[i].Title, l.TextRunes)
			out.Transactions[i].Category = truncateRunes(out.Transactions[i].Category, l.TextRunes)
		}
	}

	if s.Context != nil && l.ContextRunes > 0 {
		c := *s.Context
		c.AboutMe = truncatePtr(c.AboutMe, l.ContextRunes)
		c.Goals = truncatePtr(c.Goals, l.ContextRunes)
		c.IgnoreNotes = truncatePtr(c.IgnoreNotes, l.ContextRunes)
		out.Context = &c
	}
	return out
}

// trimGroups keeps the first n rows and folds the rest (and any existing
// fold row) into one "other" row, so shares still add up.
func trimGroups(groups []Group, n, textRunes int, other string) []Group {
	if len(groups) == 0 {
		return groups
	}
	out := make([]Group, 0, min(len(groups), n+1))
	var rest Group
	hasRest := false
	for i, g := range groups {
		isFold := len(g.Label) > 0 && g.Label[0] == '(' && i == len(groups)-1
		if n > 0 && (i >= n || isFold) {
			rest.AmountMinor += g.AmountMinor
			rest.Count += g.Count
			hasRest = true
			continue
		}
		if !isFold {
			g.Label = truncateRunes(g.Label, textRunes)
		}
		out = append(out, g)
	}
	if hasRest {
		rest.Label = other
		out = append(out, rest)
	}
	return out
}

func truncateRunes(s string, n int) string {
	if n <= 0 || utf8.RuneCountInString(s) <= n {
		return s
	}
	return string([]rune(s)[:n-1]) + "…"
}

func truncatePtr(s *string, n int) *string {
	if s == nil {
		return nil
	}
	t := truncateRunes(*s, n)
	return &t
}
