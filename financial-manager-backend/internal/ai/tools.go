package ai

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"strings"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/ai/prompt"
	"financial-manager-backend/internal/ai/provider"
	"financial-manager-backend/internal/transactions"
)

// Tools of a cloud chat (plan.md section 34.7): the model may search and
// total the user's transactions before it answers. Every call is limited
// to the chat's own wallets, kinds and period; arguments are validated and
// a bad one goes back to the model as a message, never as a failure.
const (
	toolSearch       = "search_transactions"
	toolSum          = "sum_transactions"
	maxToolRounds    = 4
	toolDefaultLimit = 20
	toolMaxLimit     = 50
)

// toolFilterSchema is the filters both tools take.
const toolFilterSchema = `
	"query": {"type": "string", "description": "Words to find in the transaction titles and categories, for example \"assicurazione auto\". Use the words the user would have written; leave it out to filter by the other fields only."},
	"from": {"type": "string", "description": "First day included, YYYY-MM-DD."},
	"to": {"type": "string", "description": "Last day included, YYYY-MM-DD."},
	"direction": {"type": "string", "enum": ["DEBIT", "CREDIT"], "description": "DEBIT for expenses, CREDIT for income; leave it out for both."},
	"min_amount": {"type": "number", "description": "Smallest amount, in the account currency (for example 50 or 12.5)."},
	"max_amount": {"type": "number", "description": "Largest amount, in the account currency."}`

// chatTools are the tools offered to a cloud chat.
func chatTools() []provider.Tool {
	return []provider.Tool{
		{
			Name: toolSearch,
			Description: "Search the user's transactions (all of the chat's history, also those not in the list you were given). " +
				"Returns the matching transactions, newest first, with date, wallet, type, amount, title and category, and how many match in all.",
			Schema: json.RawMessage(`{"type": "object", "properties": {` + toolFilterSchema + `,
				"limit": {"type": "integer", "description": "How many transactions to return: at most 50, 20 if left out."}}}`),
		},
		{
			Name: toolSum,
			Description: "Total the user's transactions matching the filters, expenses and income separately, " +
				"overall or grouped by month, category or title. Use it for questions like \"how much do I spend on fuel per month\".",
			Schema: json.RawMessage(`{"type": "object", "properties": {` + toolFilterSchema + `,
				"group_by": {"type": "string", "enum": ["none", "month", "category", "title"], "description": "How to group the totals; none if left out."}}}`),
		},
	}
}

// toolArgs are the arguments of either tool.
type toolArgs struct {
	Query     string   `json:"query"`
	From      string   `json:"from"`
	To        string   `json:"to"`
	Direction string   `json:"direction"`
	MinAmount *float64 `json:"min_amount"`
	MaxAmount *float64 `json:"max_amount"`
	Limit     int      `json:"limit"`
	GroupBy   string   `json:"group_by"`
}

// toolRunner runs the tools of one chat.
type toolRunner struct {
	repo      *Repository
	walletIDs []uuid.UUID
	kinds     []string
	from      *time.Time
	to        time.Time
	loc       *time.Location
	lang      prompt.Lang
}

// newToolRunner scopes the tools to analysis a: its wallets, kinds and
// period, read in its timezone.
func (s *Service) newToolRunner(a Analysis, lang prompt.Lang) *toolRunner {
	loc, err := time.LoadLocation(a.Timezone)
	if err != nil {
		loc = time.UTC
	}
	return &toolRunner{
		repo: s.repo, walletIDs: a.WalletIDs, kinds: chatKinds(a.Options), from: a.PeriodFrom, to: a.PeriodTo,
		loc: loc, lang: lang,
	}
}

// run executes one call and returns what goes back to the model and how
// many rows it carried. Only a database failure is an error.
func (r *toolRunner) run(ctx context.Context, call provider.ToolCall) (string, int, error) {
	var args toolArgs
	if err := json.Unmarshal(call.Args, &args); err != nil {
		return prompt.RenderToolError(r.lang, "the arguments are not a JSON object"), 0, nil
	}
	q, problem := r.search(args)
	if problem != "" {
		return prompt.RenderToolError(r.lang, problem), 0, nil
	}
	switch call.Name {
	case toolSearch:
		limit := args.Limit
		if limit <= 0 {
			limit = toolDefaultLimit
		}
		rows, total, err := r.repo.SearchTransactions(ctx, q, min(limit, toolMaxLimit))
		if err != nil {
			return "", 0, err
		}
		shown := make([]prompt.Transaction, len(rows))
		for i, row := range rows {
			shown[i] = toPromptTransaction(row, r.loc)
		}
		return prompt.RenderToolTransactions(r.lang, shown, total), len(rows), nil
	case toolSum:
		group := args.GroupBy
		if group == "" {
			group = GroupNone
		}
		if group != GroupNone && group != GroupMonth && group != GroupCategory && group != GroupTitle {
			return prompt.RenderToolError(r.lang, "group_by must be none, month, category or title"), 0, nil
		}
		rows, err := r.repo.SumTransactions(ctx, q, group, r.loc.String())
		if err != nil {
			return "", 0, err
		}
		groups := make([]prompt.SumGroup, 0, len(rows))
		for _, row := range rows {
			if row.Count == 0 {
				continue // the overall total of nothing
			}
			groups = append(groups, prompt.SumGroup{
				Label: row.Label, DebitsMinor: row.DebitsMinor, CreditsMinor: row.CreditsMinor, Count: row.Count,
			})
		}
		return prompt.RenderToolSums(r.lang, groups), len(groups), nil
	}
	return prompt.RenderToolError(r.lang, fmt.Sprintf("unknown tool %q", call.Name)), 0, nil
}

// search turns validated arguments into a search within the chat's scope;
// problem says what is wrong otherwise.
func (r *toolRunner) search(a toolArgs) (TransactionSearch, string) {
	q := TransactionSearch{WalletIDs: r.walletIDs, Kinds: r.kinds, From: r.from, Before: r.to}
	day := func(raw string) (time.Time, bool) {
		t, err := time.ParseInLocation("2006-01-02", strings.TrimSpace(raw), r.loc)
		return t, err == nil
	}
	if a.From != "" {
		from, ok := day(a.From)
		if !ok {
			return q, "from must be a date as YYYY-MM-DD"
		}
		if q.From == nil || from.After(*q.From) {
			q.From = &from
		}
	}
	if a.To != "" {
		to, ok := day(a.To)
		if !ok {
			return q, "to must be a date as YYYY-MM-DD"
		}
		if end := to.AddDate(0, 0, 1); end.Before(q.Before) {
			q.Before = end
		}
	}
	switch a.Direction {
	case "", transactions.DirectionDebit, transactions.DirectionCredit:
		q.Direction = a.Direction
	default:
		return q, "direction must be DEBIT or CREDIT"
	}
	minor := func(v *float64) (int64, bool) {
		if v == nil {
			return 0, true
		}
		if *v < 0 || *v > 1e9 || math.IsNaN(*v) {
			return 0, false
		}
		return int64(math.Round(*v * 100)), true
	}
	var ok bool
	if q.MinMinor, ok = minor(a.MinAmount); !ok {
		return q, "min_amount must be a positive amount"
	}
	if q.MaxMinor, ok = minor(a.MaxAmount); !ok {
		return q, "max_amount must be a positive amount"
	}
	if a.Limit < 0 || a.Limit > toolMaxLimit {
		return q, fmt.Sprintf("limit must be between 1 and %d", toolMaxLimit)
	}
	if strings.TrimSpace(a.Query) != "" {
		if q.Terms = searchTerms(a.Query); len(q.Terms) == 0 {
			return q, "the query has no word to search for"
		}
	}
	return q, ""
}
