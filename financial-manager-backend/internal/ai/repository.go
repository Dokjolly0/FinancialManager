package ai

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"financial-manager-backend/internal/ai/provider"
	"financial-manager-backend/internal/platform/database"
)

var (
	ErrNotFound        = errors.New("ai: not found")
	ErrVersionMismatch = errors.New("ai: version mismatch")
)

type Repository struct {
	db database.Querier
}

func NewRepository(db database.Querier) *Repository {
	return &Repository{db: db}
}

// WithQuerier returns a repository bound to a different Querier (typically
// a pgx.Tx).
func (r *Repository) WithQuerier(q database.Querier) *Repository {
	return &Repository{db: q}
}

// --- Credentials -------------------------------------------------------------

const credentialColumns = `
	id, user_id, provider, base_url, api_key_encrypted, api_key_hint, model,
	last_tested_at, last_test_ok, created_at, updated_at
`

func scanCredential(row pgx.Row) (Credential, error) {
	var c Credential
	var kind string
	err := row.Scan(&c.ID, &c.UserID, &kind, &c.BaseURL, &c.APIKeyEncrypted, &c.APIKeyHint, &c.Model,
		&c.LastTestedAt, &c.LastTestOK, &c.CreatedAt, &c.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Credential{}, ErrNotFound
	}
	if err != nil {
		return Credential{}, fmt.Errorf("scan ai credential: %w", err)
	}
	c.Provider = provider.Kind(kind)
	return c, nil
}

func (r *Repository) ListCredentials(ctx context.Context, userID uuid.UUID) ([]Credential, error) {
	rows, err := r.db.Query(ctx, `SELECT `+credentialColumns+` FROM ai_provider_credentials
		WHERE user_id = $1 ORDER BY created_at ASC`, userID)
	if err != nil {
		return nil, fmt.Errorf("list ai credentials: %w", err)
	}
	defer rows.Close()
	var out []Credential
	for rows.Next() {
		c, err := scanCredential(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (r *Repository) GetCredential(ctx context.Context, userID, id uuid.UUID) (Credential, error) {
	return scanCredential(r.db.QueryRow(ctx, `SELECT `+credentialColumns+` FROM ai_provider_credentials
		WHERE id = $1 AND user_id = $2`, id, userID))
}

func (r *Repository) FindCredential(ctx context.Context, userID uuid.UUID, kind provider.Kind, baseURL string) (Credential, error) {
	return scanCredential(r.db.QueryRow(ctx, `SELECT `+credentialColumns+` FROM ai_provider_credentials
		WHERE user_id = $1 AND provider = $2 AND base_url = $3`, userID, string(kind), baseURL))
}

// UpsertCredentialInput describes a credential save. When SetKey is false
// the stored key is left untouched; when true, APIKeyEncrypted/APIKeyHint
// replace it (both nil clears it).
type UpsertCredentialInput struct {
	UserID          uuid.UUID
	Provider        provider.Kind
	BaseURL         string
	Model           string
	SetKey          bool
	APIKeyEncrypted []byte
	APIKeyHint      *string
}

func (r *Repository) UpsertCredential(ctx context.Context, in UpsertCredentialInput) (Credential, error) {
	return scanCredential(r.db.QueryRow(ctx, `
		INSERT INTO ai_provider_credentials (user_id, provider, base_url, model, api_key_encrypted, api_key_hint)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (user_id, provider, base_url) DO UPDATE SET
			model = EXCLUDED.model,
			api_key_encrypted = CASE WHEN $7 THEN EXCLUDED.api_key_encrypted ELSE ai_provider_credentials.api_key_encrypted END,
			api_key_hint = CASE WHEN $7 THEN EXCLUDED.api_key_hint ELSE ai_provider_credentials.api_key_hint END,
			last_tested_at = CASE WHEN $7 THEN NULL ELSE ai_provider_credentials.last_tested_at END,
			last_test_ok = CASE WHEN $7 THEN NULL ELSE ai_provider_credentials.last_test_ok END,
			updated_at = now()
		RETURNING `+credentialColumns,
		in.UserID, string(in.Provider), in.BaseURL, in.Model, in.APIKeyEncrypted, in.APIKeyHint, in.SetKey))
}

// ReplaceCredentialKey re-seals a key, used for key rotation.
func (r *Repository) ReplaceCredentialKey(ctx context.Context, id uuid.UUID, encrypted []byte) error {
	_, err := r.db.Exec(ctx, `UPDATE ai_provider_credentials SET api_key_encrypted = $1 WHERE id = $2`, encrypted, id)
	if err != nil {
		return fmt.Errorf("replace ai credential key: %w", err)
	}
	return nil
}

func (r *Repository) RecordCredentialTest(ctx context.Context, id uuid.UUID, ok bool) error {
	_, err := r.db.Exec(ctx, `UPDATE ai_provider_credentials SET last_tested_at = now(), last_test_ok = $1 WHERE id = $2`, ok, id)
	if err != nil {
		return fmt.Errorf("record ai credential test: %w", err)
	}
	return nil
}

func (r *Repository) DeleteCredential(ctx context.Context, userID, id uuid.UUID) error {
	tag, err := r.db.Exec(ctx, `DELETE FROM ai_provider_credentials WHERE id = $1 AND user_id = $2`, id, userID)
	if err != nil {
		return fmt.Errorf("delete ai credential: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// --- Settings ----------------------------------------------------------------

const settingsColumns = `
	user_id, active_credential_id, consent_version, consent_accepted_at, max_output_tokens,
	input_price_per_mtok::float8, output_price_per_mtok::float8,
	default_include_transactions, default_anonymize_titles, version
`

// GetSettings returns the user's settings, or the defaults (Version 0)
// when nothing was saved yet.
func (r *Repository) GetSettings(ctx context.Context, userID uuid.UUID) (Settings, error) {
	var s Settings
	err := r.db.QueryRow(ctx, `SELECT `+settingsColumns+` FROM ai_settings WHERE user_id = $1`, userID).Scan(
		&s.UserID, &s.ActiveCredentialID, &s.ConsentVersion, &s.ConsentAcceptedAt, &s.MaxOutputTokens,
		&s.InputPricePerMTok, &s.OutputPricePerMTok, &s.DefaultIncludeTransactions, &s.DefaultAnonymizeTitles, &s.Version)
	if errors.Is(err, pgx.ErrNoRows) {
		return defaultSettings(userID), nil
	}
	if err != nil {
		return Settings{}, fmt.Errorf("get ai settings: %w", err)
	}
	return s, nil
}

// SaveSettingsRepoInput is a full replacement of the editable settings.
type SaveSettingsRepoInput struct {
	UserID                     uuid.UUID
	ActiveCredentialID         uuid.UUID
	MaxOutputTokens            int
	InputPricePerMTok          *float64
	OutputPricePerMTok         *float64
	DefaultIncludeTransactions bool
	DefaultAnonymizeTitles     bool
}

// SaveSettings creates the row (expectedVersion 0) or updates it under
// optimistic locking. ErrVersionMismatch when the version moved on.
func (r *Repository) SaveSettings(ctx context.Context, in SaveSettingsRepoInput, expectedVersion int64) (int64, error) {
	var version int64
	var err error
	if expectedVersion == 0 {
		err = r.db.QueryRow(ctx, `
			INSERT INTO ai_settings (user_id, active_credential_id, max_output_tokens, input_price_per_mtok,
				output_price_per_mtok, default_include_transactions, default_anonymize_titles)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
			ON CONFLICT (user_id) DO NOTHING
			RETURNING version`,
			in.UserID, in.ActiveCredentialID, in.MaxOutputTokens, in.InputPricePerMTok, in.OutputPricePerMTok,
			in.DefaultIncludeTransactions, in.DefaultAnonymizeTitles).Scan(&version)
	} else {
		err = r.db.QueryRow(ctx, `
			UPDATE ai_settings SET active_credential_id = $2, max_output_tokens = $3, input_price_per_mtok = $4,
				output_price_per_mtok = $5, default_include_transactions = $6, default_anonymize_titles = $7,
				version = version + 1, updated_at = now()
			WHERE user_id = $1 AND version = $8
			RETURNING version`,
			in.UserID, in.ActiveCredentialID, in.MaxOutputTokens, in.InputPricePerMTok, in.OutputPricePerMTok,
			in.DefaultIncludeTransactions, in.DefaultAnonymizeTitles, expectedVersion).Scan(&version)
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, ErrVersionMismatch
	}
	if err != nil {
		return 0, fmt.Errorf("save ai settings: %w", err)
	}
	return version, nil
}

// SetConsent records (version non-nil) or clears consent, creating the
// settings row when needed. It does not bump the settings version: consent
// is not part of the optimistic-locked form.
func (r *Repository) SetConsent(ctx context.Context, userID uuid.UUID, version *int) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO ai_settings (user_id, consent_version, consent_accepted_at)
		VALUES ($1, $2::int, CASE WHEN $2::int IS NULL THEN NULL ELSE now() END)
		ON CONFLICT (user_id) DO UPDATE SET
			consent_version = EXCLUDED.consent_version,
			consent_accepted_at = EXCLUDED.consent_accepted_at,
			updated_at = now()`, userID, version)
	if err != nil {
		return fmt.Errorf("set ai consent: %w", err)
	}
	return nil
}

// --- Personal context --------------------------------------------------------

func (r *Repository) GetUserContext(ctx context.Context, userID uuid.UUID) (UserContext, error) {
	c := UserContext{UserID: userID}
	var household *int16
	err := r.db.QueryRow(ctx, `
		SELECT household_size, income_type, about_me, goals, ignore_notes, response_style, version, updated_at
		FROM ai_user_context WHERE user_id = $1`, userID).Scan(
		&household, &c.IncomeType, &c.AboutMe, &c.Goals, &c.IgnoreNotes, &c.ResponseStyle, &c.Version, &c.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return c, nil
	}
	if err != nil {
		return UserContext{}, fmt.Errorf("get ai user context: %w", err)
	}
	if household != nil {
		h := int(*household)
		c.HouseholdSize = &h
	}
	return c, nil
}

// SaveUserContext creates (expectedVersion 0) or replaces the context under
// optimistic locking.
func (r *Repository) SaveUserContext(ctx context.Context, c UserContext, expectedVersion int64) (UserContext, error) {
	var err error
	if expectedVersion == 0 {
		_, err = r.db.Exec(ctx, `
			INSERT INTO ai_user_context (user_id, household_size, income_type, about_me, goals, ignore_notes, response_style)
			VALUES ($1, $2, $3, $4, $5, $6, $7)`,
			c.UserID, c.HouseholdSize, c.IncomeType, c.AboutMe, c.Goals, c.IgnoreNotes, c.ResponseStyle)
		if isUniqueViolation(err) {
			return UserContext{}, ErrVersionMismatch
		}
	} else {
		var tag pgconn.CommandTag
		tag, err = r.db.Exec(ctx, `
			UPDATE ai_user_context SET household_size = $2, income_type = $3, about_me = $4, goals = $5,
				ignore_notes = $6, response_style = $7, version = version + 1, updated_at = now()
			WHERE user_id = $1 AND version = $8`,
			c.UserID, c.HouseholdSize, c.IncomeType, c.AboutMe, c.Goals, c.IgnoreNotes, c.ResponseStyle, expectedVersion)
		if err == nil && tag.RowsAffected() == 0 {
			return UserContext{}, ErrVersionMismatch
		}
	}
	if err != nil {
		return UserContext{}, fmt.Errorf("save ai user context: %w", err)
	}
	return r.GetUserContext(ctx, c.UserID)
}
