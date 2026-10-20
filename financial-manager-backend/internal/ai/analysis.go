package ai

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"

	"financial-manager-backend/internal/ai/prompt"
	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/reports"
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
	Sections            []string `json:"sections"`
	IncludeTransactions bool     `json:"include_transactions"`
	MaxTransactions     int      `json:"max_transactions"`
	AnonymizeTitles     bool     `json:"anonymize_titles"`
	IncludeAdjustments  bool     `json:"include_adjustments"`
}

// AnalysisPeriod reuses the reports presets; From/To are calendar dates
// (YYYY-MM-DD, or RFC3339) for the custom preset.
type AnalysisPeriod struct {
	Preset string `json:"preset"`
	From   string `json:"from,omitempty"`
	To     string `json:"to,omitempty"`
}

// AnalysisRequest is the body shared by preview and run.
type AnalysisRequest struct {
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
}

// userMessage is the first message sent to the model.
func (b builtPrompt) userMessage() string {
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
	}
	var period reports.Period
	if !reports.IsValidPreset(periodPreset) {
		fieldErrors["period.preset"] = apierror.FieldInvalidPreset
	} else {
		from, okFrom := parseDate(req.Period.From, loc)
		to, okTo := parseDate(req.Period.To, loc)
		if !okFrom || !okTo {
			fieldErrors["period"] = apierror.FieldInvalidRFC3339Date
		} else if period, err = reports.ResolvePeriod(periodPreset, from, to, loc, s.clock.Now()); err != nil {
			fieldErrors["period"] = apierror.FieldCustomRangeRequired
		} else if period.From != nil && !period.From.Before(period.To) {
			fieldErrors["period"] = FieldInvalidValue
		}
	}

	opts := req.Options
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
	if opts.MaxTransactions == 0 {
		opts.MaxTransactions = DefaultMaxTransactions
	}
	if opts.MaxTransactions < 1 || opts.MaxTransactions > MaxMaxTransactions {
		fieldErrors["options.max_transactions"] = FieldOutOfRange
	}

	instructions := ""
	if req.Instructions != nil {
		instructions = strings.TrimSpace(*req.Instructions)
	} else if p, ok := prompt.PresetFor(lang, req.Preset); ok {
		instructions = p.Instructions
	}
	if utf8.RuneCountInString(instructions) > MaxInstructionsLength {
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
		sections: seen, options: opts, userContext: uc,
	})
	if err != nil {
		return builtPrompt{}, err
	}
	style := ""
	if uc.ResponseStyle != nil {
		style = *uc.ResponseStyle
	}
	built, err := prompt.Build(prompt.BuildInput{Lang: lang, Preset: req.Preset, Style: style, Sections: sections, Snapshot: snapshot})
	if err != nil {
		return builtPrompt{}, err
	}

	ids := make([]uuid.UUID, len(selected))
	for i, w := range selected {
		ids[i] = w.ID
	}
	bp := builtPrompt{
		prompt: built, instructions: instructions, preset: req.Preset, lang: lang, period: period, loc: loc,
		walletIDs: ids, options: opts, snapshot: snapshot, sections: sections,
	}
	bp.estimated = prompt.EstimateTokens(built.System, bp.userMessage())
	if bp.estimated > s.limits.MaxPromptTokens {
		return builtPrompt{}, ErrPromptTooLarge
	}
	return bp, nil
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
// read: the feature, the consent and a configured provider.
func (s *Service) requireReady(ctx context.Context, userID uuid.UUID) (Credential, Settings, error) {
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
	cred, err := s.activeCredential(ctx, userID, settings)
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
	if err := s.requireAvailable(); err != nil {
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

func (s *Service) Preview(ctx context.Context, userID uuid.UUID, req AnalysisRequest) (previewResponse, error) {
	cred, settings, err := s.requireReady(ctx, userID)
	if err != nil {
		return previewResponse{}, err
	}
	bp, err := s.buildPrompt(ctx, userID, req)
	if err != nil {
		return previewResponse{}, err
	}

	resp := previewResponse{
		Provider: string(cred.Provider), Model: *cred.Model, PromptVersion: bp.prompt.Version,
		SystemPrompt: bp.prompt.System, Instructions: bp.instructions, DataBlock: bp.prompt.DataBlock,
		DataFingerprint: bp.prompt.Fingerprint, EstimatedInputTokens: bp.estimated,
		MaxOutputTokens: settings.MaxOutputTokens,
		EstimatedCost:   estimateCost(settings, bp.estimated, settings.MaxOutputTokens),
		PeriodTo:        bp.period.To.In(bp.loc).Add(-time.Nanosecond).Format("2006-01-02"),
		Disclosure: disclosureResponse{
			Sections: bp.sections, WalletCount: len(bp.walletIDs), TransactionCount: len(bp.snapshot.Transactions),
			TransactionsOmitted: bp.snapshot.TransactionsOmitted, Anonymized: bp.options.AnonymizeTitles,
			IncludesPersonalContext: bp.snapshot.Context != nil,
		},
	}
	if bp.period.From != nil {
		f := bp.period.From.In(bp.loc).Format("2006-01-02")
		resp.PeriodFrom = &f
	}
	return resp, nil
}
