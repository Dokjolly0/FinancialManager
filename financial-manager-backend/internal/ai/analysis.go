package ai

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"

	"financial-manager-backend/internal/ai/prompt"
	"financial-manager-backend/internal/categories"
	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/reports"
	"financial-manager-backend/internal/transactions"
	"financial-manager-backend/internal/wallets"
)

// MaxInstructionsLength bounds the editable instructions.
const MaxInstructionsLength = 4000

var (
	ErrPromptTooLarge = apierror.New(http.StatusUnprocessableEntity, "AI_PROMPT_TOO_LARGE",
		"The data is too large for one analysis: choose a shorter period, fewer wallets or fewer transactions.")
	ErrDataChanged = apierror.New(http.StatusConflict, "AI_DATA_CHANGED",
		"Your data changed after the preview: review the preview again.")
)

// AnalysisOptions chooses what data leaves the server.
type AnalysisOptions struct {
	Sections            []string         `json:"sections"`
	IncludeTransactions bool             `json:"include_transactions"`
	MaxTransactions     int              `json:"max_transactions"`
	AnonymizeTitles     bool             `json:"anonymize_titles"`
	IncludeAdjustments  bool             `json:"include_adjustments"`
	Filters             *AnalysisFilters `json:"filters,omitempty"`
	// Profile is "standard" (default) or "compact" (plan.md section 33):
	// tighter data limits and shorter rules for small on-device models.
	Profile string `json:"profile,omitempty"`
	// BudgetTokens, when set, drops detail step by step (prompt.BudgetSteps)
	// until the estimated prompt fits.
	BudgetTokens int `json:"budget_tokens,omitempty"`
	// Lang is the prompt language, set by the server; follow-ups use it
	// for their rules. Empty on analyses stored before it existed.
	Lang string `json:"lang,omitempty"`
	// LedgerCutoff, set by the server on a chat whose transaction list was
	// cut, is the time of the oldest transaction kept (or the period end
	// when none was): questions search the transactions before it.
	LedgerCutoff *time.Time `json:"ledger_cutoff,omitempty"`
}

// Token budget bounds.
const (
	MinBudgetTokens = 1000
	MaxBudgetTokens = 32000
	// compactDefaultTransactions is the transaction list size of the
	// compact profile when the request doesn't set one.
	compactDefaultTransactions = 60
)

// AnalysisFilters restricts an analysis to part of the ledger, with the
// same meaning as the Cronologia filters (an analysis started from there).
type AnalysisFilters struct {
	Direction      string `json:"direction,omitempty"` // DEBIT, CREDIT
	CategoryID     string `json:"category_id,omitempty"`
	Title          string `json:"title,omitempty"`
	AmountMinMinor int64  `json:"amount_min_minor,omitempty"`
	AmountMaxMinor int64  `json:"amount_max_minor,omitempty"`
}

// MaxFilterTitleLength bounds the title search, like transaction titles.
const MaxFilterTitleLength = 120

// AnalysisPeriod reuses the reports presets; From/To are calendar dates
// (YYYY-MM-DD, or RFC3339) for the custom preset.
type AnalysisPeriod struct {
	Preset string `json:"preset"`
	From   string `json:"from,omitempty"`
	To     string `json:"to,omitempty"`
}

// DeviceParams describe the phone's model for an on-device preview, so it
// can say whether the prompt fits.
type DeviceParams struct {
	ContextTokens   int `json:"context_tokens"`
	MaxOutputTokens int `json:"max_output_tokens"`
}

// AnalysisRequest is the body shared by preview and run.
type AnalysisRequest struct {
	// Target is "cloud" or "on_device"; empty uses the saved mode.
	Target string        `json:"target,omitempty"`
	Device *DeviceParams `json:"device,omitempty"`
	// CredentialID picks the stored provider account of a cloud run;
	// empty uses the active one.
	CredentialID string `json:"credential_id,omitempty"`

	Preset       string          `json:"preset"`
	Period       AnalysisPeriod  `json:"period"`
	Timezone     string          `json:"timezone,omitempty"`
	WalletIDs    []string        `json:"wallet_ids"`
	Options      AnalysisOptions `json:"options"`
	Instructions *string         `json:"instructions"`
}

// builtPrompt is a validated request turned into the exact prompt.
type builtPrompt struct {
	prompt       prompt.Prompt
	filter       reports.Filter
	instructions string
	preset       string
	lang         prompt.Lang
	period       reports.Period
	loc          *time.Location
	walletIDs    []uuid.UUID
	options      AnalysisOptions
	snapshot     prompt.Snapshot
	sections     []string
	estimated    int
	// compactionSteps are the budget steps that were needed, in order.
	compactionSteps []string
	// attachment is a chat's first-question attachment, when its list was
	// cut (plan.md section 34.3).
	attachment string
}

// userMessage is the first message sent to the model. A chat's
// instructions are its first question, which comes after the data.
func (b builtPrompt) userMessage() string {
	if b.preset == prompt.PresetChat {
		return prompt.ChatUserMessage(b.instructions, b.prompt.DataBlock, b.attachment, b.lang)
	}
	return prompt.UserMessage(b.instructions, b.prompt.DataBlock)
}

func parseDate(raw string, loc *time.Location) (*time.Time, bool) {
	if raw == "" {
		return nil, true
	}
	if t, err := time.ParseInLocation("2006-01-02", raw, loc); err == nil {
		return &t, true
	}
	if t, err := time.Parse(time.RFC3339, raw); err == nil {
		return &t, true
	}
	return nil, false
}

// buildPrompt validates req and renders the prompt from fresh data.
func (s *Service) buildPrompt(ctx context.Context, userID uuid.UUID, req AnalysisRequest) (builtPrompt, error) {
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return builtPrompt{}, err
	}
	lang := prompt.LangFor(user.Locale)

	fieldErrors := map[string]string{}
	if !prompt.IsValidPreset(req.Preset) {
		fieldErrors["preset"] = FieldInvalidValue
	}
	chat := req.Preset == prompt.PresetChat

	tzName := req.Timezone
	if tzName == "" {
		tzName = user.Timezone
	}
	if tzName == "" {
		tzName = "Europe/Rome"
	}
	loc, err := time.LoadLocation(tzName)
	if err != nil {
		fieldErrors["timezone"] = apierror.FieldInvalidTimezone
		loc = time.UTC
	}

	periodPreset := req.Period.Preset
	if periodPreset == "" {
		periodPreset = reports.PresetLast12Months
		if chat {
			periodPreset = reports.PresetAllTime
		}
	}
	var period reports.Period
	if !reports.IsValidPreset(periodPreset) {
		fieldErrors["period.preset"] = apierror.FieldInvalidPreset
	} else {
		from, okFrom := parseDate(req.Period.From, loc)
		to, okTo := parseDate(req.Period.To, loc)
		if !okFrom || !okTo {
			fieldErrors["period"] = apierror.FieldInvalidRFC3339Date
		} else if periodPreset == reports.PresetCustom && (from == nil) != (to == nil) {
			// Open-ended range ("from date X" or "up to date Y"), as the
			// Cronologia date filters allow.
			period = openEndedPeriod(from, to, loc, s.clock.Now())
		} else if period, err = reports.ResolvePeriod(periodPreset, from, to, loc, s.clock.Now()); err != nil {
			fieldErrors["period"] = apierror.FieldCustomRangeRequired
		} else if period.From != nil && !period.From.Before(period.To) {
			fieldErrors["period"] = FieldInvalidValue
		}
	}

	opts := req.Options
	if chat {
		// A chat answers from the transactions themselves; the search they
		// need is by title, so titles can't be replaced by pseudonyms.
		if len(opts.Sections) == 0 {
			defaults, _ := prompt.PresetFor(lang, prompt.PresetChat)
			opts.Sections = defaults.Defaults.Sections
		}
		opts.IncludeTransactions = true
		if opts.AnonymizeTitles {
			fieldErrors["options.anonymize_titles"] = FieldInvalidValue
		}
	}
	sections := make([]string, 0, len(opts.Sections))
	seen := map[string]bool{}
	for _, sec := range opts.Sections {
		if !prompt.IsValidSection(sec) {
			fieldErrors["options.sections"] = FieldInvalidValue
			continue
		}
		if !seen[sec] {
			seen[sec] = true
			sections = append(sections, sec)
		}
	}
	if !prompt.IsValidProfile(opts.Profile) {
		fieldErrors["options.profile"] = FieldInvalidValue
	}
	if opts.Profile == "" {
		opts.Profile = prompt.ProfileStandard
	}
	opts.Lang = string(lang)
	opts.LedgerCutoff = nil
	if opts.BudgetTokens != 0 && (opts.BudgetTokens < MinBudgetTokens || opts.BudgetTokens > MaxBudgetTokens) {
		fieldErrors["options.budget_tokens"] = FieldOutOfRange
	}
	maxTransactions := MaxMaxTransactions
	switch {
	case chat:
		maxTransactions = ChatMaxTransactions
		if opts.MaxTransactions == 0 {
			opts.MaxTransactions = ChatMaxTransactions
		}
	case opts.MaxTransactions == 0:
		opts.MaxTransactions = DefaultMaxTransactions
		if opts.Profile == prompt.ProfileCompact {
			opts.MaxTransactions = compactDefaultTransactions
		}
	}
	if opts.MaxTransactions < 1 || opts.MaxTransactions > maxTransactions {
		fieldErrors["options.max_transactions"] = FieldOutOfRange
	}

	filter, filterInfo, filterErrors, err := s.resolveFilters(ctx, userID, opts.Filters)
	if err != nil {
		return builtPrompt{}, err
	}
	for k, v := range filterErrors {
		fieldErrors[k] = v
	}

	instructions := ""
	if req.Instructions != nil {
		instructions = strings.TrimSpace(*req.Instructions)
	} else if p, ok := prompt.PresetFor(lang, req.Preset); ok {
		instructions = p.Instructions
	}
	maxInstructions := MaxInstructionsLength
	if chat {
		maxInstructions = MaxQuestionLength // the first question
	}
	if utf8.RuneCountInString(instructions) > maxInstructions {
		fieldErrors["instructions"] = FieldTextTooLong
	} else if instructions == "" && req.Preset != "" {
		fieldErrors["instructions"] = apierror.FieldRequired
	}

	selected, walletErr := s.selectWallets(ctx, userID, req.WalletIDs)
	if walletErr != nil {
		var apiErr *apierror.Error
		if !errors.As(walletErr, &apiErr) {
			return builtPrompt{}, walletErr
		}
		fieldErrors["wallet_ids"] = "WALLET_NOT_FOUND"
	}
	if len(fieldErrors) > 0 {
		return builtPrompt{}, apierror.NewValidation(fieldErrors)
	}

	uc, err := s.repo.GetUserContext(ctx, userID)
	if err != nil {
		return builtPrompt{}, err
	}
	snapshot, err := s.collect(ctx, collectInput{
		userID: userID, wallets: selected, period: period, loc: loc, lang: lang,
		sections: seen, options: opts, userContext: uc, filter: filter, filterInfo: filterInfo,
	})
	if err != nil {
		return builtPrompt{}, err
	}
	style := ""
	if uc.ResponseStyle != nil {
		style = *uc.ResponseStyle
	}
	ids := make([]uuid.UUID, len(selected))
	for i, w := range selected {
		ids[i] = w.ID
	}
	bp := builtPrompt{
		filter: filter, instructions: instructions, preset: req.Preset, lang: lang, period: period, loc: loc,
		walletIDs: ids, options: opts, sections: sections,
	}

	// Render with the profile's limits, then give up detail one budget
	// step at a time until the prompt fits. Deterministic, so a run
	// rebuilds exactly what its preview showed.
	limits := prompt.LimitsFor(opts.Profile)
	budget := opts.BudgetTokens
	if chat {
		// The ledger is what a chat answers from: keep all of it, then cut
		// it to the budget (or the server's prompt limit) before anything
		// else.
		limits.Transactions = 0
		if budget == 0 {
			budget = s.limits.MaxPromptTokens
		}
	}
	render := func() error {
		bp.snapshot = prompt.Trim(snapshot, limits, lang)
		built, err := prompt.Build(prompt.BuildInput{
			Lang: lang, Preset: req.Preset, Style: style, Sections: sections, Snapshot: bp.snapshot, Profile: opts.Profile,
		})
		if err != nil {
			return err
		}
		bp.prompt = built
		bp.estimated = prompt.EstimateTokens(built.System, bp.userMessage())
		return nil
	}
	if err := render(); err != nil {
		return builtPrompt{}, err
	}
	if chat && bp.estimated > budget {
		if err := s.fitChat(ctx, &bp, &limits, budget, len(snapshot.Transactions), render); err != nil {
			return builtPrompt{}, err
		}
	}
	if budget > 0 {
		for _, step := range prompt.BudgetSteps {
			if bp.estimated <= budget {
				break
			}
			if chat && strings.HasPrefix(step.Name, "transactions_") {
				continue // fitLedger already cut the ledger
			}
			step.Apply(&limits)
			bp.compactionSteps = append(bp.compactionSteps, step.Name)
			if err := render(); err != nil {
				return builtPrompt{}, err
			}
		}
		if bp.estimated > budget {
			return builtPrompt{}, ErrPromptTooLarge
		}
	}
	if bp.estimated > s.limits.MaxPromptTokens {
		return builtPrompt{}, ErrPromptTooLarge
	}
	return bp, nil
}

// fitChat fits a chat whose ledger is over budget: it reserves room for the
// first question's attachment (the matches over the whole period, an upper
// bound, capped at a third of the budget), cuts the ledger to the rest,
// then attaches the matches older than
// the oldest transaction kept, dropping the last ones if they still don't
// fit. The cut is stored as options.ledger_cutoff for later questions.
func (s *Service) fitChat(ctx context.Context, bp *builtPrompt, limits *prompt.Limits, budget, total int, render func() error) error {
	cs := chatSearch{
		walletIDs: bp.walletIDs, kinds: chatKinds(bp.options), from: bp.period.From, before: bp.period.To,
		loc: bp.loc, limit: chatMatchLimit(bp.options.Profile),
	}
	reserve, err := s.chatAttachment(ctx, cs, bp.instructions, bp.lang)
	if err != nil {
		return err
	}
	// At most a third of the budget, so a question matching most of the
	// ledger (a "spesa" among groceries) doesn't leave the list empty.
	if err := bp.fitLedger(limits, budget-min(prompt.EstimateTokens(reserve), budget/3), total, render); err != nil {
		return err
	}
	if kept := bp.snapshot.Transactions; len(kept) > 0 {
		cs.before = kept[len(kept)-1].At
	}
	cutoff := cs.before
	bp.options.LedgerCutoff = &cutoff
	for {
		bp.attachment = ""
		if cs.limit > 0 {
			if bp.attachment, err = s.chatAttachment(ctx, cs, bp.instructions, bp.lang); err != nil {
				return err
			}
		}
		if err := render(); err != nil {
			return err
		}
		if bp.estimated <= budget || cs.limit == 0 {
			return nil
		}
		cs.limit = cs.limit * 3 / 4
	}
}

// fitLedger keeps the most recent transactions that fit the budget,
// shrinking the list by a quarter at a time (deterministic, so a run
// rebuilds its preview) and dropping it only when not even a few fit. The
// cut is recorded as a compaction step, "transactions_<kept>".
func (bp *builtPrompt) fitLedger(limits *prompt.Limits, budget, total int, render func() error) error {
	n := total
	for bp.estimated > budget && n > 0 {
		n = n * 3 / 4
		if n < 4 {
			n = 0
		}
		limits.Transactions = n
		if n == 0 {
			limits.Transactions = -1
		}
		if err := render(); err != nil {
			return err
		}
	}
	if n < total {
		bp.compactionSteps = append(bp.compactionSteps, fmt.Sprintf("transactions_%d", n))
	}
	return nil
}

// openEndedPeriod is a custom period with only one bound: "from X to
// today" or "the whole history up to Y" (Y inclusive).
func openEndedPeriod(from, to *time.Time, loc *time.Location, now time.Time) reports.Period {
	if from != nil {
		f := from.In(loc)
		start := time.Date(f.Year(), f.Month(), f.Day(), 0, 0, 0, 0, loc).UTC()
		return reports.Period{From: &start, To: now}
	}
	t := to.In(loc)
	end := time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, loc).AddDate(0, 0, 1).UTC()
	if end.After(now) {
		end = now
	}
	return reports.Period{From: nil, To: end}
}

// resolveFilters validates the Cronologia filters and returns them as a
// reports.Filter plus the description shown in the data block (nil when
// no filter is active).
func (s *Service) resolveFilters(ctx context.Context, userID uuid.UUID, f *AnalysisFilters) (reports.Filter, *prompt.Filters, map[string]string, error) {
	if f == nil {
		return reports.Filter{}, nil, nil, nil
	}
	fieldErrors := map[string]string{}
	filter := reports.Filter{
		Direction: f.Direction, Title: strings.TrimSpace(f.Title),
		AmountMinMinor: f.AmountMinMinor, AmountMaxMinor: f.AmountMaxMinor,
	}
	info := &prompt.Filters{
		Direction: f.Direction, Title: filter.Title, AmountMinMinor: f.AmountMinMinor, AmountMaxMinor: f.AmountMaxMinor,
	}
	if f.Direction != "" && f.Direction != transactions.DirectionDebit && f.Direction != transactions.DirectionCredit {
		fieldErrors["options.filters.direction"] = FieldInvalidValue
	}
	if utf8.RuneCountInString(filter.Title) > MaxFilterTitleLength {
		fieldErrors["options.filters.title"] = FieldTextTooLong
	}
	if f.AmountMinMinor < 0 || f.AmountMaxMinor < 0 {
		fieldErrors["options.filters.amount_min_minor"] = apierror.FieldNegativeNotAllowed
	} else if f.AmountMaxMinor > 0 && f.AmountMinMinor > f.AmountMaxMinor {
		fieldErrors["options.filters.amount_max_minor"] = FieldOutOfRange
	}
	if f.CategoryID != "" {
		id, err := uuid.Parse(f.CategoryID)
		if err != nil {
			fieldErrors["options.filters.category_id"] = "CATEGORY_NOT_FOUND"
		} else if c, err := s.categories.GetByIDAndVisibility(ctx, id, userID); errors.Is(err, categories.ErrNotFound) {
			fieldErrors["options.filters.category_id"] = "CATEGORY_NOT_FOUND"
		} else if err != nil {
			return reports.Filter{}, nil, nil, err
		} else {
			filter.CategoryID = &id
			info.Category = c.Name
		}
	}
	if filter.IsZero() {
		return reports.Filter{}, nil, fieldErrors, nil
	}
	return filter, info, fieldErrors, nil
}

// selectWallets resolves wallet_ids; empty means every wallet the user ever
// had, archived ones included, as in the reports "all wallets" view.
func (s *Service) selectWallets(ctx context.Context, userID uuid.UUID, raw []string) ([]wallets.Wallet, error) {
	if len(raw) == 0 {
		all, err := s.wallets.ListAllByUserID(ctx, userID)
		if err != nil {
			return nil, err
		}
		if len(all) == 0 {
			return nil, apierror.ErrNotFound
		}
		return all, nil
	}
	out := make([]wallets.Wallet, 0, len(raw))
	seen := map[uuid.UUID]bool{}
	for _, r := range raw {
		id, err := uuid.Parse(r)
		if err != nil {
			return nil, apierror.ErrNotFound
		}
		if seen[id] {
			continue
		}
		seen[id] = true
		w, err := s.wallets.GetByID(ctx, id, userID)
		if errors.Is(err, wallets.ErrNotFound) {
			return nil, apierror.ErrNotFound
		}
		if err != nil {
			return nil, err
		}
		out = append(out, w)
	}
	return out, nil
}

// requireReady checks everything an analysis needs before any data is
// read: the feature, the consent and a configured provider (credentialID,
// or the active one when empty).
func (s *Service) requireReady(ctx context.Context, userID uuid.UUID, credentialID string) (Credential, Settings, error) {
	if err := s.requireAvailable(); err != nil {
		return Credential{}, Settings{}, err
	}
	settings, err := s.repo.GetSettings(ctx, userID)
	if err != nil {
		return Credential{}, Settings{}, err
	}
	if !settings.HasCurrentConsent() {
		return Credential{}, Settings{}, ErrConsentRequired
	}
	cred, err := s.credentialFor(ctx, userID, settings, credentialID)
	if err != nil {
		return Credential{}, Settings{}, err
	}
	return cred, settings, nil
}

// --- Presets -------------------------------------------------------------------

type presetResponse struct {
	ID                  string   `json:"id"`
	Title               string   `json:"title"`
	Description         string   `json:"description"`
	DefaultInstructions string   `json:"default_instructions"`
	DefaultSections     []string `json:"default_sections"`
	IncludeTransactions bool     `json:"default_include_transactions"`
	PeriodPreset        string   `json:"default_period_preset"`
}

func (s *Service) Presets(ctx context.Context, userID uuid.UUID) ([]presetResponse, error) {
	if err := s.requireFeature(); err != nil {
		return nil, err
	}
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	presets := prompt.Presets(prompt.LangFor(user.Locale))
	out := make([]presetResponse, 0, len(presets))
	for _, p := range presets {
		out = append(out, presetResponse{
			ID: p.ID, Title: p.Title, Description: p.Description, DefaultInstructions: p.Instructions,
			DefaultSections: p.Defaults.Sections, IncludeTransactions: p.Defaults.IncludeTransactions,
			PeriodPreset: p.Defaults.PeriodPreset,
		})
	}
	return out, nil
}

// --- Preview -------------------------------------------------------------------

type costEstimate struct {
	InputCost     float64 `json:"input_cost"`
	MaxOutputCost float64 `json:"max_output_cost"`
}

type disclosureResponse struct {
	Sections                []string `json:"sections"`
	WalletCount             int      `json:"wallet_count"`
	TransactionCount        int      `json:"transaction_count"`
	TransactionsOmitted     int      `json:"transactions_omitted"`
	Anonymized              bool     `json:"anonymized"`
	IncludesPersonalContext bool     `json:"includes_personal_context"`
	Profile                 string   `json:"profile"`
	// CompactionSteps lists the detail given up to fit budget_tokens.
	CompactionSteps []string `json:"compaction_steps"`
}

type previewResponse struct {
	Provider             string             `json:"provider"`
	Model                string             `json:"model"`
	PromptVersion        string             `json:"prompt_version"`
	SystemPrompt         string             `json:"system_prompt"`
	Instructions         string             `json:"instructions"`
	DataBlock            string             `json:"data_block"`
	DataFingerprint      string             `json:"data_fingerprint"`
	EstimatedInputTokens int                `json:"estimated_input_tokens"`
	MaxOutputTokens      int                `json:"max_output_tokens"`
	EstimatedCost        *costEstimate      `json:"estimated_cost"`
	PeriodFrom           *string            `json:"period_from"`
	PeriodTo             string             `json:"period_to"`
	Disclosure           disclosureResponse `json:"disclosure"`
	Target               string             `json:"target"`
	ContextFit           *contextFit        `json:"context_fit"`
}

// contextFit says whether an on-device prompt and its answer fit the
// model's context.
type contextFit struct {
	ContextTokens        int  `json:"context_tokens"`
	InputTokens          int  `json:"input_tokens"`
	ReservedOutputTokens int  `json:"reserved_output_tokens"`
	Fits                 bool `json:"fits"`
}

func estimateCost(settings Settings, inputTokens, maxOutputTokens int) *costEstimate {
	if settings.InputPricePerMTok == nil && settings.OutputPricePerMTok == nil {
		return nil
	}
	var c costEstimate
	if settings.InputPricePerMTok != nil {
		c.InputCost = float64(inputTokens) * *settings.InputPricePerMTok / 1e6
	}
	if settings.OutputPricePerMTok != nil {
		c.MaxOutputCost = float64(maxOutputTokens) * *settings.OutputPricePerMTok / 1e6
	}
	return &c
}

// previewTarget resolves the request's target against the saved mode.
func (s *Service) previewTarget(ctx context.Context, userID uuid.UUID, target string) (string, error) {
	if err := s.requireFeature(); err != nil {
		return "", err
	}
	switch target {
	case ModeCloud, ModeOnDevice:
		return target, nil
	case "":
		settings, err := s.repo.GetSettings(ctx, userID)
		if err != nil {
			return "", err
		}
		return settings.Mode, nil
	}
	return "", apierror.NewValidation(map[string]string{"target": FieldInvalidValue})
}

func (s *Service) Preview(ctx context.Context, userID uuid.UUID, req AnalysisRequest) (previewResponse, error) {
	target, err := s.previewTarget(ctx, userID, req.Target)
	if err != nil {
		return previewResponse{}, err
	}
	if target == ModeOnDevice {
		return s.previewOnDevice(ctx, userID, req)
	}
	cred, settings, err := s.requireReady(ctx, userID, req.CredentialID)
	if err != nil {
		return previewResponse{}, err
	}
	bp, err := s.buildPrompt(ctx, userID, req)
	if err != nil {
		return previewResponse{}, err
	}

	resp := s.previewFrom(bp)
	resp.Target = ModeCloud
	resp.Provider, resp.Model = string(cred.Provider), *cred.Model
	resp.MaxOutputTokens = settings.MaxOutputTokens
	resp.EstimatedCost = estimateCost(settings, bp.estimated, settings.MaxOutputTokens)
	return resp, nil
}

// previewOnDevice previews a run on the phone: no provider, no cost, and
// a context fit when the app says which context its model has.
func (s *Service) previewOnDevice(ctx context.Context, userID uuid.UUID, req AnalysisRequest) (previewResponse, error) {
	settings, err := s.requireLocalReady(ctx, userID)
	if err != nil {
		return previewResponse{}, err
	}
	if d := req.Device; d != nil && (d.ContextTokens < MinLocalContextTokens || d.ContextTokens > MaxLocalContextTokens ||
		d.MaxOutputTokens < 0 || d.MaxOutputTokens >= d.ContextTokens) {
		return previewResponse{}, apierror.NewValidation(map[string]string{"device": FieldOutOfRange})
	}
	bp, err := s.buildPrompt(ctx, userID, req)
	if err != nil {
		return previewResponse{}, err
	}
	resp := s.previewFrom(bp)
	resp.Target = ModeOnDevice
	resp.Provider = ProviderOnDevice
	if settings.LocalModel != nil {
		resp.Model = *settings.LocalModel
	}
	if d := req.Device; d != nil {
		resp.MaxOutputTokens = d.MaxOutputTokens
		resp.ContextFit = &contextFit{
			ContextTokens: d.ContextTokens, InputTokens: bp.estimated, ReservedOutputTokens: d.MaxOutputTokens,
			Fits: bp.estimated+d.MaxOutputTokens <= d.ContextTokens,
		}
	}
	return resp, nil
}

// previewFrom fills the parts of a preview that don't depend on the target.
func (s *Service) previewFrom(bp builtPrompt) previewResponse {
	resp := previewResponse{
		PromptVersion: bp.prompt.Version,
		SystemPrompt:  bp.prompt.System, Instructions: bp.instructions, DataBlock: bp.prompt.DataBlock,
		DataFingerprint: bp.prompt.Fingerprint, EstimatedInputTokens: bp.estimated,
		PeriodTo: bp.period.To.In(bp.loc).Add(-time.Nanosecond).Format("2006-01-02"),
		Disclosure: disclosureResponse{
			Sections: bp.sections, WalletCount: len(bp.walletIDs), TransactionCount: len(bp.snapshot.Transactions),
			TransactionsOmitted: bp.snapshot.TransactionsOmitted, Anonymized: bp.options.AnonymizeTitles,
			IncludesPersonalContext: bp.snapshot.Context != nil,
			Profile:                 bp.options.Profile, CompactionSteps: append([]string{}, bp.compactionSteps...),
		},
	}
	if bp.period.From != nil {
		f := bp.period.From.In(bp.loc).Format("2006-01-02")
		resp.PeriodFrom = &f
	}
	return resp
}
