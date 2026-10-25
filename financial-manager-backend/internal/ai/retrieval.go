package ai

import (
	"context"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/google/uuid"

	"financial-manager-backend/internal/ai/prompt"
	"financial-manager-backend/internal/transactions"
)

// Chat search (plan.md section 34.3): when a chat's transaction list had to
// be cut, each question gets the earlier transactions whose title or
// category contains one of its words. Deliberately simple and
// deterministic: words, minus common ones, folded and cut to a prefix so
// that plurals and other endings match ("macchina" finds "macchine").
const (
	maxSearchTerms       = 6
	minSearchTermRunes   = 3
	chatMatchesStandard  = 150
	chatMatchesCompact   = 40
	searchPrefixMinRunes = 4
)

// stopWords are dropped from questions: articles, prepositions, question
// words and verbs that say nothing about what was paid (Italian, English).
var stopWords = map[string]bool{}

func init() {
	for _, w := range strings.Fields(`
		il lo la le gli un uno una di da in con su per tra fra che chi cui non piu mi ti si ci vi ne
		ho hai ha abbiamo avete hanno sono sei era erano stato stata stati essere avere
		quando quanto quanta quanti quante come dove cosa perche quale quali quest questo questa
		questi queste quello quella quelli quelle mio mia miei mie tuo tua tuoi tue suo sua suoi sue
		del dello della dei degli delle al allo alla ai agli alle dal dallo dalla dai dagli dalle
		nel nello nella nei negli nelle sul sullo sulla sui sugli sulle col coi
		ricordi ricordami dimmi sai puoi potresti volevo vorrei sapere fatto fatta fatti fatte
		pagato pagata pagati pagate pagare pago paghiamo speso spendo spendere comprato comprata
		acquistato acquistata volta volte ultima ultimo ultimi ultime anno anni mese mesi giorno
		giorni settimana settimane tutto tutti tutte totale circa elenco lista
		the and for with but that what when how much many where which who whom whose did does
		was were have has had are you your yours mine paid pay pays spent spend spends bought buy
		last first year years month months week weeks day days all total remind tell list about
		from into this these those there their them they our ours can could would should`) {
		stopWords[w] = true
	}
}

// foldAccents maps accented Latin letters to plain ones, as the SQL side
// does with accentFrom/accentTo.
func foldAccents(s string) string {
	from, to := []rune(accentFrom), []rune(accentTo)
	return strings.Map(func(r rune) rune {
		for i, f := range from {
			if r == f {
				return to[i]
			}
		}
		return r
	}, s)
}

// searchTerms turns a question into at most maxSearchTerms search terms:
// lowercase words of letters, accents folded, stop words and words shorter
// than minSearchTermRunes dropped, duplicates removed, each cut to a prefix
// (two letters shorter, at least searchPrefixMinRunes).
func searchTerms(question string) []string {
	words := strings.FieldsFunc(foldAccents(strings.ToLower(question)), func(r rune) bool { return !unicode.IsLetter(r) })
	seen := map[string]bool{}
	var out []string
	for _, w := range words {
		n := utf8.RuneCountInString(w)
		if n < minSearchTermRunes || stopWords[w] {
			continue
		}
		if keep := max(searchPrefixMinRunes, n-2); keep < n {
			w = string([]rune(w)[:keep])
		}
		if seen[w] {
			continue
		}
		seen[w] = true
		out = append(out, w)
		if len(out) == maxSearchTerms {
			break
		}
	}
	return out
}

// chatSearch is where a chat's question is searched: the chat's wallets,
// kinds and period start, before the oldest transaction of its list.
type chatSearch struct {
	walletIDs []uuid.UUID
	kinds     []string
	from      *time.Time
	before    time.Time
	loc       *time.Location
	limit     int
}

// chatMatchLimit is how many matching transactions a question may carry.
func chatMatchLimit(profile string) int {
	if profile == prompt.ProfileCompact {
		return chatMatchesCompact
	}
	return chatMatchesStandard
}

// chatKinds are the transaction kinds a chat reads, as the collector.
func chatKinds(opts AnalysisOptions) []string {
	kinds := []string{transactions.KindStandard}
	if opts.IncludeAdjustments {
		kinds = append(kinds, transactions.KindBalanceAdjustment)
	}
	return kinds
}

// chatAttachment searches the question's terms and renders what is found;
// "" when the question has no searchable word.
func (s *Service) chatAttachment(ctx context.Context, cs chatSearch, question string, lang prompt.Lang) (string, error) {
	terms := searchTerms(question)
	if len(terms) == 0 {
		return "", nil
	}
	rows, total, err := s.repo.SearchTransactions(ctx, cs.walletIDs, cs.kinds, cs.from, cs.before, terms, cs.limit)
	if err != nil {
		return "", err
	}
	matches := make([]prompt.Transaction, len(rows))
	for i, r := range rows {
		matches[i] = toPromptTransaction(r, cs.loc)
	}
	return prompt.RenderMatches(lang, terms, matches, total), nil
}

// toPromptTransaction is a listed transaction as the data block shows it.
func toPromptTransaction(r TransactionRow, loc *time.Location) prompt.Transaction {
	t := prompt.Transaction{
		Date: r.OccurredAt.In(loc).Format("2006-01-02"), Wallet: r.WalletName,
		Credit: r.Direction == transactions.DirectionCredit, AmountMinor: r.AmountMinor, Title: r.Title, At: r.OccurredAt,
	}
	if r.Category != nil {
		t.Category = *r.Category
	}
	return t
}

// followUpAttachment is the attachment of a new question on a chat whose
// list was cut; nil otherwise.
func (s *Service) followUpAttachment(ctx context.Context, a Analysis, question string, lang prompt.Lang) (*string, error) {
	if a.Preset != prompt.PresetChat || a.Options.LedgerCutoff == nil {
		return nil, nil
	}
	loc, err := time.LoadLocation(a.Timezone)
	if err != nil {
		loc = time.UTC
	}
	att, err := s.chatAttachment(ctx, chatSearch{
		walletIDs: a.WalletIDs, kinds: chatKinds(a.Options), from: a.PeriodFrom, before: *a.Options.LedgerCutoff,
		loc: loc, limit: chatMatchLimit(a.Options.Profile),
	}, question, lang)
	if err != nil || att == "" {
		return nil, err
	}
	return &att, nil
}
