package reports

import (
	"strconv"
	"strings"

	"github.com/google/uuid"

	"financial-manager-backend/internal/transactions"
)

// Filter narrows report queries to part of the ledger, with the same
// semantics as the history filters (transactions.ListFilter): used by the
// AI analysis started from Cronologia (plan.md section 32.6). The zero
// Filter matches everything, so the reports endpoints are unaffected.
type Filter struct {
	Direction      string     // DEBIT, CREDIT or "" for both
	CategoryID     *uuid.UUID // nil: any category
	Title          string     // substring of title or description
	AmountMinMinor int64      // 0: no lower bound
	AmountMaxMinor int64      // 0: no upper bound
}

// IsZero reports whether the filter matches every transaction.
func (f Filter) IsZero() bool {
	return f.Direction == "" && f.CategoryID == nil && strings.TrimSpace(f.Title) == "" &&
		f.AmountMinMinor == 0 && f.AmountMaxMinor == 0
}

// SQL returns the filter as extra WHERE conditions (each prefixed with
// " AND ") on columns qualified by alias (e.g. "t." or ""), numbering
// placeholders from firstArg, plus their arguments.
func (f Filter) SQL(alias string, firstArg int) (string, []any) {
	var b strings.Builder
	var args []any
	next := func(v any) string {
		args = append(args, v)
		return "$" + strconv.Itoa(firstArg+len(args)-1)
	}
	if f.Direction != "" {
		b.WriteString(" AND " + alias + "direction = " + next(f.Direction))
	}
	if f.CategoryID != nil {
		b.WriteString(" AND " + alias + "category_id = " + next(*f.CategoryID))
	}
	if title := strings.TrimSpace(f.Title); title != "" {
		p := next(transactions.TitleSearchPattern(title))
		b.WriteString(" AND (" + alias + "title_normalized LIKE " + p + ` ESCAPE '\'` +
			" OR lower(" + alias + "description) LIKE " + p + ` ESCAPE '\')`)
	}
	if f.AmountMinMinor > 0 {
		b.WriteString(" AND " + alias + "amount_minor >= " + next(f.AmountMinMinor))
	}
	if f.AmountMaxMinor > 0 {
		b.WriteString(" AND " + alias + "amount_minor <= " + next(f.AmountMaxMinor))
	}
	return b.String(), args
}

// WithFilter returns a repository whose Totals, Buckets and breakdowns
// only count transactions matching f. SignedImpact is never filtered: it
// computes wallet balances, which a partial view of the ledger can't.
func (r *Repository) WithFilter(f Filter) *Repository {
	return &Repository{db: r.db, filter: f}
}
