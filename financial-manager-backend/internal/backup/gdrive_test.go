package backup

import "testing"

func TestQuoteQuery(t *testing.T) {
	cases := map[string]string{
		"FinancialManager Backups": `'FinancialManager Backups'`,
		"Alex's backups":           `'Alex\'s backups'`,
		`back\slash`:               `'back\slash'`,
	}
	for in, want := range cases {
		if got := quoteQuery(in); got != want {
			t.Errorf("quoteQuery(%q) = %s, want %s", in, got, want)
		}
	}
}
