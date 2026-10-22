package reports

import (
	"strings"
	"testing"

	"github.com/google/uuid"
)

func TestFilterSQL(t *testing.T) {
	if sql, args := (Filter{}).SQL("t.", 6); sql != "" || len(args) != 0 {
		t.Fatalf("zero filter = %q %v", sql, args)
	}
	if !(Filter{Title: "  "}).IsZero() {
		t.Fatal("a blank title is no filter")
	}

	cat := uuid.New()
	sql, args := Filter{
		Direction: "DEBIT", CategoryID: &cat, Title: "Canone_SIM", AmountMinMinor: 100, AmountMaxMinor: 5000,
	}.SQL("t.", 6)
	want := []string{
		" AND t.direction = $6",
		" AND t.category_id = $7",
		" AND (t.title_normalized LIKE $8 ESCAPE '\\' OR lower(t.description) LIKE $8 ESCAPE '\\')",
		" AND t.amount_minor >= $9",
		" AND t.amount_minor <= $10",
	}
	if sql != strings.Join(want, "") {
		t.Fatalf("sql = %q", sql)
	}
	if len(args) != 5 || args[0] != "DEBIT" || args[1] != cat || args[3] != int64(100) {
		t.Fatalf("args = %v", args)
	}
	if pattern := args[2].(string); !strings.HasPrefix(pattern, "%") || !strings.Contains(pattern, `\_`) {
		t.Fatalf("title pattern must be escaped and unanchored: %q", pattern)
	}
}
