package ai

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"financial-manager-backend/internal/ai/prompt"
	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/metrics"
)

// On-device analysis (plan.md section 33): the server builds the prompt and
// keeps the history exactly as for a cloud run, but the model runs on the
// user's phone. A run is three calls: prepare (stores the analysis and
// returns what to feed the model), the phone generates, then it submits
// the result. No provider and no encryption key are involved.

var (
	ErrOnDeviceDisabled = apierror.New(http.StatusServiceUnavailable, "AI_ON_DEVICE_DISABLED",
		"On-device analysis is not enabled on this server.")
	ErrLocalConsentRequired = apierror.New(http.StatusForbidden, "AI_LOCAL_CONSENT_REQUIRED",
		"Accept the on-device analysis notice first.")
	ErrAnalysisOnDevice = apierror.New(http.StatusConflict, "AI_ANALYSIS_ON_DEVICE",
		"This analysis was written on your phone: continue it there.")
	ErrAnalysisNotOnDevice = apierror.New(http.StatusConflict, "AI_ANALYSIS_NOT_ON_DEVICE",
		"This analysis was written by a cloud provider.")
	ErrMessageFinished = apierror.New(http.StatusConflict, "AI_MESSAGE_FINISHED",
		"This answer was already saved.")
	ErrLocalContextTooLong = apierror.New(http.StatusUnprocessableEntity, "AI_LOCAL_CONTEXT_TOO_LONG",
		"The prompt doesn't fit the model's context: use the compact profile, a larger context or fewer transactions.")
	ErrAnswerTooLong = apierror.New(http.StatusUnprocessableEntity, "AI_ANSWER_TOO_LONG",
		"The answer is too long to be saved.")
)

// Engines and backends the app may report.
var (
	localEngines  = map[string]string{"litert_lm": "LiteRT-LM", "llama_cpp": "llama.cpp"}
	localBackends = map[string]bool{"cpu": true, "gpu": true, "npu": true}
	// localErrorCodes are the failures a phone may report; anything else
	// is stored as AI_LOCAL_ENGINE_ERROR.
	localErrorCodes = map[string]bool{
		"AI_LOCAL_ENGINE_ERROR": true, "AI_LOCAL_OUT_OF_MEMORY": true, "AI_LOCAL_CONTEXT_TOO_LONG": true,
		"AI_LOCAL_TIMEOUT": true, "AI_LOCAL_MODEL_MISSING": true, "AI_LOCAL_INTERRUPTED": true,
	}
	modelIDPattern = regexp.MustCompile(`^[A-Za-z0-9._:/@+-]{1,200}$`)
)

// Bounds of what a phone may report.
const (
	MinLocalContextTokens = 512
	MaxLocalContextTokens = 131072
	maxLocalTokens        = 1_000_000
	maxLocalDuration      = 24 * time.Hour
)

// LocalRuntime describes how an on-device analysis runs; stored with it.
type LocalRuntime struct {
	Engine          string `json:"engine"`
	ModelID         string `json:"model_id"`
	DisplayName     string `json:"display_name"`
	Quantization    string `json:"quantization"`
	Backend         string `json:"backend"`
	ContextTokens   int    `json:"context_tokens"`
	MaxOutputTokens int    `json:"max_output_tokens"`
	AppVersion      string `json:"app_version,omitempty"`
}

func (r LocalRuntime) validate() map[string]string {
	fieldErrors := map[string]string{}
	if _, ok := localEngines[r.Engine]; !ok {
		fieldErrors["runtime.engine"] = FieldInvalidValue
	}
	if !modelIDPattern.MatchString(r.ModelID) {
		fieldErrors["runtime.model_id"] = FieldInvalidValue
	}
	if n := utf8.RuneCountInString(strings.TrimSpace(r.DisplayName)); n == 0 || n > 100 {
		fieldErrors["runtime.display_name"] = FieldTextTooLong
	}
	if n := utf8.RuneCountInString(strings.TrimSpace(r.Quantization)); n == 0 || n > 32 {
		fieldErrors["runtime.quantization"] = FieldTextTooLong
	}
	if !localBackends[r.Backend] {
		fieldErrors["runtime.backend"] = FieldInvalidValue
	}
	if r.ContextTokens < MinLocalContextTokens || r.ContextTokens > MaxLocalContextTokens {
		fieldErrors["runtime.context_tokens"] = FieldOutOfRange
	}
	if r.MaxOutputTokens < 64 || r.MaxOutputTokens >= r.ContextTokens {
		fieldErrors["runtime.max_output_tokens"] = FieldOutOfRange
	}
	if utf8.RuneCountInString(r.AppVersion) > 32 {
		fieldErrors["runtime.app_version"] = FieldTextTooLong
	}
	return fieldErrors
}

// label is the model shown in the history: "Gemma 4 E2B · int4 · LiteRT-LM".
func (r LocalRuntime) label() string {
	return truncateRunes(strings.TrimSpace(r.DisplayName)+" · "+strings.TrimSpace(r.Quantization)+" · "+localEngines[r.Engine], MaxModelLength)
}

// requireLocalReady checks the on-device path and its consent.
func (s *Service) requireLocalReady(ctx context.Context, userID uuid.UUID) (Settings, error) {
	if err := s.requireFeature(); err != nil {
		return Settings{}, err
	}
	if !s.OnDeviceAvailable() {
		return Settings{}, ErrOnDeviceDisabled
	}
	settings, err := s.repo.GetSettings(ctx, userID)
	if err != nil {
		return Settings{}, err
	}
	if !settings.HasCurrentLocalConsent() {
		return Settings{}, ErrLocalConsentRequired
	}
	return settings, nil
}

type localMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
	// Kind is the stored message kind (CONTEXT, REPORT, QUESTION, ANSWER):
	// the phone sends the whole conversation as one user turn and labels
	// each part with it.
	Kind string `json:"kind"`
}

// localTurnResponse is everything the phone needs to generate one answer.
type localTurnResponse struct {
	AnalysisID      string         `json:"analysis_id"`
	QuestionID      *string        `json:"question_id,omitempty"`
	MessageID       string         `json:"message_id"`
	Kind            string         `json:"kind"`
	SystemPrompt    string         `json:"system_prompt"`
	Messages        []localMessage `json:"messages"`
	MaxOutputTokens int            `json:"max_output_tokens"`
	DeadlineAt      string         `json:"deadline_at"`
}

// system is the prompt to run with: the stored one for the report, the
// one with the follow-up rules for an answer.
func (s *Service) localTurn(a Analysis, answer Message, system string, history []localMessage) localTurnResponse {
	maxOut := 0
	if a.Runtime != nil {
		maxOut = a.Runtime.MaxOutputTokens
	}
	return localTurnResponse{
		AnalysisID: a.ID.String(), MessageID: answer.ID.String(), Kind: answer.Kind,
		SystemPrompt: system, Messages: history, MaxOutputTokens: maxOut,
		DeadlineAt: answer.CreatedAt.Add(s.limits.LocalMaxDuration).UTC().Format(timeLayout),
	}
}

// LocalRunRequest is a previewed analysis plus how the phone will run it.
type LocalRunRequest struct {
	RunRequest
	Runtime LocalRuntime `json:"runtime"`
}

// PrepareLocalAnalysis stores an on-device analysis and returns the prompt
// to run. A retry with the same client_request_id while the report is still
// pending returns the same turn, so a phone that crashed can resume.
// created reports whether this call created it.
func (s *Service) PrepareLocalAnalysis(ctx context.Context, userID uuid.UUID, req LocalRunRequest) (resp localTurnResponse, created bool, err error) {
	if _, err := s.requireLocalReady(ctx, userID); err != nil {
		return localTurnResponse{}, false, err
	}
	requestID, err := uuid.Parse(req.ClientRequestID)
	if err != nil {
		return localTurnResponse{}, false, apierror.NewValidation(map[string]string{"client_request_id": apierror.FieldInvalidUUID})
	}
	if existing, err := s.repo.FindAnalysisByRequestID(ctx, userID, requestID); err == nil {
		return s.resumeLocalAnalysis(ctx, existing)
	} else if !errors.Is(err, ErrNotFound) {
		return localTurnResponse{}, false, err
	}
	if fieldErrors := req.Runtime.validate(); len(fieldErrors) > 0 {
		return localTurnResponse{}, false, apierror.NewValidation(fieldErrors)
	}
	if err := s.checkRateLimit(ctx, "local-run", userID, s.limits.LocalRunsPerHour, runWindow); err != nil {
		return localTurnResponse{}, false, err
	}

	bp, err := s.buildPrompt(ctx, userID, req.AnalysisRequest)
	if err != nil {
		return localTurnResponse{}, false, err
	}
	if req.DataFingerprint != bp.prompt.Fingerprint {
		return localTurnResponse{}, false, ErrDataChanged
	}
	if bp.estimated+req.Runtime.MaxOutputTokens > req.Runtime.ContextTokens {
		return localTurnResponse{}, false, ErrLocalContextTooLong
	}

	runtime := req.Runtime
	runtime.DisplayName = strings.TrimSpace(runtime.DisplayName)
	runtime.Quantization = strings.TrimSpace(runtime.Quantization)
	presetInfo, _ := prompt.PresetFor(bp.lang, bp.preset)
	analysis := Analysis{
		UserID: userID, Title: analysisTitle(presetInfo.Title, bp), Preset: bp.preset,
		PeriodFrom: bp.period.From, PeriodTo: bp.period.To, Timezone: bp.loc.String(), WalletIDs: bp.walletIDs,
		Options: bp.options, Provider: ProviderOnDevice, Model: runtime.label(), PromptVersion: bp.prompt.Version,
		SystemPrompt: bp.prompt.System, DataFingerprint: bp.prompt.Fingerprint, ClientRequestID: requestID,
		Runtime: &runtime,
	}
	userMessage := bp.userMessage()
	var stored Analysis
	var report Message
	err = s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		var txErr error
		stored, report, txErr = s.repo.WithQuerier(tx).CreateAnalysis(ctx, analysis, userMessage)
		return txErr
	})
	if errors.Is(err, ErrDuplicateRequest) {
		// Lost a race with a retry of the same request.
		existing, findErr := s.repo.FindAnalysisByRequestID(ctx, userID, requestID)
		if findErr != nil {
			return localTurnResponse{}, false, findErr
		}
		return s.resumeLocalAnalysis(ctx, existing)
	}
	if err != nil {
		return localTurnResponse{}, false, err
	}
	return s.localTurn(stored, report, stored.SystemPrompt, []localMessage{{Role: "user", Content: userMessage, Kind: KindContext}}), true, nil
}

// resumeLocalAnalysis answers a repeated prepare: the same turn while the
// report is pending, a conflict otherwise.
func (s *Service) resumeLocalAnalysis(ctx context.Context, a Analysis) (localTurnResponse, bool, error) {
	if a.Provider != ProviderOnDevice {
		return localTurnResponse{}, false, ErrAnalysisExists
	}
	messages, err := s.repo.ListMessages(ctx, a.ID)
	if err != nil {
		return localTurnResponse{}, false, err
	}
	var contextMsg, report *Message
	for i := range messages {
		switch messages[i].Kind {
		case KindContext:
			contextMsg = &messages[i]
		case KindReport:
			report = &messages[i]
		}
	}
	if contextMsg == nil || report == nil || report.Status != StatusStreaming {
		return localTurnResponse{}, false, ErrAnalysisExists
	}
	return s.localTurn(a, *report, a.SystemPrompt, []localMessage{{Role: "user", Content: contextMsg.Content, Kind: KindContext}}), false, nil
}

// PrepareLocalFollowUp stores a question on an on-device analysis and
// returns the stored conversation to replay on the phone.
func (s *Service) PrepareLocalFollowUp(ctx context.Context, userID, analysisID uuid.UUID, question string) (localTurnResponse, error) {
	if _, err := s.requireLocalReady(ctx, userID); err != nil {
		return localTurnResponse{}, err
	}
	question = strings.TrimSpace(question)
	if question == "" {
		return localTurnResponse{}, apierror.NewValidation(map[string]string{"content": apierror.FieldRequired})
	}
	if utf8.RuneCountInString(question) > MaxQuestionLength {
		return localTurnResponse{}, apierror.NewValidation(map[string]string{"content": FieldTextTooLong})
	}
	analysis, err := s.repo.GetAnalysis(ctx, userID, analysisID)
	if errors.Is(err, ErrNotFound) {
		return localTurnResponse{}, apierror.ErrNotFound
	}
	if err != nil {
		return localTurnResponse{}, err
	}
	if analysis.Provider != ProviderOnDevice {
		return localTurnResponse{}, ErrAnalysisNotOnDevice
	}
	messages, err := s.repo.ListMessages(ctx, analysisID)
	if err != nil {
		return localTurnResponse{}, err
	}
	lang, err := s.analysisLang(ctx, analysis)
	if err != nil {
		return localTurnResponse{}, err
	}
	history, questions, err := s.replayHistory(messages, analysis, lang)
	if err != nil {
		return localTurnResponse{}, err
	}
	if questions >= MaxFollowUps {
		return localTurnResponse{}, ErrFollowUpLimit
	}
	if err := s.checkRateLimit(ctx, "local-run", userID, s.limits.LocalRunsPerHour, runWindow); err != nil {
		return localTurnResponse{}, err
	}

	var q, answer Message
	err = s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		var txErr error
		q, answer, txErr = s.repo.WithQuerier(tx).AppendQuestion(ctx, analysisID, question, analysis.Model)
		return txErr
	})
	if err != nil {
		return localTurnResponse{}, err
	}
	out := make([]localMessage, 0, len(history)+1)
	for _, m := range history {
		out = append(out, localMessage{Role: string(m.Role), Content: m.Content, Kind: m.Kind})
	}
	out = append(out, localMessage{Role: "user", Content: prompt.FollowUpQuestion(question, lang, analysis.Preset), Kind: KindQuestion})
	resp := s.localTurn(analysis, answer, prompt.WithFollowUpRules(analysis.SystemPrompt, lang, analysis.Preset), out)
	qid := q.ID.String()
	resp.QuestionID = &qid
	return resp, nil
}

// LocalResult is what the phone generated for one assistant message.
type LocalResult struct {
	Content      string  `json:"content"`
	Status       string  `json:"status"`
	ErrorCode    *string `json:"error_code"`
	InputTokens  int     `json:"input_tokens"`
	OutputTokens int     `json:"output_tokens"`
	Truncated    bool    `json:"truncated"`
	DurationMs   int     `json:"duration_ms"`
}

// SubmitLocalResult stores a phone's answer. Repeating the same submission
// is accepted (the app retries from its outbox); a different one for a
// message already saved is a conflict.
func (s *Service) SubmitLocalResult(ctx context.Context, userID, analysisID, messageID uuid.UUID, in LocalResult) (messageResponse, error) {
	if err := s.requireFeature(); err != nil {
		return messageResponse{}, err
	}
	if !s.OnDeviceAvailable() {
		return messageResponse{}, ErrOnDeviceDisabled
	}
	analysis, err := s.repo.GetAnalysis(ctx, userID, analysisID)
	if errors.Is(err, ErrNotFound) {
		return messageResponse{}, apierror.ErrNotFound
	}
	if err != nil {
		return messageResponse{}, err
	}
	if analysis.Provider != ProviderOnDevice {
		return messageResponse{}, ErrAnalysisNotOnDevice
	}
	msg, err := s.repo.GetMessage(ctx, analysisID, messageID)
	if errors.Is(err, ErrNotFound) {
		return messageResponse{}, apierror.ErrNotFound
	}
	if err != nil {
		return messageResponse{}, err
	}

	fieldErrors := map[string]string{}
	if msg.Role != "assistant" {
		fieldErrors["message_id"] = FieldInvalidValue
	}
	switch in.Status {
	case StatusCompleted, StatusFailed, StatusCancelled:
	default:
		fieldErrors["status"] = FieldInvalidValue
	}
	if !utf8.ValidString(in.Content) {
		fieldErrors["content"] = FieldInvalidValue
	}
	if in.InputTokens < 0 || in.InputTokens > maxLocalTokens || in.OutputTokens < 0 || in.OutputTokens > maxLocalTokens {
		fieldErrors["output_tokens"] = FieldOutOfRange
	}
	if in.DurationMs < 0 || time.Duration(in.DurationMs)*time.Millisecond > maxLocalDuration {
		fieldErrors["duration_ms"] = FieldOutOfRange
	}
	if len(fieldErrors) > 0 {
		return messageResponse{}, apierror.NewValidation(fieldErrors)
	}
	if len(in.Content) > maxStoredAnswerBytes {
		return messageResponse{}, ErrAnswerTooLong
	}
	var errorCode *string
	if in.Status == StatusFailed {
		code := "AI_LOCAL_ENGINE_ERROR"
		if in.ErrorCode != nil && localErrorCodes[*in.ErrorCode] {
			code = *in.ErrorCode
		}
		errorCode = &code
	}

	if msg.Status != StatusStreaming {
		if msg.Content == in.Content && msg.Status == in.Status {
			return toMessageResponse(msg), nil
		}
		return messageResponse{}, ErrMessageFinished
	}

	duration := in.DurationMs
	finish := FinishInput{
		Content: in.Content, Status: in.Status, ErrorCode: errorCode, InputTokens: in.InputTokens,
		OutputTokens: in.OutputTokens, Truncated: in.Truncated, DurationMs: &duration,
	}
	if err := s.repo.FinishMessage(ctx, msg, finish); err != nil {
		return messageResponse{}, err
	}
	metrics.AIStreamsTotal.WithLabelValues(ProviderOnDevice, strings.ToLower(in.Status)).Inc()
	metrics.AITokensTotal.WithLabelValues(ProviderOnDevice, "input").Add(float64(in.InputTokens))
	metrics.AITokensTotal.WithLabelValues(ProviderOnDevice, "output").Add(float64(in.OutputTokens))
	engine := ""
	if analysis.Runtime != nil {
		engine = analysis.Runtime.Engine
	}
	s.logger.Info("ai_local_result", slog.String("engine", engine), slog.String("model", analysis.Model),
		slog.String("kind", msg.Kind), slog.String("status", in.Status),
		slog.Int("input_tokens", in.InputTokens), slog.Int("output_tokens", in.OutputTokens),
		slog.Int("duration_ms", in.DurationMs))

	updated, err := s.repo.GetMessage(ctx, analysisID, messageID)
	if err != nil {
		return messageResponse{}, err
	}
	return toMessageResponse(updated), nil
}

func toMessageResponse(m Message) messageResponse {
	return messageResponse{
		ID: m.ID.String(), Seq: m.Seq, Role: m.Role, Kind: m.Kind, Content: m.Content, Status: m.Status,
		ErrorCode: m.ErrorCode, Model: m.Model, InputTokens: m.InputTokens, OutputTokens: m.OutputTokens,
		Truncated: m.Truncated, CreatedAt: m.CreatedAt.UTC().Format(timeLayout), DurationMs: m.DurationMs,
	}
}
