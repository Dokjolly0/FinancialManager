package ai

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"

	"financial-manager-backend/internal/ai/provider"
	"financial-manager-backend/internal/categories"
	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/clock"
	"financial-manager-backend/internal/platform/database"
	"financial-manager-backend/internal/platform/metrics"
	"financial-manager-backend/internal/platform/ratelimit"
	"financial-manager-backend/internal/platform/secretbox"
	"financial-manager-backend/internal/reports"
	"financial-manager-backend/internal/users"
	"financial-manager-backend/internal/wallets"
)

// Probe limits: test connection and model listing call the provider with
// the user's key, so they are throttled like any outbound action.
const (
	probeLimit       = 10
	probeWindow      = 10 * time.Minute
	probeTimeout     = 30 * time.Second
	probeMaxTokens   = 16
	timeLayout       = time.RFC3339
	maxModelsInReply = 500
)

// Limits are the configurable bounds of an analysis (config AI_*).
type Limits struct {
	MaxPromptTokens   int
	RunsPerHour       int
	StreamMaxDuration time.Duration
}

type Deps struct {
	DB         *database.Pool
	Repo       *Repository
	Wallets    *wallets.Repository
	Users      *users.Repository
	Reports    *reports.Repository
	Categories *categories.Repository
	Limits     Limits
	// Box encrypts the API keys; nil means the feature is disabled
	// (AI_KEY_ENCRYPTION_KEY unset).
	Box         *secretbox.Box
	Providers   provider.Factory
	Policy      provider.BaseURLPolicy
	RateLimiter *ratelimit.Limiter // nil disables rate limiting (tests)
	// Locker allows one stream per user; nil uses an in-process lock,
	// which is only correct with a single API instance (tests).
	Locker StreamLocker
	Clock  clock.Clock
	Logger *slog.Logger
}

type Service struct {
	db          *database.Pool
	locker      StreamLocker
	repo        *Repository
	wallets     *wallets.Repository
	users       *users.Repository
	reports     *reports.Repository
	categories  *categories.Repository
	limits      Limits
	box         *secretbox.Box
	providers   provider.Factory
	policy      provider.BaseURLPolicy
	rateLimiter *ratelimit.Limiter
	clock       clock.Clock
	logger      *slog.Logger
}

func NewService(d Deps) *Service {
	logger := d.Logger
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, nil))
	}
	c := d.Clock
	if c == nil {
		c = clock.System{}
	}
	limits := d.Limits
	if limits.MaxPromptTokens == 0 {
		limits.MaxPromptTokens = 60000
	}
	if limits.RunsPerHour == 0 {
		limits.RunsPerHour = 20
	}
	if limits.StreamMaxDuration == 0 {
		limits.StreamMaxDuration = 5 * time.Minute
	}
	var locker StreamLocker = newMemoryLocker()
	if d.Locker != nil {
		locker = d.Locker
	}
	return &Service{
		db: d.DB, locker: locker,
		repo: d.Repo, wallets: d.Wallets, users: d.Users, reports: d.Reports, categories: d.Categories, limits: limits,
		box: d.Box, providers: d.Providers, policy: d.Policy,
		rateLimiter: d.RateLimiter, clock: c, logger: logger,
	}
}

// Available reports whether the server can run the feature at all.
func (s *Service) Available() bool { return s.box != nil }

func (s *Service) requireAvailable() error {
	if !s.Available() {
		return ErrDisabled
	}
	return nil
}

func (s *Service) checkRateLimit(ctx context.Context, scope string, userID uuid.UUID, limit int, window time.Duration) error {
	if s.rateLimiter == nil {
		return nil
	}
	result, err := s.rateLimiter.Allow(ctx, "ratelimit:ai-"+scope+":user:"+userID.String(), limit, window)
	if err == nil && !result.Allowed {
		metrics.RateLimitTriggered.WithLabelValues("ai-" + scope).Inc()
		return apierror.ErrRateLimited
	}
	return nil
}

// --- Responses ---------------------------------------------------------------

type credentialResponse struct {
	ID           string  `json:"id"`
	Provider     string  `json:"provider"`
	BaseURL      *string `json:"base_url"`
	Model        *string `json:"model"`
	HasKey       bool    `json:"has_key"`
	KeyHint      *string `json:"key_hint"`
	LastTestedAt *string `json:"last_tested_at"`
	LastTestOK   *bool   `json:"last_test_ok"`
}

func toCredentialResponse(c Credential) credentialResponse {
	resp := credentialResponse{
		ID: c.ID.String(), Provider: string(c.Provider), Model: c.Model, HasKey: c.HasKey(),
		KeyHint: c.APIKeyHint, LastTestOK: c.LastTestOK,
	}
	if c.BaseURL != "" {
		u := c.BaseURL
		resp.BaseURL = &u
	}
	if c.LastTestedAt != nil {
		t := c.LastTestedAt.UTC().Format(timeLayout)
		resp.LastTestedAt = &t
	}
	return resp
}

type defaultsResponse struct {
	IncludeTransactions bool `json:"include_transactions"`
	AnonymizeTitles     bool `json:"anonymize_titles"`
}

type consentResponse struct {
	AcceptedVersion *int    `json:"accepted_version"`
	CurrentVersion  int     `json:"current_version"`
	AcceptedAt      *string `json:"accepted_at"`
	Required        bool    `json:"required"`
}

// setupResponse drives the app's setup checklist.
type setupResponse struct {
	HasProvider        bool `json:"has_provider"`
	HasModel           bool `json:"has_model"`
	HasContext         bool `json:"has_context"`
	WalletsTotal       int  `json:"wallets_total"`
	WalletsWithPurpose int  `json:"wallets_with_purpose"`
	AnalysesCount      int  `json:"analyses_count"`
}

type settingsResponse struct {
	Available          bool                 `json:"available"`
	Active             *credentialResponse  `json:"active"`
	Credentials        []credentialResponse `json:"credentials"`
	MaxOutputTokens    int                  `json:"max_output_tokens"`
	InputPricePerMTok  *float64             `json:"input_price_per_mtok"`
	OutputPricePerMTok *float64             `json:"output_price_per_mtok"`
	Defaults           defaultsResponse     `json:"defaults"`
	Consent            consentResponse      `json:"consent"`
	Setup              setupResponse        `json:"setup"`
	Version            int64                `json:"version"`
}

// --- Settings ----------------------------------------------------------------

func (s *Service) GetSettings(ctx context.Context, userID uuid.UUID) (settingsResponse, error) {
	if !s.Available() {
		return settingsResponse{Available: false, Credentials: []credentialResponse{},
			MaxOutputTokens: DefaultMaxOutputTokens, Consent: consentResponse{CurrentVersion: ConsentVersion, Required: true}}, nil
	}
	settings, err := s.repo.GetSettings(ctx, userID)
	if err != nil {
		return settingsResponse{}, err
	}
	creds, err := s.repo.ListCredentials(ctx, userID)
	if err != nil {
		return settingsResponse{}, err
	}

	resp := settingsResponse{
		Available:          true,
		Credentials:        make([]credentialResponse, 0, len(creds)),
		MaxOutputTokens:    settings.MaxOutputTokens,
		InputPricePerMTok:  settings.InputPricePerMTok,
		OutputPricePerMTok: settings.OutputPricePerMTok,
		Defaults: defaultsResponse{
			IncludeTransactions: settings.DefaultIncludeTransactions,
			AnonymizeTitles:     settings.DefaultAnonymizeTitles,
		},
		Consent: consentResponse{
			AcceptedVersion: settings.ConsentVersion, CurrentVersion: ConsentVersion,
			Required: !settings.HasCurrentConsent(),
		},
		Version: settings.Version,
	}
	if settings.ConsentAcceptedAt != nil {
		t := settings.ConsentAcceptedAt.UTC().Format(timeLayout)
		resp.Consent.AcceptedAt = &t
	}
	for _, c := range creds {
		cr := toCredentialResponse(c)
		resp.Credentials = append(resp.Credentials, cr)
		if settings.ActiveCredentialID != nil && *settings.ActiveCredentialID == c.ID {
			active := cr
			resp.Active = &active
		}
	}

	resp.Setup, err = s.setupStatus(ctx, userID, resp.Active)
	if err != nil {
		return settingsResponse{}, err
	}
	return resp, nil
}

func (s *Service) setupStatus(ctx context.Context, userID uuid.UUID, active *credentialResponse) (setupResponse, error) {
	setup := setupResponse{HasProvider: active != nil}
	if active != nil {
		setup.HasModel = active.Model != nil && *active.Model != ""
		setup.HasProvider = active.HasKey || !provider.Kind(active.Provider).RequiresAPIKey()
	}
	uc, err := s.repo.GetUserContext(ctx, userID)
	if err != nil {
		return setupResponse{}, err
	}
	setup.HasContext = !uc.IsEmpty()

	list, err := s.wallets.ListByUserID(ctx, userID)
	if err != nil {
		return setupResponse{}, err
	}
	setup.WalletsTotal = len(list)
	for _, w := range list {
		if w.Purpose != nil {
			setup.WalletsWithPurpose++
		}
	}
	setup.AnalysesCount, err = s.repo.CountAnalyses(ctx, userID)
	if err != nil {
		return setupResponse{}, err
	}
	return setup, nil
}

// SaveSettingsInput is PUT /v1/ai/settings. APIKey nil keeps the stored
// key, "" removes it, anything else replaces it.
type SaveSettingsInput struct {
	UserID                     uuid.UUID
	Provider                   string
	BaseURL                    string
	Model                      string
	APIKey                     *string
	MaxOutputTokens            int
	InputPricePerMTok          *float64
	OutputPricePerMTok         *float64
	DefaultIncludeTransactions bool
	DefaultAnonymizeTitles     bool
	ExpectedVersion            int64
}

func (s *Service) SaveSettings(ctx context.Context, in SaveSettingsInput) (settingsResponse, error) {
	if err := s.requireAvailable(); err != nil {
		return settingsResponse{}, err
	}

	fieldErrors := map[string]string{}
	kind := provider.Kind(in.Provider)
	if !kind.Valid() {
		fieldErrors["provider"] = FieldProviderInvalid
	}
	baseURL := ""
	if kind.RequiresBaseURL() {
		normalized, err := s.policy.ValidateBaseURL(in.BaseURL)
		switch {
		case errors.Is(err, provider.ErrBaseURLNotAllowed):
			fieldErrors["base_url"] = FieldBaseURLNotAllowed
		case err != nil:
			fieldErrors["base_url"] = FieldBaseURLInvalid
		}
		baseURL = normalized
	}
	model := strings.TrimSpace(in.Model)
	if model == "" {
		fieldErrors["model"] = apierror.FieldRequired
	} else if utf8.RuneCountInString(model) > MaxModelLength {
		fieldErrors["model"] = FieldTextTooLong
	}
	var newKey *string
	if in.APIKey != nil {
		k := strings.TrimSpace(*in.APIKey)
		if utf8.RuneCountInString(k) > MaxAPIKeyLength {
			fieldErrors["api_key"] = FieldTextTooLong
		}
		newKey = &k
	}
	if in.MaxOutputTokens < MinMaxOutputTokens || in.MaxOutputTokens > MaxMaxOutputTokens {
		fieldErrors["max_output_tokens"] = FieldOutOfRange
	}
	if in.InputPricePerMTok != nil && *in.InputPricePerMTok < 0 {
		fieldErrors["input_price_per_mtok"] = apierror.FieldNegativeNotAllowed
	}
	if in.OutputPricePerMTok != nil && *in.OutputPricePerMTok < 0 {
		fieldErrors["output_price_per_mtok"] = apierror.FieldNegativeNotAllowed
	}
	if len(fieldErrors) > 0 {
		return settingsResponse{}, apierror.NewValidation(fieldErrors)
	}

	// A provider that needs a key must end up with one: either sent now or
	// already stored for this provider/base URL.
	if kind.RequiresAPIKey() && (newKey == nil || *newKey == "") {
		existing, err := s.repo.FindCredential(ctx, in.UserID, kind, baseURL)
		if err != nil && !errors.Is(err, ErrNotFound) {
			return settingsResponse{}, err
		}
		if newKey != nil || errors.Is(err, ErrNotFound) || !existing.HasKey() {
			return settingsResponse{}, apierror.NewValidation(map[string]string{"api_key": apierror.FieldRequired})
		}
	}

	upsert := UpsertCredentialInput{UserID: in.UserID, Provider: kind, BaseURL: baseURL, Model: model}
	if newKey != nil {
		upsert.SetKey = true
		if *newKey != "" {
			sealed, err := s.box.Seal([]byte(*newKey), credentialAAD(in.UserID, kind, baseURL))
			if err != nil {
				return settingsResponse{}, err
			}
			hint := keyHint(*newKey)
			upsert.APIKeyEncrypted, upsert.APIKeyHint = sealed, &hint
		}
	}

	cred, err := s.repo.UpsertCredential(ctx, upsert)
	if err != nil {
		return settingsResponse{}, err
	}
	_, err = s.repo.SaveSettings(ctx, SaveSettingsRepoInput{
		UserID: in.UserID, ActiveCredentialID: cred.ID, MaxOutputTokens: in.MaxOutputTokens,
		InputPricePerMTok: in.InputPricePerMTok, OutputPricePerMTok: in.OutputPricePerMTok,
		DefaultIncludeTransactions: in.DefaultIncludeTransactions, DefaultAnonymizeTitles: in.DefaultAnonymizeTitles,
	}, in.ExpectedVersion)
	if errors.Is(err, ErrVersionMismatch) {
		return settingsResponse{}, apierror.ErrConflict
	}
	if err != nil {
		return settingsResponse{}, err
	}
	return s.GetSettings(ctx, in.UserID)
}

func (s *Service) DeleteCredential(ctx context.Context, userID, id uuid.UUID) error {
	if err := s.requireAvailable(); err != nil {
		return err
	}
	err := s.repo.DeleteCredential(ctx, userID, id)
	if errors.Is(err, ErrNotFound) {
		return apierror.ErrNotFound
	}
	return err
}

// --- Consent -----------------------------------------------------------------

func (s *Service) AcceptConsent(ctx context.Context, userID uuid.UUID, version int) error {
	if err := s.requireAvailable(); err != nil {
		return err
	}
	if version != ConsentVersion {
		return apierror.NewValidation(map[string]string{"consent_version": FieldConsentVersionInvalid})
	}
	return s.repo.SetConsent(ctx, userID, &version)
}

func (s *Service) RevokeConsent(ctx context.Context, userID uuid.UUID) error {
	if err := s.requireAvailable(); err != nil {
		return err
	}
	return s.repo.SetConsent(ctx, userID, nil)
}

// --- Personal context ----------------------------------------------------------

type userContextResponse struct {
	HouseholdSize *int    `json:"household_size"`
	IncomeType    *string `json:"income_type"`
	AboutMe       *string `json:"about_me"`
	Goals         *string `json:"goals"`
	IgnoreNotes   *string `json:"ignore_notes"`
	ResponseStyle *string `json:"response_style"`
	Version       int64   `json:"version"`
	UpdatedAt     *string `json:"updated_at"`
}

func toUserContextResponse(c UserContext) userContextResponse {
	resp := userContextResponse{
		HouseholdSize: c.HouseholdSize, IncomeType: c.IncomeType, AboutMe: c.AboutMe, Goals: c.Goals,
		IgnoreNotes: c.IgnoreNotes, ResponseStyle: c.ResponseStyle, Version: c.Version,
	}
	if c.UpdatedAt != nil {
		t := c.UpdatedAt.UTC().Format(timeLayout)
		resp.UpdatedAt = &t
	}
	return resp
}

func (s *Service) GetUserContext(ctx context.Context, userID uuid.UUID) (userContextResponse, error) {
	if err := s.requireAvailable(); err != nil {
		return userContextResponse{}, err
	}
	c, err := s.repo.GetUserContext(ctx, userID)
	if err != nil {
		return userContextResponse{}, err
	}
	return toUserContextResponse(c), nil
}

// SaveUserContextInput is PUT /v1/ai/context, a full replacement.
type SaveUserContextInput struct {
	UserID          uuid.UUID
	HouseholdSize   *int
	IncomeType      *string
	AboutMe         *string
	Goals           *string
	IgnoreNotes     *string
	ResponseStyle   *string
	ExpectedVersion int64
}

func (s *Service) SaveUserContext(ctx context.Context, in SaveUserContextInput) (userContextResponse, error) {
	if err := s.requireAvailable(); err != nil {
		return userContextResponse{}, err
	}
	fieldErrors := map[string]string{}
	if in.HouseholdSize != nil && (*in.HouseholdSize < 1 || *in.HouseholdSize > MaxHouseholdSize) {
		fieldErrors["household_size"] = FieldOutOfRange
	}
	incomeType := normalizeText(in.IncomeType)
	if incomeType != nil && !ValidIncomeTypes[*incomeType] {
		fieldErrors["income_type"] = FieldInvalidValue
	}
	responseStyle := normalizeText(in.ResponseStyle)
	if responseStyle != nil && !ValidResponseStyles[*responseStyle] {
		fieldErrors["response_style"] = FieldInvalidValue
	}
	texts := map[string]*string{"about_me": in.AboutMe, "goals": in.Goals, "ignore_notes": in.IgnoreNotes}
	normalized := map[string]*string{}
	for field, v := range texts {
		n := normalizeText(v)
		if n != nil && utf8.RuneCountInString(*n) > MaxContextTextLength {
			fieldErrors[field] = FieldTextTooLong
		}
		normalized[field] = n
	}
	if len(fieldErrors) > 0 {
		return userContextResponse{}, apierror.NewValidation(fieldErrors)
	}

	saved, err := s.repo.SaveUserContext(ctx, UserContext{
		UserID: in.UserID, HouseholdSize: in.HouseholdSize, IncomeType: incomeType,
		AboutMe: normalized["about_me"], Goals: normalized["goals"], IgnoreNotes: normalized["ignore_notes"],
		ResponseStyle: responseStyle,
	}, in.ExpectedVersion)
	if errors.Is(err, ErrVersionMismatch) {
		return userContextResponse{}, apierror.ErrConflict
	}
	if err != nil {
		return userContextResponse{}, err
	}
	return toUserContextResponse(saved), nil
}

// normalizeText trims and maps blank to nil.
func normalizeText(v *string) *string {
	if v == nil {
		return nil
	}
	t := strings.TrimSpace(*v)
	if t == "" {
		return nil
	}
	return &t
}

// --- Provider resolution and probes --------------------------------------------

// resolvedProvider is a ready-to-call provider plus where it came from.
type resolvedProvider struct {
	provider   provider.Provider
	kind       provider.Kind
	model      string
	credential *Credential // the stored credential used, if any
	keyFromDB  bool        // the key came from credential (not from the request)
}

// openKey decrypts a stored key, re-sealing it when it was encrypted with a
// rotated-out key.
func (s *Service) openKey(ctx context.Context, c Credential) (string, error) {
	if !c.HasKey() {
		return "", nil
	}
	aad := credentialAAD(c.UserID, c.Provider, c.BaseURL)
	plain, err := s.box.Open(c.APIKeyEncrypted, aad)
	if err != nil {
		// The encryption key changed without AI_KEY_ENCRYPTION_KEY_PREVIOUS:
		// the stored key is lost and must be entered again.
		return "", apierror.New(http.StatusConflict, "AI_KEY_UNREADABLE", "The stored API key can no longer be read; enter it again.")
	}
	if s.box.NeedsRotation(c.APIKeyEncrypted) {
		if resealed, err := s.box.Seal(plain, aad); err == nil {
			if err := s.repo.ReplaceCredentialKey(ctx, c.ID, resealed); err != nil {
				s.logger.Warn("ai_key_rotation_failed", slog.String("credential_id", c.ID.String()), slog.Any("error", err))
			}
		}
	}
	return string(plain), nil
}

// activeCredential returns the active credential when it is complete
// (model, and a key when the provider needs one), else ErrNotConfigured.
func (s *Service) activeCredential(ctx context.Context, userID uuid.UUID, settings Settings) (Credential, error) {
	if settings.ActiveCredentialID == nil {
		return Credential{}, ErrNotConfigured
	}
	cred, err := s.repo.GetCredential(ctx, userID, *settings.ActiveCredentialID)
	if errors.Is(err, ErrNotFound) {
		return Credential{}, ErrNotConfigured
	}
	if err != nil {
		return Credential{}, err
	}
	if cred.Model == nil || *cred.Model == "" || (cred.Provider.RequiresAPIKey() && !cred.HasKey()) {
		return Credential{}, ErrNotConfigured
	}
	return cred, nil
}

// activeProvider resolves the user's saved configuration for an analysis.
func (s *Service) activeProvider(ctx context.Context, userID uuid.UUID) (resolvedProvider, Settings, error) {
	settings, err := s.repo.GetSettings(ctx, userID)
	if err != nil {
		return resolvedProvider{}, Settings{}, err
	}
	cred, err := s.activeCredential(ctx, userID, settings)
	if err != nil {
		return resolvedProvider{}, settings, err
	}
	key, err := s.openKey(ctx, cred)
	if err != nil {
		return resolvedProvider{}, settings, err
	}
	p, err := s.providers.New(provider.Config{Kind: cred.Provider, BaseURL: cred.BaseURL, APIKey: key})
	if err != nil {
		return resolvedProvider{}, settings, providerAPIError(err)
	}
	return resolvedProvider{provider: p, kind: cred.Provider, model: *cred.Model, credential: &cred, keyFromDB: true}, settings, nil
}

// ProbeInput selects what to probe. With Provider empty the active
// configuration is used; otherwise missing fields fall back to the stored
// credential for that provider/base URL, so a form can be tested before
// it is saved.
type ProbeInput struct {
	UserID   uuid.UUID
	Provider string
	BaseURL  string
	APIKey   string
	Model    string
}

func (s *Service) probeProvider(ctx context.Context, in ProbeInput) (resolvedProvider, error) {
	if in.Provider == "" {
		rp, _, err := s.activeProvider(ctx, in.UserID)
		if errors.Is(err, ErrNotConfigured) {
			return resolvedProvider{}, ErrNotConfigured
		}
		if err != nil {
			return resolvedProvider{}, err
		}
		if m := strings.TrimSpace(in.Model); m != "" {
			rp.model = m
		}
		return rp, nil
	}

	kind := provider.Kind(in.Provider)
	if !kind.Valid() {
		return resolvedProvider{}, apierror.NewValidation(map[string]string{"provider": FieldProviderInvalid})
	}
	baseURL := ""
	if kind.RequiresBaseURL() {
		normalized, err := s.policy.ValidateBaseURL(in.BaseURL)
		if err != nil {
			return resolvedProvider{}, providerAPIError(err)
		}
		baseURL = normalized
	}

	rp := resolvedProvider{kind: kind, model: strings.TrimSpace(in.Model)}
	key := strings.TrimSpace(in.APIKey)
	stored, err := s.repo.FindCredential(ctx, in.UserID, kind, baseURL)
	switch {
	case err == nil:
		rp.credential = &stored
		if key == "" {
			if key, err = s.openKey(ctx, stored); err != nil {
				return resolvedProvider{}, err
			}
			rp.keyFromDB = true
		}
		if rp.model == "" && stored.Model != nil {
			rp.model = *stored.Model
		}
	case !errors.Is(err, ErrNotFound):
		return resolvedProvider{}, err
	}
	if kind.RequiresAPIKey() && key == "" {
		return resolvedProvider{}, apierror.NewValidation(map[string]string{"api_key": apierror.FieldRequired})
	}

	p, err := s.providers.New(provider.Config{Kind: kind, BaseURL: baseURL, APIKey: key})
	if err != nil {
		return resolvedProvider{}, providerAPIError(err)
	}
	rp.provider = p
	return rp, nil
}

type testResponse struct {
	OK           bool    `json:"ok"`
	LatencyMS    int64   `json:"latency_ms"`
	Model        *string `json:"model"`
	ErrorCode    *string `json:"error_code"`
	ErrorMessage *string `json:"error_message"`
}

// TestConnection checks the key (and the model, when one is known) with
// the cheapest possible call. Provider failures are reported in the body,
// not as an HTTP error: the request itself succeeded.
func (s *Service) TestConnection(ctx context.Context, in ProbeInput) (testResponse, error) {
	if err := s.requireAvailable(); err != nil {
		return testResponse{}, err
	}
	if err := s.checkRateLimit(ctx, "probe", in.UserID, probeLimit, probeWindow); err != nil {
		return testResponse{}, err
	}
	rp, err := s.probeProvider(ctx, in)
	if err != nil {
		return testResponse{}, err
	}

	ctx, cancel := context.WithTimeout(ctx, probeTimeout)
	defer cancel()
	start := s.clock.Now()
	if rp.model != "" {
		_, err = rp.provider.Stream(ctx, provider.ChatRequest{
			Model: rp.model, MaxTokens: probeMaxTokens,
			Messages: []provider.Message{{Role: provider.RoleUser, Content: "Reply with OK."}},
		}, func(string) error { return nil })
	} else {
		_, err = rp.provider.ListModels(ctx)
	}
	resp := testResponse{OK: err == nil, LatencyMS: s.clock.Now().Sub(start).Milliseconds()}
	if rp.model != "" {
		m := rp.model
		resp.Model = &m
	}
	if err != nil {
		apiErr := providerAPIError(err)
		resp.ErrorCode, resp.ErrorMessage = &apiErr.Code, &apiErr.Message
	}
	s.logger.Info("ai_probe", slog.String("provider", string(rp.kind)), slog.Bool("ok", resp.OK),
		slog.Int64("latency_ms", resp.LatencyMS))

	// Only a test of the stored key, unchanged, says anything about it.
	if rp.credential != nil && rp.keyFromDB {
		if recErr := s.repo.RecordCredentialTest(context.WithoutCancel(ctx), rp.credential.ID, resp.OK); recErr != nil {
			return testResponse{}, recErr
		}
	}
	return resp, nil
}

type modelResponse struct {
	ID          string `json:"id"`
	DisplayName string `json:"display_name"`
}

func (s *Service) ListModels(ctx context.Context, in ProbeInput) ([]modelResponse, error) {
	if err := s.requireAvailable(); err != nil {
		return nil, err
	}
	if err := s.checkRateLimit(ctx, "probe", in.UserID, probeLimit, probeWindow); err != nil {
		return nil, err
	}
	rp, err := s.probeProvider(ctx, in)
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithTimeout(ctx, probeTimeout)
	defer cancel()
	models, err := rp.provider.ListModels(ctx)
	if err != nil {
		return nil, providerAPIError(err)
	}
	out := make([]modelResponse, 0, min(len(models), maxModelsInReply))
	for _, m := range models {
		if len(out) == maxModelsInReply {
			break
		}
		name := m.DisplayName
		if name == "" {
			name = m.ID
		}
		out = append(out, modelResponse{ID: m.ID, DisplayName: name})
	}
	return out, nil
}
