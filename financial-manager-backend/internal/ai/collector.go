package ai

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/ai/prompt"
	"financial-manager-backend/internal/reports"
	"financial-manager-backend/internal/transactions"
	"financial-manager-backend/internal/wallets"
)

// Data block limits: enough detail for the model, bounded prompt size.
const (
	maxGroupsPerList       = 25
	maxRecurring           = 20
	maxTransferFlows       = 20
	recurringMinMonths     = 3
	recurringStableSpread  = 0.10
	DefaultMaxTransactions = 200
	MaxMaxTransactions     = 500
)

// collectInput is a validated analysis request.
type collectInput struct {
	userID      uuid.UUID
	wallets     []wallets.Wallet
	period      reports.Period
	loc         *time.Location
	lang        prompt.Lang
	sections    map[string]bool
	options     AnalysisOptions
	userContext UserContext
	filter      reports.Filter
	filterInfo  *prompt.Filters
}

// collect queries everything the data block needs. Like the reports
// module, totals count STANDARD transactions (plus balance adjustments
// when asked) and leave transfers out; transfers get their own section.
func (s *Service) collect(ctx context.Context, in collectInput) (prompt.Snapshot, error) {
	walletIDs := make([]uuid.UUID, len(in.wallets))
	for i, w := range in.wallets {
		walletIDs[i] = w.ID
	}
	kinds := []string{transactions.KindStandard}
	if in.options.IncludeAdjustments {
		kinds = append(kinds, transactions.KindBalanceAdjustment)
	}
	from, to := in.period.From, in.period.To

	snap := prompt.Snapshot{
		PeriodFrom: from, PeriodTo: to, Timezone: in.loc.String(), Currency: in.wallets[0].Currency,
	}
	if from != nil {
		localFrom := from.In(in.loc)
		snap.PeriodFrom = &localFrom
	}
	snap.PeriodTo = to.In(in.loc)

	for _, w := range in.wallets {
		pw := prompt.Wallet{Name: w.Name, Type: w.Type, BalanceMinor: w.CurrentBalanceMinor, Archived: w.IsArchived()}
		if w.Purpose != nil {
			pw.Purpose = *w.Purpose
		}
		snap.Wallets = append(snap.Wallets, pw)
	}

	// Every aggregate below honours the Cronologia filters, if any.
	rep := s.reports.WithFilter(in.filter)
	filtered := in.filterInfo != nil
	snap.Filters = in.filterInfo

	totals, err := rep.Totals(ctx, walletIDs, kinds, from, to)
	if err != nil {
		return prompt.Snapshot{}, err
	}
	snap.Totals = prompt.Totals{CreditsMinor: totals.CreditsMinor, DebitsMinor: totals.DebitsMinor, Count: totals.Count}
	if !filtered {
		var opening int64
		if from != nil {
			if opening, err = s.reports.SignedImpact(ctx, walletIDs, nil, from); err != nil {
				return prompt.Snapshot{}, err
			}
			snap.Totals.OpeningMinor = &opening
		}
		impact, err := s.reports.SignedImpact(ctx, walletIDs, from, &to)
		if err != nil {
			return prompt.Snapshot{}, err
		}
		snap.Totals.ClosingMinor = opening + impact
	}

	if in.sections[prompt.SectionMonthly] {
		buckets, err := rep.Buckets(ctx, walletIDs, kinds, from, to, reports.GranularityMonthly, in.loc.String())
		if err != nil {
			return prompt.Snapshot{}, err
		}
		snap.Months = fillMonths(buckets, from, to, in.loc)
	}

	if in.sections[prompt.SectionCategories] {
		if snap.DebitCategories, err = s.groups(ctx, rep, true, walletIDs, transactions.DirectionDebit, kinds, from, to, in.lang); err != nil {
			return prompt.Snapshot{}, err
		}
		if snap.CreditCategories, err = s.groups(ctx, rep, true, walletIDs, transactions.DirectionCredit, kinds, from, to, in.lang); err != nil {
			return prompt.Snapshot{}, err
		}
	}
	if in.sections[prompt.SectionTitles] {
		if snap.DebitTitles, err = s.groups(ctx, rep, false, walletIDs, transactions.DirectionDebit, kinds, from, to, in.lang); err != nil {
			return prompt.Snapshot{}, err
		}
		if snap.CreditTitles, err = s.groups(ctx, rep, false, walletIDs, transactions.DirectionCredit, kinds, from, to, in.lang); err != nil {
			return prompt.Snapshot{}, err
		}
	}

	if in.sections[prompt.SectionTransfers] && !filtered {
		flows, err := s.repo.TransferFlows(ctx, walletIDs, from, to)
		if err != nil {
			return prompt.Snapshot{}, err
		}
		for i, f := range flows {
			if i == maxTransferFlows {
				break
			}
			snap.Transfers = append(snap.Transfers, prompt.TransferFlow{From: f.FromWallet, To: f.ToWallet, AmountMinor: f.AmountMinor, Count: f.Count})
		}
	}

	if in.sections[prompt.SectionRecurring] {
		monthly, err := s.repo.MonthlyDebitsByTitle(ctx, walletIDs, kinds, from, to, in.loc.String(), in.filter)
		if err != nil {
			return prompt.Snapshot{}, err
		}
		snap.Recurring = detectRecurring(monthly)
	}

	if in.options.IncludeTransactions {
		rows, err := s.repo.ListTransactions(ctx, walletIDs, kinds, from, to, in.options.MaxTransactions, in.filter)
		if err != nil {
			return prompt.Snapshot{}, err
		}
		for _, r := range rows {
			t := prompt.Transaction{
				Date: r.OccurredAt.In(in.loc).Format("2006-01-02"), Wallet: r.WalletName,
				Credit: r.Direction == transactions.DirectionCredit, AmountMinor: r.AmountMinor, Title: r.Title,
			}
			if r.Category != nil {
				t.Category = *r.Category
			}
			snap.Transactions = append(snap.Transactions, t)
		}
		if omitted := int(totals.Count) - len(rows); omitted > 0 {
			snap.TransactionsOmitted = omitted
		}
	}

	if in.sections[prompt.SectionPersonalContext] && !in.userContext.IsEmpty() {
		uc := in.userContext
		snap.Context = &prompt.Context{
			HouseholdSize: uc.HouseholdSize, IncomeType: uc.IncomeType, AboutMe: uc.AboutMe,
			Goals: uc.Goals, IgnoreNotes: uc.IgnoreNotes,
		}
	}

	if in.options.AnonymizeTitles {
		anonymize(&snap, in.lang)
	}
	return snap, nil
}

// groups returns a category or title breakdown capped at maxGroupsPerList,
// folding the rest into one "other" row so shares still add up.
func (s *Service) groups(ctx context.Context, rep *reports.Repository, byCategory bool, walletIDs []uuid.UUID, direction string, kinds []string,
	from *time.Time, to time.Time, lang prompt.Lang) ([]prompt.Group, error) {
	var list []reports.BreakdownGroup
	var err error
	if byCategory {
		list, err = rep.BreakdownByCategory(ctx, walletIDs, direction, kinds, from, to)
	} else {
		list, err = rep.BreakdownByTitle(ctx, walletIDs, direction, kinds, from, to)
	}
	if err != nil {
		return nil, err
	}
	out := make([]prompt.Group, 0, min(len(list), maxGroupsPerList+1))
	var rest prompt.Group
	for i, g := range list {
		if i < maxGroupsPerList {
			out = append(out, prompt.Group{Label: g.Label, AmountMinor: g.AmountMinor, Count: g.TransactionCount})
			continue
		}
		rest.AmountMinor += g.AmountMinor
		rest.Count += g.TransactionCount
	}
	if rest.Count > 0 {
		rest.Label = "(altre voci)"
		if lang != prompt.LangIT {
			rest.Label = "(other items)"
		}
		out = append(out, rest)
	}
	return out, nil
}

// fillMonths returns one row per local month from the first month with
// data to the end of the period, zero-filled. Months before the first
// transaction are left out: they usually predate the user's first use of
// the app, and zero rows would read as "spent nothing".
func fillMonths(buckets []reports.Bucket, from *time.Time, to time.Time, loc *time.Location) []prompt.Month {
	if len(buckets) == 0 {
		return nil
	}
	byMonth := map[string]reports.Bucket{}
	for _, b := range buckets {
		byMonth[b.PeriodStart.In(loc).Format("2006-01")] = b
	}
	start := buckets[0].PeriodStart.In(loc)
	if from != nil && from.After(start) {
		start = from.In(loc)
	}
	end := to.Add(-time.Nanosecond).In(loc)
	cursor := time.Date(start.Year(), start.Month(), 1, 0, 0, 0, 0, loc)
	var out []prompt.Month
	for !cursor.After(end) {
		key := cursor.Format("2006-01")
		b := byMonth[key]
		out = append(out, prompt.Month{Month: key, CreditsMinor: b.CreditsMinor, DebitsMinor: b.DebitsMinor})
		cursor = cursor.AddDate(0, 1, 0)
	}
	return out
}

// detectRecurring flags expense items seen in at least recurringMinMonths
// distinct months, ordered by average monthly amount.
func detectRecurring(rows []MonthlyTitleRow) []prompt.Recurring {
	type acc struct {
		label     string
		amounts   []int64
		lastMonth string
		lastMinor int64
	}
	byKey := map[string]*acc{}
	var keys []string
	for _, r := range rows {
		a, ok := byKey[r.Key]
		if !ok {
			a = &acc{}
			byKey[r.Key] = a
			keys = append(keys, r.Key)
		}
		a.amounts = append(a.amounts, r.AmountMinor)
		if r.Month >= a.lastMonth {
			a.lastMonth, a.lastMinor, a.label = r.Month, r.AmountMinor, r.Label
		}
	}

	var out []prompt.Recurring
	for _, k := range keys {
		a := byKey[k]
		if len(a.amounts) < recurringMinMonths {
			continue
		}
		var sum, lo, hi int64 = 0, a.amounts[0], a.amounts[0]
		for _, v := range a.amounts {
			sum += v
			lo, hi = min(lo, v), max(hi, v)
		}
		avg := sum / int64(len(a.amounts))
		stable := avg > 0 && float64(hi-lo)/float64(avg) <= 2*recurringStableSpread
		out = append(out, prompt.Recurring{
			Label: a.label, Months: len(a.amounts), AvgAmountMinor: avg, LastAmountMinor: a.lastMinor,
			LastSeenMonth: a.lastMonth, AmountsVaryLittle: stable,
		})
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].AvgAmountMinor > out[j].AvgAmountMinor })
	if len(out) > maxRecurring {
		out = out[:maxRecurring]
	}
	return out
}

// anonymize replaces transaction titles with stable pseudonyms ("Voce 1"),
// the same title getting the same pseudonym everywhere in the block.
// Categories and wallet names are kept: they are the user's own labels
// and carry the meaning the analysis needs.
func anonymize(s *prompt.Snapshot, lang prompt.Lang) {
	word := "Item"
	if lang == prompt.LangIT {
		word = "Voce"
	}
	names := map[string]string{}
	pseudonym := func(title string) string {
		key := strings.ToLower(strings.Join(strings.Fields(title), " "))
		if p, ok := names[key]; ok {
			return p
		}
		p := fmt.Sprintf("%s %d", word, len(names)+1)
		names[key] = p
		return p
	}
	for _, list := range [][]prompt.Group{s.DebitTitles, s.CreditTitles} {
		for i := range list {
			if !strings.HasPrefix(list[i].Label, "(") {
				list[i].Label = pseudonym(list[i].Label)
			}
		}
	}
	for i := range s.Recurring {
		s.Recurring[i].Label = pseudonym(s.Recurring[i].Label)
	}
	for i := range s.Transactions {
		s.Transactions[i].Title = pseudonym(s.Transactions[i].Title)
	}
}
