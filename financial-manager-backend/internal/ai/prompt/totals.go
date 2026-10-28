package prompt

import (
	"fmt"
	"strings"
	"time"
)

// Question totals (plan.md section 34.3): small models add up and average
// badly, so every chat question gets, for each of its search words, the
// matching transactions totalled month by month by the server, with the
// monthly averages already worked out. The model only has to quote them.

// MonthTotal is one month of a word's matches; Month is "2006-01".
type MonthTotal struct {
	Month        string
	DebitsMinor  int64
	CreditsMinor int64
	Count        int64
}

// TermTotals are the matches of one search word over the chat's period:
// the months that have any, oldest first.
type TermTotals struct {
	Term   string
	Months []MonthTotal
}

// TotalsPeriod is where the totals end: the last day with data (the
// period's end, or today for a period still running), in the chat's
// time zone.
type TotalsPeriod struct {
	LastDay time.Time
}

// maxTotalsMonths bounds a word's month table; the totals and averages
// still cover every month.
const maxTotalsMonths = 24

// RenderQuestionTotals is the totals block of a chat question; "" without
// words.
func RenderQuestionTotals(lang Lang, terms []TermTotals, period TotalsPeriod) string {
	if len(terms) == 0 {
		return ""
	}
	l := labelsFor(normalizeLang(lang))
	lines := []string{"<financial_data>", l.questionTotalsHeading, l.questionTotalsNote}
	lastMonth := period.LastDay.Format("2006-01")
	partial := period.LastDay.AddDate(0, 0, 1).Day() != 1
	for _, t := range terms {
		word := `"` + clean(t.Term) + `"`
		lines = append(lines, "", fmt.Sprintf(l.questionTotalsWord, word))
		if len(t.Months) == 0 {
			lines = append(lines, fmt.Sprintf(l.questionTotalsNone, word))
			continue
		}
		months := fillMonths(t.Months, lastMonth)
		var debits, credits, count int64
		var debitMonths, creditMonths int
		for _, m := range months {
			debits += m.DebitsMinor
			credits += m.CreditsMinor
			count += m.Count
			if m.DebitsMinor > 0 {
				debitMonths++
			}
			if m.CreditsMinor > 0 {
				creditMonths++
			}
		}
		shown := months
		if len(shown) > maxTotalsMonths {
			shown = shown[len(shown)-maxTotalsMonths:]
			lines = append(lines, fmt.Sprintf(l.questionTotalsLastMonths, maxTotalsMonths))
		}
		lines = append(lines, l.questionTotalsColumns)
		for _, m := range shown {
			lines = append(lines, strings.Join([]string{m.Month, money(m.DebitsMinor), money(m.CreditsMinor), fmt.Sprint(m.Count)}, " | "))
		}
		lines = append(lines, fmt.Sprintf(l.questionTotalsSum, money(debits), money(credits), count))
		first := months[0].Month
		if n := len(months); n > 1 {
			if debits > 0 {
				lines = append(lines, fmt.Sprintf(l.questionTotalsDebitAverage,
					money(average(debits, n)), n, first, lastMonth, debitMonths, money(average(debits, debitMonths))))
			}
			if credits > 0 {
				lines = append(lines, fmt.Sprintf(l.questionTotalsCreditAverage,
					money(average(credits, n)), n, first, lastMonth, creditMonths, money(average(credits, creditMonths))))
			}
		}
		if partial {
			lines = append(lines, fmt.Sprintf(l.questionTotalsPartial, lastMonth, period.LastDay.Format("2006-01-02")))
		}
	}
	return strings.Join(append(lines, "</financial_data>"), "\n")
}

// fillMonths lists every month from the first with matches to last,
// those without any as zero.
func fillMonths(rows []MonthTotal, last string) []MonthTotal {
	byMonth := make(map[string]MonthTotal, len(rows))
	for _, r := range rows {
		byMonth[r.Month] = r
	}
	start, err := time.Parse("2006-01", rows[0].Month)
	if err != nil {
		return rows
	}
	var out []MonthTotal
	for m := start; m.Format("2006-01") <= last; m = m.AddDate(0, 1, 0) {
		key := m.Format("2006-01")
		r, ok := byMonth[key]
		if !ok {
			r = MonthTotal{Month: key}
		}
		out = append(out, r)
	}
	if len(out) == 0 {
		return rows
	}
	return out
}

// average is total/n rounded to the cent, halves away from zero.
func average(total int64, n int) int64 {
	if n <= 0 {
		return 0
	}
	return (total + int64(n)/2) / int64(n)
}
