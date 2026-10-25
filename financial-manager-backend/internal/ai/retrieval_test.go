package ai

import (
	"reflect"
	"testing"
)

func TestSearchTerms(t *testing.T) {
	for _, c := range []struct {
		question string
		want     []string
	}{
		// Stop words and short words go; long words keep a prefix so
		// endings match ("assicurazioni", "macchine").
		{"Mi ricordi quando ho pagato l'assicurazione della macchina?", []string{"assicurazio", "macchi"}},
		// Accents are folded, like the SQL side; four-letter words stay whole.
		{"Quanto spendo di caffè e di auto?", []string{"caff", "auto"}},
		{"Quanto ho speso per la VPS quest'anno?", []string{"vps"}},
		{"When did I pay the car insurance?", []string{"car", "insuran"}},
		// Duplicates once, at most six terms.
		{"benzina benzine benzinaio", []string{"benzi", "benzina"}},
		// ("sei" is a stop word: "you are").
		{"uno due tre quattro cinque sei sette otto nove dieci", []string{"due", "tre", "quatt", "cinq", "sett", "otto"}},
		{"Quando? Quanto?", nil},
		{"", nil},
	} {
		if got := searchTerms(c.question); !reflect.DeepEqual(got, c.want) {
			t.Errorf("searchTerms(%q) = %q, want %q", c.question, got, c.want)
		}
	}
}

func TestFoldAccents(t *testing.T) {
	if got := foldAccents("perché più già così"); got != "perche piu gia cosi" {
		t.Errorf("foldAccents = %q", got)
	}
	if len([]rune(accentFrom)) != len([]rune(accentTo)) {
		t.Fatal("accentFrom and accentTo must have the same length for SQL translate()")
	}
}
