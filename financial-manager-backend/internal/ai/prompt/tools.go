package prompt

import (
	"fmt"
	"strings"
)

// Tool results (plan.md section 34.7) are data like the data block: they
// go back to the model inside <financial_data>, so the injection guard
// covers them, with the data block's columns and number format.

// SumGroup is one row of a grouped total.
type SumGroup struct {
	Label        string // "" for the overall total or no category
	DebitsMinor  int64
	CreditsMinor int64
	Count        int64
}

// RenderToolTransactions is the result of a transaction search: the rows
// shown and how many matched in all.
func RenderToolTransactions(lang Lang, rows []Transaction, total int) string {
	l := labelsFor(normalizeLang(lang))
	if len(rows) == 0 {
		return wrapData(l.toolNone)
	}
	lines := []string{fmt.Sprintf(l.toolFound, total, len(rows)), l.transactionsColumns}
	for _, t := range rows {
		lines = append(lines, transactionRow(l, t))
	}
	return wrapData(lines...)
}

// RenderToolSums is the result of a grouped total.
func RenderToolSums(lang Lang, rows []SumGroup) string {
	l := labelsFor(normalizeLang(lang))
	if len(rows) == 0 {
		return wrapData(l.toolNone)
	}
	lines := []string{l.sumColumns}
	for _, g := range rows {
		label := clean(g.Label)
		if label == "" {
			label = l.sumNoLabel
		}
		lines = append(lines, strings.Join([]string{label, money(g.DebitsMinor), money(g.CreditsMinor), fmt.Sprint(g.Count)}, " | "))
	}
	return wrapData(lines...)
}

// RenderToolError tells the model a call couldn't run, and why.
func RenderToolError(lang Lang, reason string) string {
	return fmt.Sprintf(labelsFor(normalizeLang(lang)).toolError, clean(reason))
}

func wrapData(lines ...string) string {
	return "<financial_data>\n" + strings.Join(lines, "\n") + "\n</financial_data>"
}
