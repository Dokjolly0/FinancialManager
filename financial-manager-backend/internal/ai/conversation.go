package ai

import (
	"context"
	"encoding/base64"
	"errors"
	"log/slog"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"financial-manager-backend/internal/ai/prompt"
	"financial-manager-backend/internal/ai/provider"
	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/metrics"
)

const (
	MaxFollowUps          = 20
	MaxQuestionLength     = 2000
	MaxTitleLength        = 200
	maxStoredAnswerBytes  = 200 << 10
	runWindow             = time.Hour
	finishTimeout         = 5 * time.Second
	staleStreamGrace      = time.Minute
	defaultHistoryPage    = 20
	maxHistoryPage        = 50
	streamLockKeyPrefix   = "ai:stream:"
	errorCodeInterrupted  = "AI_STREAM_INTERRUPTED"
	errorCodeAnswerTooBig = "AI_ANSWER_TOO_LONG"
)

var (
	ErrStreamInProgress = apierror.New(http.StatusConflict, "AI_STREAM_IN_PROGRESS",
		"Another analysis is still being written: wait for it to finish or stop it.")
	ErrFollowUpLimit = apierror.New(http.StatusConflict, "AI_FOLLOWUP_LIMIT",
		"This analysis reached the maximum number of follow-up questions: start a new analysis.")
	ErrAnalysisExists = apierror.New(http.StatusConflict, "AI_ANALYSIS_EXISTS",
		"This analysis was already started: open it from the history.")
	ErrAnalysisNotReady = apierror.New(http.StatusConflict, "AI_ANALYSIS_NOT_READY",
		"Follow-up questions need a finished report.")

	errAnswerTooLong = errors.New("answer exceeds the stored size limit")
)

// Turn is one model response about to be streamed: a report or an answer.
// Prepare* return it before any response byte is written, so every
// validation failure is still a normal JSON error.
type Turn struct {
	Analysis Analysis
	Message  Message
	request  provider.ChatRequest
	provider provider.Provider
	kind     provider.Kind
	release  func()
}

// Release frees the per-user stream lock. StreamTurn calls it; callers
// that never stream must call it themselves.
func (t Turn) Release() {
	if t.release != nil {
		t.release()
	}
}

// RunRequest starts an analysis: the previewed request plus the preview's
// fingerprint and a client-generated id that makes retries idempotent.
type RunRequest struct {
	AnalysisRequest
	DataFingerprint string `json:"data_fingerprint"`
	ClientRequestID string `json:"client_request_id"`
}

func (s *Service) lockStream(ctx context.Context, userID uuid.UUID) (func(), error) {
	release, ok, err := s.locker.TryLock(ctx, streamLockKeyPrefix+userID.String(), s.limits.StreamMaxDuration+30*time.Second)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, ErrStreamInProgress
	}
	return release, nil
}

// PrepareAnalysis validates a run, checks that the data still matches the
// preview, takes the stream lock and stores the analysis.
func (s *Service) PrepareAnalysis(ctx context.Context, userID uuid.UUID, req RunRequest) (Turn, error) {
	if _, _, err := s.requireReady(ctx, userID, req.CredentialID); err != nil {
		return Turn{}, err
	}
	clientRequestID, err := uuid.Parse(req.ClientRequestID)
	if err != nil {
		return Turn{}, apierror.NewValidation(map[string]string{"client_request_id": apierror.FieldInvalidUUID})
	}
	if err := s.checkRateLimit(ctx, "run", userID, s.limits.RunsPerHour, runWindow); err != nil {
		return Turn{}, err
	}

	bp, err := s.buildPrompt(ctx, userID, req.AnalysisRequest)
	if err != nil {
		return Turn{}, err
	}
	if req.DataFingerprint != bp.prompt.Fingerprint {
		return Turn{}, ErrDataChanged
	}
	rp, settings, err := s.providerFor(ctx, userID, req.CredentialID)
	if err != nil {
		return Turn{}, err
	}

	release, err := s.lockStream(ctx, userID)
	if err != nil {
		return Turn{}, err
	}

	presetInfo, _ := prompt.PresetFor(bp.lang, bp.preset)
	analysis := Analysis{
		UserID: userID, Title: analysisTitle(presetInfo.Title, bp), Preset: bp.preset,
		PeriodFrom: bp.period.From, PeriodTo: bp.period.To, Timezone: bp.loc.String(), WalletIDs: bp.walletIDs,
		Options: bp.options, Provider: string(rp.kind), Model: rp.model, PromptVersion: bp.prompt.Version,
		SystemPrompt: bp.prompt.System, DataFingerprint: bp.prompt.Fingerprint, ClientRequestID: clientRequestID,
		CredentialID: &rp.credential.ID,
	}
	userMessage := bp.userMessage()

	var created Analysis
	var report Message
	err = s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		var txErr error
		created, report, txErr = s.repo.WithQuerier(tx).CreateAnalysis(ctx, analysis, userMessage)
		return txErr
	})
	if err != nil {
		release()
		if errors.Is(err, ErrDuplicateRequest) {
			return Turn{}, ErrAnalysisExists
		}
		return Turn{}, err
	}

	return Turn{
		Analysis: created, Message: report, provider: rp.provider, kind: rp.kind, release: release,
		request: provider.ChatRequest{
			Model: rp.model, System: bp.prompt.System, MaxTokens: settings.MaxOutputTokens,
			Messages: []provider.Message{{Role: provider.RoleUser, Content: userMessage}},
		},
	}, nil
}

func analysisTitle(presetTitle string, bp builtPrompt) string {
	to := bp.period.To.In(bp.loc).Add(-time.Nanosecond).Format("2006-01-02")
	if bp.period.From == nil {
		return truncateRunes(presetTitle+" · → "+to, MaxTitleLength)
	}
	return truncateRunes(presetTitle+" · "+bp.period.From.In(bp.loc).Format("2006-01-02")+" → "+to, MaxTitleLength)
}

func truncateRunes(s string, n int) string {
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	return string([]rune(s)[:n])
}

// PrepareFollowUp validates a follow-up question on a finished analysis and
// stores it. The conversation sent is the stored one: system prompt,
// original data message, report, and earlier answered questions.
func (s *Service) PrepareFollowUp(ctx context.Context, userID, analysisID uuid.UUID, question string) (Turn, error) {
	if err := s.requireAvailable(); err != nil {
		return Turn{}, err
	}
	settings, err := s.repo.GetSettings(ctx, userID)
	if err != nil {
		return Turn{}, err
	}
	if !settings.HasCurrentConsent() {
		return Turn{}, ErrConsentRequired
	}
	question = strings.TrimSpace(question)
	if question == "" {
		return Turn{}, apierror.NewValidation(map[string]string{"content": apierror.FieldRequired})
	}
	if utf8.RuneCountInString(question) > MaxQuestionLength {
		return Turn{}, apierror.NewValidation(map[string]string{"content": FieldTextTooLong})
	}

	analysis, err := s.repo.GetAnalysis(ctx, userID, analysisID)
	if errors.Is(err, ErrNotFound) {
		return Turn{}, apierror.ErrNotFound
	}
	if err != nil {
		return Turn{}, err
	}
	if analysis.Provider == ProviderOnDevice {
		// Continuing on a cloud provider would send the data to a third
		// party the user chose not to involve.
		return Turn{}, ErrAnalysisOnDevice
	}
	messages, err := s.repo.ListMessages(ctx, analysisID)
	if err != nil {
		return Turn{}, err
	}
	history, questions, err := s.replayHistory(messages, analysis.Provider)
	if err != nil {
		return Turn{}, err
	}
	if questions >= MaxFollowUps {
		return Turn{}, ErrFollowUpLimit
	}
	if err := s.checkRateLimit(ctx, "run", userID, s.limits.RunsPerHour, runWindow); err != nil {
		return Turn{}, err
	}
	rp, settings, err := s.followUpProvider(ctx, userID, analysis)
	if err != nil {
		return Turn{}, err
	}

	release, err := s.lockStream(ctx, userID)
	if err != nil {
		return Turn{}, err
	}
	var answer Message
	err = s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		var txErr error
		_, answer, txErr = s.repo.WithQuerier(tx).AppendQuestion(ctx, analysisID, question, rp.model)
		return txErr
	})
	if err != nil {
		release()
		return Turn{}, err
	}

	history = append(history, provider.Message{Role: provider.RoleUser, Content: question})
	return Turn{
		Analysis: analysis, Message: answer, provider: rp.provider, kind: rp.kind, release: release,
		request: provider.ChatRequest{
			Model: rp.model, System: analysis.SystemPrompt, MaxTokens: settings.MaxOutputTokens, Messages: history,
		},
	}, nil
}

// replayHistory rebuilds the conversation from stored messages, keeping
// user/assistant alternation (Anthropic requires it): a question whose
// answer failed or is empty is left out together with that answer.
func (s *Service) replayHistory(messages []Message, analysisProvider string) ([]provider.Message, int, error) {
	now := s.clock.Now()
	var history []provider.Message
	questions := 0
	var reportOK bool
	for i := 0; i < len(messages); i++ {
		m := messages[i]
		status := s.effectiveStatus(m.Status, m.UpdatedAt, now, analysisProvider)
		switch m.Kind {
		case KindContext:
			history = append(history, provider.Message{Role: provider.RoleUser, Content: m.Content})
		case KindReport:
			if status == StatusStreaming {
				return nil, 0, ErrStreamInProgress
			}
			if status == StatusFailed || strings.TrimSpace(m.Content) == "" {
				return nil, 0, ErrAnalysisNotReady
			}
			reportOK = true
			history = append(history, provider.Message{Role: provider.RoleAssistant, Content: m.Content})
		case KindQuestion:
			questions++
			if i+1 >= len(messages) || messages[i+1].Kind != KindAnswer {
				continue
			}
			answer := messages[i+1]
			answerStatus := s.effectiveStatus(answer.Status, answer.UpdatedAt, now, analysisProvider)
			if answerStatus == StatusStreaming {
				return nil, 0, ErrStreamInProgress
			}
			if answerStatus != StatusFailed && strings.TrimSpace(answer.Content) != "" {
				history = append(history,
					provider.Message{Role: provider.RoleUser, Content: m.Content},
					provider.Message{Role: provider.RoleAssistant, Content: answer.Content})
			}
			i++
		}
	}
	if !reportOK {
		return nil, 0, ErrAnalysisNotReady
	}
	return history, questions, nil
}

// effectiveStatus reports a STREAMING row whose stream cannot still be
// running (the process died mid-stream) as FAILED.
// A phone may take much longer than a cloud stream, so on-device rows get
// their own window (AI_LOCAL_MAX_DURATION).
func (s *Service) effectiveStatus(status string, updatedAt, now time.Time, analysisProvider string) string {
	window := s.limits.StreamMaxDuration
	if analysisProvider == ProviderOnDevice {
		window = s.limits.LocalMaxDuration
	}
	if status == StatusStreaming && now.Sub(updatedAt) > window+staleStreamGrace {
		return StatusFailed
	}
	return status
}

// StreamTurn runs the model and relays its text to sink, then stores the
// outcome. Events: meta, delta*, then either usage+done, or error+done.
// A client that disconnects cancels the provider call; what was written so
// far is kept as CANCELLED.
func (s *Service) StreamTurn(ctx context.Context, sink EventSink, t Turn) {
	defer t.Release()
	start := s.clock.Now()
	_ = sink.Event("meta", map[string]string{
		"analysis_id": t.Analysis.ID.String(), "message_id": t.Message.ID.String(), "kind": t.Message.Kind,
	})

	streamCtx, cancel := context.WithTimeout(ctx, s.limits.StreamMaxDuration)
	defer cancel()
	var content strings.Builder
	tooLong := false
	result, err := t.provider.Stream(streamCtx, t.request, func(text string) error {
		if content.Len()+len(text) > maxStoredAnswerBytes {
			tooLong = true
			return errAnswerTooLong
		}
		content.WriteString(text)
		return sink.Delta(text)
	})

	finish := FinishInput{
		Content: content.String(), Status: StatusCompleted, InputTokens: result.InputTokens,
		OutputTokens: result.OutputTokens, Truncated: result.Truncated || tooLong,
	}
	var errorEvent map[string]string
	switch {
	case err == nil || errors.Is(err, errAnswerTooLong):
	case ctx.Err() != nil:
		// The client went away: nobody is listening for further events.
		finish.Status = StatusCancelled
	case errors.Is(err, context.DeadlineExceeded) || errors.Is(streamCtx.Err(), context.DeadlineExceeded):
		finish.Status = StatusFailed
		code := "AI_PROVIDER_TIMEOUT"
		finish.ErrorCode = &code
		errorEvent = map[string]string{"code": code, "message": "The analysis took too long and was stopped."}
	default:
		finish.Status = StatusFailed
		apiErr := providerAPIError(err)
		finish.ErrorCode = &apiErr.Code
		errorEvent = map[string]string{"code": apiErr.Code, "message": apiErr.Message}
	}

	persistCtx, cancelPersist := context.WithTimeout(context.WithoutCancel(ctx), finishTimeout)
	defer cancelPersist()
	if perr := s.repo.FinishMessage(persistCtx, t.Message, finish); perr != nil {
		s.logger.Error("ai_finish_failed", slog.String("message_id", t.Message.ID.String()), slog.Any("error", perr))
	}

	metrics.AIStreamsTotal.WithLabelValues(string(t.kind), strings.ToLower(finish.Status)).Inc()
	metrics.AITokensTotal.WithLabelValues(string(t.kind), "input").Add(float64(finish.InputTokens))
	metrics.AITokensTotal.WithLabelValues(string(t.kind), "output").Add(float64(finish.OutputTokens))
	errorCode := ""
	if finish.ErrorCode != nil {
		errorCode = *finish.ErrorCode
	}
	s.logger.Info("ai_stream", slog.String("provider", string(t.kind)), slog.String("model", t.request.Model),
		slog.String("kind", t.Message.Kind), slog.String("status", finish.Status), slog.String("error_code", errorCode),
		slog.Int("input_tokens", finish.InputTokens), slog.Int("output_tokens", finish.OutputTokens),
		slog.Duration("duration", s.clock.Now().Sub(start)))

	if finish.Status == StatusCancelled {
		return
	}
	if errorEvent != nil {
		_ = sink.Event("error", errorEvent)
	} else {
		_ = sink.Event("usage", map[string]any{
			"input_tokens": finish.InputTokens, "output_tokens": finish.OutputTokens, "truncated": finish.Truncated,
		})
	}
	_ = sink.Event("done", map[string]string{"status": finish.Status})
}

// --- History ------------------------------------------------------------------

type analysisSummary struct {
	ID           string   `json:"id"`
	Title        string   `json:"title"`
	Preset       string   `json:"preset"`
	PeriodFrom   *string  `json:"period_from"`
	PeriodTo     string   `json:"period_to"`
	Status       string   `json:"status"`
	ErrorCode    *string  `json:"error_code"`
	Provider     string   `json:"provider"`
	Model        string   `json:"model"`
	InputTokens  int      `json:"input_tokens"`
	OutputTokens int      `json:"output_tokens"`
	Cost         *float64 `json:"cost"`
	// Runtime is set for on-device analyses: engine, model, quantization.
	Runtime   *LocalRuntime `json:"runtime"`
	CreatedAt string        `json:"created_at"`
	UpdatedAt string        `json:"updated_at"`
}

type messageResponse struct {
	ID           string  `json:"id"`
	Seq          int     `json:"seq"`
	Role         string  `json:"role"`
	Kind         string  `json:"kind"`
	Content      string  `json:"content"`
	Status       string  `json:"status"`
	ErrorCode    *string `json:"error_code"`
	Model        *string `json:"model"`
	InputTokens  *int    `json:"input_tokens"`
	OutputTokens *int    `json:"output_tokens"`
	Truncated    bool    `json:"truncated"`
	CreatedAt    string  `json:"created_at"`
	DurationMs   *int    `json:"duration_ms"`
}

type analysisDetail struct {
	analysisSummary
	Timezone        string            `json:"timezone"`
	WalletIDs       []string          `json:"wallet_ids"`
	Options         AnalysisOptions   `json:"options"`
	PromptVersion   string            `json:"prompt_version"`
	SystemPrompt    string            `json:"system_prompt"`
	FollowUpsLeft   int               `json:"follow_ups_left"`
	CanAskFollowUps bool              `json:"can_ask_follow_ups"`
	Messages        []messageResponse `json:"messages"`
}

func actualCost(settings Settings, analysisProvider string, in, out int) *float64 {
	if analysisProvider == ProviderOnDevice || (settings.InputPricePerMTok == nil && settings.OutputPricePerMTok == nil) {
		return nil
	}
	var c float64
	if settings.InputPricePerMTok != nil {
		c += float64(in) * *settings.InputPricePerMTok / 1e6
	}
	if settings.OutputPricePerMTok != nil {
		c += float64(out) * *settings.OutputPricePerMTok / 1e6
	}
	return &c
}

func (s *Service) toSummary(a Analysis, settings Settings) analysisSummary {
	sum := analysisSummary{
		ID: a.ID.String(), Title: a.Title, Preset: a.Preset, Status: a.Status, ErrorCode: a.ErrorCode,
		Provider: a.Provider, Model: a.Model, InputTokens: a.InputTokensTotal, OutputTokens: a.OutputTokensTotal,
		Cost:      actualCost(settings, a.Provider, a.InputTokensTotal, a.OutputTokensTotal),
		Runtime:   a.Runtime,
		CreatedAt: a.CreatedAt.UTC().Format(timeLayout), UpdatedAt: a.UpdatedAt.UTC().Format(timeLayout),
	}
	loc, err := time.LoadLocation(a.Timezone)
	if err != nil {
		loc = time.UTC
	}
	if a.PeriodFrom != nil {
		f := a.PeriodFrom.In(loc).Format("2006-01-02")
		sum.PeriodFrom = &f
	}
	sum.PeriodTo = a.PeriodTo.In(loc).Add(-time.Nanosecond).Format("2006-01-02")
	if effective := s.effectiveStatus(a.Status, a.UpdatedAt, s.clock.Now(), a.Provider); effective != a.Status {
		sum.Status = effective
		code := errorCodeInterrupted
		sum.ErrorCode = &code
	}
	return sum
}

type historyPage struct {
	Items      []analysisSummary `json:"items"`
	NextCursor *string           `json:"next_cursor"`
}

func encodeCursor(a Analysis) string {
	return base64.RawURLEncoding.EncodeToString([]byte(a.CreatedAt.UTC().Format(time.RFC3339Nano) + "|" + a.ID.String()))
}

func decodeCursor(raw string) (*AnalysisCursor, error) {
	if raw == "" {
		return nil, nil
	}
	b, err := base64.RawURLEncoding.DecodeString(raw)
	if err != nil {
		return nil, err
	}
	ts, id, ok := strings.Cut(string(b), "|")
	if !ok {
		return nil, errors.New("bad cursor")
	}
	createdAt, err := time.Parse(time.RFC3339Nano, ts)
	if err != nil {
		return nil, err
	}
	uid, err := uuid.Parse(id)
	if err != nil {
		return nil, err
	}
	return &AnalysisCursor{CreatedAt: createdAt, ID: uid}, nil
}

func (s *Service) ListAnalyses(ctx context.Context, userID uuid.UUID, cursor string, limit int) (historyPage, error) {
	if err := s.requireFeature(); err != nil {
		return historyPage{}, err
	}
	after, err := decodeCursor(cursor)
	if err != nil {
		return historyPage{}, apierror.NewValidation(map[string]string{"cursor": FieldInvalidValue})
	}
	if limit <= 0 {
		limit = defaultHistoryPage
	}
	limit = min(limit, maxHistoryPage)
	list, err := s.repo.ListAnalyses(ctx, userID, after, limit+1)
	if err != nil {
		return historyPage{}, err
	}
	settings, err := s.repo.GetSettings(ctx, userID)
	if err != nil {
		return historyPage{}, err
	}
	page := historyPage{Items: make([]analysisSummary, 0, min(len(list), limit))}
	for i, a := range list {
		if i == limit {
			next := encodeCursor(list[limit-1])
			page.NextCursor = &next
			break
		}
		page.Items = append(page.Items, s.toSummary(a, settings))
	}
	return page, nil
}

func (s *Service) GetAnalysis(ctx context.Context, userID, id uuid.UUID) (analysisDetail, error) {
	if err := s.requireFeature(); err != nil {
		return analysisDetail{}, err
	}
	a, err := s.repo.GetAnalysis(ctx, userID, id)
	if errors.Is(err, ErrNotFound) {
		return analysisDetail{}, apierror.ErrNotFound
	}
	if err != nil {
		return analysisDetail{}, err
	}
	messages, err := s.repo.ListMessages(ctx, id)
	if err != nil {
		return analysisDetail{}, err
	}
	settings, err := s.repo.GetSettings(ctx, userID)
	if err != nil {
		return analysisDetail{}, err
	}

	detail := analysisDetail{
		analysisSummary: s.toSummary(a, settings), Timezone: a.Timezone, Options: a.Options,
		PromptVersion: a.PromptVersion, SystemPrompt: a.SystemPrompt, Messages: make([]messageResponse, 0, len(messages)),
		WalletIDs: make([]string, len(a.WalletIDs)),
	}
	for i, w := range a.WalletIDs {
		detail.WalletIDs[i] = w.String()
	}
	now := s.clock.Now()
	for _, m := range messages {
		mr := messageResponse{
			ID: m.ID.String(), Seq: m.Seq, Role: m.Role, Kind: m.Kind, Content: m.Content, Status: m.Status,
			ErrorCode: m.ErrorCode, Model: m.Model, InputTokens: m.InputTokens, OutputTokens: m.OutputTokens,
			Truncated: m.Truncated, CreatedAt: m.CreatedAt.UTC().Format(timeLayout), DurationMs: m.DurationMs,
		}
		if effective := s.effectiveStatus(m.Status, m.UpdatedAt, now, a.Provider); effective != m.Status {
			mr.Status = effective
			code := errorCodeInterrupted
			mr.ErrorCode = &code
		}
		detail.Messages = append(detail.Messages, mr)
	}
	if _, questions, err := s.replayHistory(messages, a.Provider); err == nil {
		detail.FollowUpsLeft = max(MaxFollowUps-questions, 0)
		detail.CanAskFollowUps = detail.FollowUpsLeft > 0
	}
	return detail, nil
}

func (s *Service) RenameAnalysis(ctx context.Context, userID, id uuid.UUID, title string) (analysisDetail, error) {
	if err := s.requireFeature(); err != nil {
		return analysisDetail{}, err
	}
	title = strings.TrimSpace(title)
	if title == "" {
		return analysisDetail{}, apierror.NewValidation(map[string]string{"title": apierror.FieldRequired})
	}
	if utf8.RuneCountInString(title) > MaxTitleLength {
		return analysisDetail{}, apierror.NewValidation(map[string]string{"title": FieldTextTooLong})
	}
	if err := s.repo.RenameAnalysis(ctx, userID, id, title); errors.Is(err, ErrNotFound) {
		return analysisDetail{}, apierror.ErrNotFound
	} else if err != nil {
		return analysisDetail{}, err
	}
	return s.GetAnalysis(ctx, userID, id)
}

func (s *Service) DeleteAnalysis(ctx context.Context, userID, id uuid.UUID) error {
	if err := s.requireFeature(); err != nil {
		return err
	}
	if err := s.repo.DeleteAnalysis(ctx, userID, id); errors.Is(err, ErrNotFound) {
		return apierror.ErrNotFound
	} else if err != nil {
		return err
	}
	return nil
}

func (s *Service) DeleteAllAnalyses(ctx context.Context, userID uuid.UUID) error {
	if err := s.requireFeature(); err != nil {
		return err
	}
	return s.repo.DeleteAllAnalyses(ctx, userID)
}
