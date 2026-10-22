// Package prompt builds what the AI analysis sends to the model (plan.md
// section 32.6): a system prompt with the rules and the report structure, the
// user's instructions, and a data block rendered from an aggregated Snapshot.
//
// Everything here is a pure function of its input, so the preview the user
// sees is byte for byte what is sent, and golden tests pin the output.
// Templates are embedded and versioned: a change to their wording is a new
// Version, so stored analyses keep replaying the prompt they were made with.
package prompt

import (
	"crypto/sha256"
	"embed"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math"
	"strings"
	"text/template"
	"time"
	"unicode/utf8"
)

// Version identifies the templates below; it is stored with every analysis.
const Version = "v1"

//go:embed templates
var templatesFS embed.FS

// Lang is the language of the prompt and of the expected answer.
type Lang string

const (
	LangIT Lang = "it"
	LangEN Lang = "en"
)

// LangFor maps a user locale ("it-IT", "en-US") to a prompt language.
func LangFor(locale string) Lang {
	if strings.HasPrefix(strings.ToLower(locale), "it") {
		return LangIT
	}
	return LangEN
}

// Presets.
const (
	PresetMonthlyCheckup = "MONTHLY_CHECKUP"
	PresetAnomalies      = "ANOMALIES"
	PresetSavings        = "SAVINGS"
	PresetRecurring      = "RECURRING"
	PresetWalletPurpose  = "WALLET_PURPOSE"
	PresetCustom         = "CUSTOM"
)

// PresetOrder is the order presets are offered in.
var PresetOrder = []string{
	PresetMonthlyCheckup, PresetAnomalies, PresetSavings, PresetRecurring, PresetWalletPurpose, PresetCustom,
}

// Optional data sections. Period, wallets and totals are always included.
const (
	SectionMonthly         = "monthly"
	SectionCategories      = "categories"
	SectionTitles          = "titles"
	SectionTransfers       = "transfers"
	SectionRecurring       = "recurring"
	SectionPersonalContext = "personal_context"
)

// AllSections lists every optional section in rendering order.
var AllSections = []string{
	SectionMonthly, SectionCategories, SectionTitles, SectionTransfers, SectionRecurring, SectionPersonalContext,
}

// IsValidSection reports whether s is an optional section.
func IsValidSection(s string) bool {
	for _, v := range AllSections {
		if v == s {
			return true
		}
	}
	return false
}

// PresetDefaults is the data each preset needs, used to prefill the setup
// screen.
type PresetDefaults struct {
	Sections            []string
	IncludeTransactions bool
	PeriodPreset        string // one of the reports period presets
}

var presetDefaults = map[string]PresetDefaults{
	PresetMonthlyCheckup: {Sections: []string{SectionMonthly, SectionCategories, SectionTitles, SectionTransfers, SectionRecurring, SectionPersonalContext}, PeriodPreset: "last_12_months"},
	PresetAnomalies:      {Sections: []string{SectionMonthly, SectionCategories, SectionTitles, SectionPersonalContext}, IncludeTransactions: true, PeriodPreset: "last_12_months"},
	PresetSavings:        {Sections: []string{SectionMonthly, SectionCategories, SectionTitles, SectionRecurring, SectionPersonalContext}, PeriodPreset: "last_12_months"},
	PresetRecurring:      {Sections: []string{SectionMonthly, SectionTitles, SectionRecurring, SectionPersonalContext}, PeriodPreset: "last_12_months"},
	PresetWalletPurpose:  {Sections: []string{SectionCategories, SectionTitles, SectionTransfers, SectionPersonalContext}, PeriodPreset: "last_12_months"},
	PresetCustom:         {Sections: AllSections, PeriodPreset: "last_12_months"},
}

// Preset is a preset's localized text plus its defaults.
type Preset struct {
	ID           string
	Title        string
	Description  string
	Headings     []string
	Instructions string
	Defaults     PresetDefaults
}

type presetText struct {
	Title        string   `json:"title"`
	Description  string   `json:"description"`
	Headings     []string `json:"headings"`
	Instructions string   `json:"instructions"`
}

type langTemplates struct {
	system  *template.Template
	compact *template.Template // shorter rules for the compact profile
	presets map[string]presetText
}

// parseTemplate reads an embedded template, normalizing line endings: a
// Windows checkout (core.autocrlf) gives the files CRLF, and prompts must
// not depend on where the binary was built.
func parseTemplate(path string) *template.Template {
	raw, err := templatesFS.ReadFile(path)
	if err != nil {
		panic(err)
	}
	return template.Must(template.New(path).Funcs(template.FuncMap{"join": strings.Join}).
		Parse(strings.ReplaceAll(string(raw), "\r\n", "\n")))
}

var loaded = map[Lang]langTemplates{}

func init() {
	for _, lang := range []Lang{LangIT, LangEN} {
		dir := "templates/" + Version + "/" + string(lang) + "/"
		raw, err := templatesFS.ReadFile(dir + "presets.json")
		if err != nil {
			panic(err)
		}
		var presets map[string]presetText
		if err := json.Unmarshal(raw, &presets); err != nil {
			panic(fmt.Sprintf("prompt: %s presets.json: %v", lang, err))
		}
		for _, id := range PresetOrder {
			if _, ok := presets[id]; !ok {
				panic(fmt.Sprintf("prompt: %s presets.json lacks %s", lang, id))
			}
		}
		loaded[lang] = langTemplates{
			system: parseTemplate(dir + "system.tmpl"), compact: parseTemplate(dir + "system_compact.tmpl"), presets: presets,
		}
	}
}

// IsValidPreset reports whether id is a known preset.
func IsValidPreset(id string) bool {
	_, ok := presetDefaults[id]
	return ok
}

// Presets returns every preset in PresetOrder, localized.
func Presets(lang Lang) []Preset {
	out := make([]Preset, 0, len(PresetOrder))
	for _, id := range PresetOrder {
		p, _ := PresetFor(lang, id)
		out = append(out, p)
	}
	return out
}

// PresetFor returns one localized preset.
func PresetFor(lang Lang, id string) (Preset, bool) {
	defaults, ok := presetDefaults[id]
	if !ok {
		return Preset{}, false
	}
	t := loaded[normalizeLang(lang)].presets[id]
	return Preset{
		ID: id, Title: t.Title, Description: t.Description, Headings: t.Headings,
		Instructions: t.Instructions, Defaults: defaults,
	}, true
}

func normalizeLang(lang Lang) Lang {
	if lang == LangIT {
		return LangIT
	}
	return LangEN
}

// BuildInput is everything that shapes the prompt except the editable
// instructions.
type BuildInput struct {
	Lang     Lang
	Preset   string
	Style    string // CONCISE, DETAILED or "" for the model's default
	Sections []string
	Snapshot Snapshot
	// Profile selects the system prompt: standard, or the shorter compact
	// rules for small on-device models. The data limits of a profile are
	// applied by Trim before Build.
	Profile string
}

// Prompt is the built prompt. Instructions are not part of it: the user
// edits them and they are combined with DataBlock by UserMessage.
type Prompt struct {
	Version   string
	System    string
	DataBlock string
	// Fingerprint identifies the system prompt and data block, so a run
	// can check it sends what the user previewed.
	Fingerprint string
}

// Build renders the system prompt and the data block.
func Build(in BuildInput) (Prompt, error) {
	lang := normalizeLang(in.Lang)
	preset, ok := PresetFor(lang, in.Preset)
	if !ok {
		return Prompt{}, fmt.Errorf("prompt: unknown preset %q", in.Preset)
	}

	tmpl := loaded[lang].system
	if in.Profile == ProfileCompact {
		tmpl = loaded[lang].compact
	}
	var system strings.Builder
	err := tmpl.Execute(&system, struct {
		Style    string
		Headings []string
	}{Style: in.Style, Headings: preset.Headings})
	if err != nil {
		return Prompt{}, fmt.Errorf("prompt: render system: %w", err)
	}

	sections := map[string]bool{}
	for _, s := range in.Sections {
		sections[s] = true
	}
	data := renderData(labelsFor(lang), in.Snapshot, sections)

	sum := sha256.Sum256([]byte(Version + "\x00" + system.String() + "\x00" + data))
	return Prompt{
		Version: Version, System: strings.TrimSpace(system.String()), DataBlock: data,
		Fingerprint: hex.EncodeToString(sum[:]),
	}, nil
}

// UserMessage is the first user message: the instructions followed by the
// data block.
func UserMessage(instructions, dataBlock string) string {
	return strings.TrimSpace(instructions) + "\n\n" + dataBlock
}

// EstimateTokens is a deliberately rough estimate (about 3.5 characters
// per token for Italian and English mixed with numbers); the UI labels it
// as an estimate and the provider reports the real count afterwards.
func EstimateTokens(texts ...string) int {
	runes := 0
	for _, t := range texts {
		runes += utf8.RuneCountInString(t)
	}
	return int(math.Ceil(float64(runes) / 3.5))
}

// --- Data block ---------------------------------------------------------------

func renderData(l labels, s Snapshot, sections map[string]bool) string {
	var b strings.Builder
	linef := func(format string, args ...any) {
		fmt.Fprintf(&b, format, args...)
		b.WriteByte('\n')
	}
	text := func(s string) {
		b.WriteString(s)
		b.WriteByte('\n')
	}
	row := func(cells ...string) { text(strings.Join(cells, " | ")) }

	b.WriteString("<financial_data>\n")

	text(l.periodHeading)
	to := s.PeriodTo.Add(-time.Nanosecond).Format("2006-01-02")
	if s.PeriodFrom != nil {
		linef(l.periodFrom, s.PeriodFrom.Format("2006-01-02"), to)
	} else {
		linef(l.periodWholeHistory, to)
	}
	linef(l.periodNote, s.Timezone, s.Currency)

	if f := s.Filters; f != nil {
		text("")
		text(l.filtersHeading)
		text(l.filtersNote)
		switch f.Direction {
		case "DEBIT":
			text("- " + l.filterDebit)
		case "CREDIT":
			text("- " + l.filterCredit)
		}
		if f.Category != "" {
			linef("- "+l.filterCategory, clean(f.Category))
		}
		if f.Title != "" {
			linef("- "+l.filterTitle, clean(f.Title))
		}
		if f.AmountMinMinor > 0 {
			linef("- "+l.filterAmountFrom, money(f.AmountMinMinor))
		}
		if f.AmountMaxMinor > 0 {
			linef("- "+l.filterAmountTo, money(f.AmountMaxMinor))
		}
	}

	text("")
	text(l.walletsHeading)
	if len(s.Wallets) == 0 {
		text(l.noData)
	} else {
		text(l.walletColumns)
		for _, w := range s.Wallets {
			name := clean(w.Name)
			if w.Archived {
				name += l.archived
			}
			purpose := l.noPurpose
			if w.Purpose != "" {
				purpose = clean(w.Purpose)
			}
			wType := l.walletTypes[w.Type]
			if wType == "" {
				wType = w.Type
			}
			row(name, wType, purpose, money(w.BalanceMinor))
		}
	}

	text("")
	text(l.totalsHeading)
	text(l.totalsColumns)
	savings := l.savingsRateNA
	if s.Totals.CreditsMinor > 0 {
		savings = percent(s.Totals.CreditsMinor-s.Totals.DebitsMinor, s.Totals.CreditsMinor)
	}
	row(money(s.Totals.CreditsMinor), money(s.Totals.DebitsMinor), money(s.Totals.CreditsMinor-s.Totals.DebitsMinor),
		fmt.Sprint(s.Totals.Count), savings)
	if s.Filters != nil {
		text(l.filteredBalances)
	} else {
		text(l.balancesColumns)
		opening := l.savingsRateNA
		if s.Totals.OpeningMinor != nil {
			opening = money(*s.Totals.OpeningMinor)
		}
		row(opening, money(s.Totals.ClosingMinor))
	}

	if sections[SectionMonthly] {
		text("")
		text(l.monthsHeading)
		if len(s.Months) == 0 {
			text(l.noData)
		} else {
			text(l.monthsColumns)
			for _, m := range s.Months {
				row(m.Month, money(m.CreditsMinor), money(m.DebitsMinor), money(m.CreditsMinor-m.DebitsMinor))
			}
		}
	}

	groups := func(heading, columns string, list []Group, total int64) {
		text("")
		text(heading)
		if len(list) == 0 {
			text(l.noData)
			return
		}
		text(columns)
		for _, g := range list {
			row(clean(g.Label), money(g.AmountMinor), percent(g.AmountMinor, total), fmt.Sprint(g.Count))
		}
	}
	if sections[SectionCategories] {
		groups(l.debitCategoriesHeading, l.groupColumnsCategory, s.DebitCategories, s.Totals.DebitsMinor)
		groups(l.creditCategoriesHeading, l.groupColumnsCategory, s.CreditCategories, s.Totals.CreditsMinor)
	}
	if sections[SectionTitles] {
		groups(l.debitTitlesHeading, l.groupColumnsTitle, s.DebitTitles, s.Totals.DebitsMinor)
		if s.CreditTitlesOmitted {
			text("")
			text(l.creditTitlesHeading)
			text(l.omittedForBrevity)
		} else {
			groups(l.creditTitlesHeading, l.groupColumnsTitle, s.CreditTitles, s.Totals.CreditsMinor)
		}
	}

	if sections[SectionTransfers] {
		text("")
		text(l.transfersHeading)
		text(l.transfersNote)
		if s.Filters != nil {
			text(l.filteredTransfers)
		} else if s.TransfersOmitted {
			text(l.omittedForBrevity)
		} else if len(s.Transfers) == 0 {
			text(l.noData)
		} else {
			text(l.transfersColumns)
			for _, t := range s.Transfers {
				row(clean(t.From), clean(t.To), money(t.AmountMinor), fmt.Sprint(t.Count))
			}
		}
	}

	if sections[SectionRecurring] {
		text("")
		text(l.recurringHeading)
		text(l.recurringNote)
		if len(s.Recurring) == 0 {
			text(l.noData)
		} else {
			text(l.recurringColumns)
			for _, r := range s.Recurring {
				stable := l.no
				if r.AmountsVaryLittle {
					stable = l.yes
				}
				row(clean(r.Label), fmt.Sprint(r.Months), money(r.AvgAmountMinor), money(r.LastAmountMinor), r.LastSeenMonth, stable)
			}
		}
	}

	if len(s.Transactions) > 0 {
		text("")
		text(l.transactionsHeading)
		text(l.transactionsColumns)
		for _, t := range s.Transactions {
			kind := l.debit
			if t.Credit {
				kind = l.credit
			}
			category := l.uncategorized
			if t.Category != "" {
				category = clean(t.Category)
			}
			row(t.Date, clean(t.Wallet), kind, money(t.AmountMinor), clean(t.Title), category)
		}
		if s.TransactionsOmitted > 0 {
			linef(l.transactionsOmitted, s.TransactionsOmitted)
		}
	}

	b.WriteString("</financial_data>")

	if sections[SectionPersonalContext] && s.Context != nil {
		if ctx := renderContext(l, *s.Context); ctx != "" {
			b.WriteString("\n\n<user_context>\n")
			b.WriteString(ctx)
			b.WriteString("</user_context>")
		}
	}
	return b.String()
}

func renderContext(l labels, c Context) string {
	var b strings.Builder
	if c.HouseholdSize != nil {
		fmt.Fprintf(&b, l.contextHousehold+"\n", *c.HouseholdSize)
	}
	if c.IncomeType != nil {
		label := l.incomeTypes[*c.IncomeType]
		if label == "" {
			label = *c.IncomeType
		}
		fmt.Fprintf(&b, l.contextIncome+"\n", label)
	}
	for _, f := range []struct {
		format string
		value  *string
	}{{l.contextAboutMe, c.AboutMe}, {l.contextGoals, c.Goals}, {l.contextIgnore, c.IgnoreNotes}} {
		if f.value != nil {
			fmt.Fprintf(&b, f.format+"\n", cleanMultiline(*f.value))
		}
	}
	return b.String()
}

// clean makes user-written text safe for one table cell: no line breaks,
// no column separator, and no angle brackets that could close the data
// tags early.
func clean(s string) string {
	s = strings.Join(strings.Fields(s), " ")
	return strings.NewReplacer("|", "/", "<", "‹", ">", "›").Replace(s)
}

// cleanMultiline keeps line breaks (as " / ") for free text.
func cleanMultiline(s string) string {
	lines := strings.Split(strings.ReplaceAll(s, "\r\n", "\n"), "\n")
	kept := lines[:0]
	for _, ln := range lines {
		if c := clean(ln); c != "" {
			kept = append(kept, c)
		}
	}
	return strings.Join(kept, " / ")
}

// money renders minor units as a plain decimal ("-1234.50").
func money(minor int64) string {
	sign := ""
	if minor < 0 {
		sign, minor = "-", -minor
	}
	return fmt.Sprintf("%s%d.%02d", sign, minor/100, minor%100)
}

// percent renders part/total with one decimal ("12.5%").
func percent(part, total int64) string {
	if total == 0 {
		return "-"
	}
	return fmt.Sprintf("%.1f%%", float64(part)*100/float64(total))
}
