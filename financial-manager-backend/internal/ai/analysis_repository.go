package ai

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// Analysis and message statuses (migration 0033).
const (
	StatusStreaming = "STREAMING"
	StatusCompleted = "COMPLETED"
	StatusFailed    = "FAILED"
	StatusCancelled = "CANCELLED"
)

// Message kinds.
const (
	KindContext  = "CONTEXT"
	KindReport   = "REPORT"
	KindQuestion = "QUESTION"
	KindAnswer   = "ANSWER"
)

type Analysis struct {
	ID                uuid.UUID
	UserID            uuid.UUID
	Title             string
	Preset            string
	PeriodFrom        *time.Time
	PeriodTo          time.Time
	Timezone          string
	WalletIDs         []uuid.UUID
	Options           AnalysisOptions
	Provider          string
	Model             string
	PromptVersion     string
	SystemPrompt      string
	DataFingerprint   string
	Status            string
	ErrorCode         *string
	InputTokensTotal  int
	OutputTokensTotal int
	ClientRequestID   uuid.UUID
	CreatedAt         time.Time
	UpdatedAt         time.Time
}

type Message struct {
	ID           uuid.UUID
	AnalysisID   uuid.UUID
	Seq          int
	Role         string
	Kind         string
	Content      string
	Status       string
	ErrorCode    *string
	Model        *string
	InputTokens  *int
	OutputTokens *int
	Truncated    bool
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

const analysisColumns = `
	id, user_id, title, preset, period_from, period_to, timezone, wallet_ids, options, provider, model,
	prompt_version, system_prompt, data_fingerprint, status, error_code, input_tokens_total,
	output_tokens_total, client_request_id, created_at, updated_at
`

func scanAnalysis(row pgx.Row) (Analysis, error) {
	var a Analysis
	err := row.Scan(&a.ID, &a.UserID, &a.Title, &a.Preset, &a.PeriodFrom, &a.PeriodTo, &a.Timezone, &a.WalletIDs,
		&a.Options, &a.Provider, &a.Model, &a.PromptVersion, &a.SystemPrompt, &a.DataFingerprint, &a.Status,
		&a.ErrorCode, &a.InputTokensTotal, &a.OutputTokensTotal, &a.ClientRequestID, &a.CreatedAt, &a.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Analysis{}, ErrNotFound
	}
	if err != nil {
		return Analysis{}, fmt.Errorf("scan ai analysis: %w", err)
	}
	return a, nil
}

const messageColumns = `
	id, analysis_id, seq, role, kind, content, status, error_code, model, input_tokens, output_tokens,
	truncated, created_at, updated_at
`

func scanMessage(row pgx.Row) (Message, error) {
	var m Message
	err := row.Scan(&m.ID, &m.AnalysisID, &m.Seq, &m.Role, &m.Kind, &m.Content, &m.Status, &m.ErrorCode, &m.Model,
		&m.InputTokens, &m.OutputTokens, &m.Truncated, &m.CreatedAt, &m.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Message{}, ErrNotFound
	}
	if err != nil {
		return Message{}, fmt.Errorf("scan ai message: %w", err)
	}
	return m, nil
}

// ErrDuplicateRequest is returned when client_request_id was already used.
var ErrDuplicateRequest = errors.New("ai: duplicate client request id")

// CreateAnalysis inserts the analysis with its CONTEXT message (the user
// message sent) and an empty, streaming REPORT message. Run it in a
// transaction (see Service).
func (r *Repository) CreateAnalysis(ctx context.Context, a Analysis, userMessage string) (Analysis, Message, error) {
	created, err := scanAnalysis(r.db.QueryRow(ctx, `
		INSERT INTO ai_analyses (user_id, title, preset, period_from, period_to, timezone, wallet_ids, options,
			provider, model, prompt_version, system_prompt, data_fingerprint, status, client_request_id)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
		RETURNING `+analysisColumns,
		a.UserID, a.Title, a.Preset, a.PeriodFrom, a.PeriodTo, a.Timezone, a.WalletIDs, a.Options,
		a.Provider, a.Model, a.PromptVersion, a.SystemPrompt, a.DataFingerprint, StatusStreaming, a.ClientRequestID))
	if isUniqueViolation(err) {
		return Analysis{}, Message{}, ErrDuplicateRequest
	}
	if err != nil {
		return Analysis{}, Message{}, err
	}
	if _, err := r.insertMessage(ctx, created.ID, 1, "user", KindContext, userMessage, StatusCompleted, nil); err != nil {
		return Analysis{}, Message{}, err
	}
	report, err := r.insertMessage(ctx, created.ID, 2, "assistant", KindReport, "", StatusStreaming, &a.Model)
	if err != nil {
		return Analysis{}, Message{}, err
	}
	return created, report, nil
}

func (r *Repository) insertMessage(ctx context.Context, analysisID uuid.UUID, seq int, role, kind, content, status string, model *string) (Message, error) {
	return scanMessage(r.db.QueryRow(ctx, `
		INSERT INTO ai_messages (analysis_id, seq, role, kind, content, status, model)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING `+messageColumns, analysisID, seq, role, kind, content, status, model))
}

// AppendQuestion adds a follow-up question and an empty, streaming answer
// after the last message. The (analysis_id, seq) unique key makes two
// concurrent follow-ups on the same analysis collide instead of interleave.
func (r *Repository) AppendQuestion(ctx context.Context, analysisID uuid.UUID, question, model string) (Message, Message, error) {
	var last int
	if err := r.db.QueryRow(ctx, `SELECT COALESCE(MAX(seq), 0) FROM ai_messages WHERE analysis_id = $1`, analysisID).Scan(&last); err != nil {
		return Message{}, Message{}, fmt.Errorf("last ai message seq: %w", err)
	}
	q, err := r.insertMessage(ctx, analysisID, last+1, "user", KindQuestion, question, StatusCompleted, nil)
	if isUniqueViolation(err) {
		return Message{}, Message{}, ErrStreamInProgress
	}
	if err != nil {
		return Message{}, Message{}, err
	}
	a, err := r.insertMessage(ctx, analysisID, last+2, "assistant", KindAnswer, "", StatusStreaming, &model)
	if err != nil {
		return Message{}, Message{}, err
	}
	return q, a, nil
}

// FinishInput is the outcome of a stream.
type FinishInput struct {
	Content      string
	Status       string
	ErrorCode    *string
	InputTokens  int
	OutputTokens int
	Truncated    bool
}

// FinishMessage stores a stream's outcome on its message and adds its
// tokens to the analysis; for the REPORT it also sets the analysis status.
func (r *Repository) FinishMessage(ctx context.Context, m Message, in FinishInput) error {
	var inTok, outTok *int
	if in.InputTokens > 0 || in.OutputTokens > 0 {
		inTok, outTok = &in.InputTokens, &in.OutputTokens
	}
	if _, err := r.db.Exec(ctx, `
		UPDATE ai_messages SET content = $2, status = $3, error_code = $4, input_tokens = $5, output_tokens = $6,
			truncated = $7, updated_at = now()
		WHERE id = $1`, m.ID, in.Content, in.Status, in.ErrorCode, inTok, outTok, in.Truncated); err != nil {
		return fmt.Errorf("finish ai message: %w", err)
	}
	if m.Kind == KindReport {
		_, err := r.db.Exec(ctx, `
			UPDATE ai_analyses SET status = $2, error_code = $3, input_tokens_total = input_tokens_total + $4,
				output_tokens_total = output_tokens_total + $5, updated_at = now()
			WHERE id = $1`, m.AnalysisID, in.Status, in.ErrorCode, in.InputTokens, in.OutputTokens)
		if err != nil {
			return fmt.Errorf("finish ai analysis: %w", err)
		}
		return nil
	}
	_, err := r.db.Exec(ctx, `
		UPDATE ai_analyses SET input_tokens_total = input_tokens_total + $2,
			output_tokens_total = output_tokens_total + $3, updated_at = now()
		WHERE id = $1`, m.AnalysisID, in.InputTokens, in.OutputTokens)
	if err != nil {
		return fmt.Errorf("add ai analysis tokens: %w", err)
	}
	return nil
}

func (r *Repository) GetAnalysis(ctx context.Context, userID, id uuid.UUID) (Analysis, error) {
	return scanAnalysis(r.db.QueryRow(ctx, `SELECT `+analysisColumns+` FROM ai_analyses WHERE id = $1 AND user_id = $2`, id, userID))
}

func (r *Repository) ListMessages(ctx context.Context, analysisID uuid.UUID) ([]Message, error) {
	rows, err := r.db.Query(ctx, `SELECT `+messageColumns+` FROM ai_messages WHERE analysis_id = $1 ORDER BY seq`, analysisID)
	if err != nil {
		return nil, fmt.Errorf("list ai messages: %w", err)
	}
	defer rows.Close()
	var out []Message
	for rows.Next() {
		m, err := scanMessage(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// AnalysisCursor is the keyset position of the last item of a page.
type AnalysisCursor struct {
	CreatedAt time.Time
	ID        uuid.UUID
}

// ListAnalyses returns a page of the user's analyses, newest first.
func (r *Repository) ListAnalyses(ctx context.Context, userID uuid.UUID, after *AnalysisCursor, limit int) ([]Analysis, error) {
	var createdAt *time.Time
	var id *uuid.UUID
	if after != nil {
		createdAt, id = &after.CreatedAt, &after.ID
	}
	rows, err := r.db.Query(ctx, `SELECT `+analysisColumns+` FROM ai_analyses
		WHERE user_id = $1 AND ($2::timestamptz IS NULL OR (created_at, id) < ($2, $3::uuid))
		ORDER BY created_at DESC, id DESC
		LIMIT $4`, userID, createdAt, id, limit)
	if err != nil {
		return nil, fmt.Errorf("list ai analyses: %w", err)
	}
	defer rows.Close()
	var out []Analysis
	for rows.Next() {
		a, err := scanAnalysis(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

func (r *Repository) CountAnalyses(ctx context.Context, userID uuid.UUID) (int, error) {
	var n int
	if err := r.db.QueryRow(ctx, `SELECT count(*) FROM ai_analyses WHERE user_id = $1`, userID).Scan(&n); err != nil {
		return 0, fmt.Errorf("count ai analyses: %w", err)
	}
	return n, nil
}

func (r *Repository) RenameAnalysis(ctx context.Context, userID, id uuid.UUID, title string) error {
	tag, err := r.db.Exec(ctx, `UPDATE ai_analyses SET title = $3, updated_at = now() WHERE id = $1 AND user_id = $2`, id, userID, title)
	if err != nil {
		return fmt.Errorf("rename ai analysis: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repository) DeleteAnalysis(ctx context.Context, userID, id uuid.UUID) error {
	tag, err := r.db.Exec(ctx, `DELETE FROM ai_analyses WHERE id = $1 AND user_id = $2`, id, userID)
	if err != nil {
		return fmt.Errorf("delete ai analysis: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repository) DeleteAllAnalyses(ctx context.Context, userID uuid.UUID) error {
	if _, err := r.db.Exec(ctx, `DELETE FROM ai_analyses WHERE user_id = $1`, userID); err != nil {
		return fmt.Errorf("delete ai analyses: %w", err)
	}
	return nil
}
