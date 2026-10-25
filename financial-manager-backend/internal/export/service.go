package export

import (
	"bytes"
	"context"
	"encoding/csv"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/ai"
	"financial-manager-backend/internal/categories"
	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/storage"
	"financial-manager-backend/internal/templates"
	"financial-manager-backend/internal/transactions"
	"financial-manager-backend/internal/users"
	"financial-manager-backend/internal/wallets"
)

const timeLayout = "2006-01-02T15:04:05Z07:00"

type Service struct {
	repo         *Repository
	store        storage.Store
	users        *users.Repository
	wallets      *wallets.Repository
	categories   *categories.Repository
	templates    *templates.Repository
	transactions *transactions.Repository
	ai           *ai.Repository
	aiStream     time.Duration
	aiLocal      time.Duration
}

type Deps struct {
	Repo         *Repository
	Store        storage.Store
	Users        *users.Repository
	Wallets      *wallets.Repository
	Categories   *categories.Repository
	Templates    *templates.Repository
	Transactions *transactions.Repository
	// AIStreamWindow and AILocalWindow are how long a cloud stream and a
	// phone may take (AI_STREAM_MAX_DURATION, AI_LOCAL_MAX_DURATION): an
	// analysis still pending after that is exported as failed, as the app
	// shows it. Zero uses the AI defaults (5m, 30m).
	AIStreamWindow time.Duration
	AILocalWindow  time.Duration
	// AI, when set, adds the AI analysis personal context (plan.md section
	// 32.3) to the JSON export. API keys and analyses are never exported.
	AI *ai.Repository
}

func NewService(d Deps) *Service {
	s := &Service{
		repo: d.Repo, store: d.Store, users: d.Users, wallets: d.Wallets,
		categories: d.Categories, templates: d.Templates, transactions: d.Transactions, ai: d.AI,
		aiStream: d.AIStreamWindow, aiLocal: d.AILocalWindow,
	}
	if s.aiStream == 0 {
		s.aiStream = 5 * time.Minute
	}
	if s.aiLocal == 0 {
		s.aiLocal = 30 * time.Minute
	}
	return s
}

// RequestExport generates the export synchronously and returns the
// completed record (plan.md section 20.2). The two-endpoint shape
// (create then poll) is kept even though generation is synchronous today,
// so moving it to the worker later needs no API change — see migration
// 0018's comment.
func (s *Service) RequestExport(ctx context.Context, userID uuid.UUID, format string) (Record, error) {
	if !IsValidFormat(format) {
		return Record{}, apierror.NewValidation(map[string]string{"format": apierror.FieldInvalidExportFormat})
	}

	record, err := s.repo.Create(ctx, userID, format)
	if err != nil {
		return Record{}, err
	}

	content, contentType, err := s.buildContent(ctx, userID, format)
	if err != nil {
		failed, markErr := s.repo.MarkFailed(ctx, record.ID, err.Error())
		if markErr != nil {
			return Record{}, markErr
		}
		return failed, nil
	}

	key := fmt.Sprintf("exports/%s/%s.%s", userID, record.ID, format)
	if _, err := s.store.Put(ctx, key, bytes.NewReader(content), int64(len(content)), contentType); err != nil {
		failed, markErr := s.repo.MarkFailed(ctx, record.ID, err.Error())
		if markErr != nil {
			return Record{}, markErr
		}
		return failed, nil
	}

	return s.repo.MarkReady(ctx, record.ID, key)
}

// GetExport fetches a previously requested export's status (plan.md
// section 14.2), scoped to userID so one user can never poll another's
// export by guessing its id.
func (s *Service) GetExport(ctx context.Context, userID, exportID uuid.UUID) (Record, error) {
	record, err := s.repo.GetByIDAndUserID(ctx, exportID, userID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			return Record{}, apierror.ErrNotFound
		}
		return Record{}, err
	}
	return record, nil
}

// DownloadContent streams a ready export's content. The download is
// proxied through the API rather than via a presigned object-storage URL
// (plan.md section 16.7's "fallback when presigned URLs are not desired")
// since a presigned URL would point at MinIO's internal address, which is
// not reachable from outside the backend's own Docker network.
func (s *Service) DownloadContent(ctx context.Context, userID, exportID uuid.UUID) (Record, io.ReadCloser, error) {
	record, err := s.GetExport(ctx, userID, exportID)
	if err != nil {
		return Record{}, nil, err
	}
	if record.Status != StatusReady || record.ObjectKey == nil {
		return Record{}, nil, apierror.New(http.StatusConflict, "EXPORT_NOT_READY", "The export is not ready yet.")
	}

	content, err := s.store.Get(ctx, *record.ObjectKey)
	if err != nil {
		return Record{}, nil, err
	}
	return record, content, nil
}

func (s *Service) buildContent(ctx context.Context, userID uuid.UUID, format string) ([]byte, string, error) {
	txs, err := s.transactions.ListAllForExport(ctx, userID)
	if err != nil {
		return nil, "", fmt.Errorf("list transactions: %w", err)
	}
	cats, err := s.categories.ListForUser(ctx, userID)
	if err != nil {
		return nil, "", fmt.Errorf("list categories: %w", err)
	}
	categoryNames := make(map[uuid.UUID]string, len(cats))
	for _, c := range cats {
		categoryNames[c.ID] = c.Name
	}

	if format == FormatCSV {
		content, err := buildCSV(txs, categoryNames)
		return content, "text/csv", err
	}

	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return nil, "", fmt.Errorf("get user: %w", err)
	}
	userWallets, err := s.wallets.ListAllByUserID(ctx, userID)
	if err != nil {
		return nil, "", fmt.Errorf("list wallets: %w", err)
	}
	tmpls, err := s.templates.ListAllForUser(ctx, userID)
	if err != nil {
		return nil, "", fmt.Errorf("list templates: %w", err)
	}

	var aiContext *ai.UserContext
	var analyses []aiAnalysisJSON
	if s.ai != nil {
		uc, err := s.ai.GetUserContext(ctx, userID)
		if err != nil {
			return nil, "", fmt.Errorf("get ai context: %w", err)
		}
		if !uc.IsEmpty() {
			aiContext = &uc
		}
		history, err := s.ai.ListAnalysesForExport(ctx, userID)
		if err != nil {
			return nil, "", fmt.Errorf("list ai analyses: %w", err)
		}
		analyses = s.toAIAnalysesJSON(history, time.Now())
	}

	content, err := buildJSON(user, userWallets, cats, tmpls, txs, aiContext, analyses)
	return content, "application/json", err
}

// buildCSV implements plan.md section 20.2's exact column order:
// id,data_ora,tipo,titolo,categoria,descrizione,importo,valuta,natura.
func buildCSV(txs []transactions.Transaction, categoryNames map[uuid.UUID]string) ([]byte, error) {
	var buf bytes.Buffer
	w := csv.NewWriter(&buf)

	if err := w.Write([]string{"id", "data_ora", "tipo", "titolo", "categoria", "descrizione", "importo", "valuta", "natura"}); err != nil {
		return nil, err
	}
	for _, t := range txs {
		categoryName := ""
		if t.CategoryID != nil {
			categoryName = categoryNames[*t.CategoryID]
		}
		description := ""
		if t.Description != nil {
			description = *t.Description
		}
		row := []string{
			t.ID.String(),
			t.OccurredAt.Format(timeLayout),
			t.Direction,
			t.Title,
			categoryName,
			description,
			formatAmount(t.AmountMinor),
			t.Currency,
			t.Kind,
		}
		if err := w.Write(row); err != nil {
			return nil, err
		}
	}
	w.Flush()
	if err := w.Error(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func formatAmount(amountMinor int64) string {
	return fmt.Sprintf("%d.%02d", amountMinor/100, amountMinor%100)
}

// buildJSON implements plan.md section 20.2's JSON shape: profilo,
// portafogli, categorie personalizzate, modelli, transazioni. Every wallet
// the user has ever owned is included (not just one), since a user may now
// hold several — each transaction's wallet_id says which one it belongs to.
// Image bytes are never embedded — media_id on each transaction/category is
// already a reference into the separate object-storage archive (section
// 20.2: "riferimenti immagini o archivio separato").
func buildJSON(user users.User, userWallets []wallets.Wallet, cats []categories.Category, tmpls []templates.Template, txs []transactions.Transaction, aiContext *ai.UserContext, analyses []aiAnalysisJSON) ([]byte, error) {
	type profileJSON struct {
		ID        string `json:"id"`
		FirstName string `json:"first_name"`
		LastName  string `json:"last_name"`
		Username  string `json:"username"`
		Email     string `json:"email"`
		Locale    string `json:"locale"`
		Timezone  string `json:"timezone"`
		CreatedAt string `json:"created_at"`
	}
	type walletJSON struct {
		ID                  string  `json:"id"`
		Name                string  `json:"name"`
		Type                string  `json:"type"`
		Currency            string  `json:"currency"`
		CurrentBalanceMinor int64   `json:"current_balance_minor"`
		Purpose             *string `json:"scopo,omitempty"`
		ArchivedAt          *string `json:"archived_at,omitempty"`
	}
	type categoryJSON struct {
		ID             string  `json:"id"`
		Name           string  `json:"name"`
		DirectionScope string  `json:"direction_scope"`
		Color          *string `json:"color,omitempty"`
	}
	type templateJSON struct {
		ID                 string  `json:"id"`
		Direction          string  `json:"direction"`
		Title              string  `json:"title"`
		DefaultCategoryID  *string `json:"default_category_id,omitempty"`
		DefaultDescription *string `json:"default_description,omitempty"`
		UsageCount         int64   `json:"usage_count"`
	}
	type transactionJSON struct {
		ID          string  `json:"id"`
		WalletID    string  `json:"wallet_id"`
		Direction   string  `json:"direction"`
		Kind        string  `json:"kind"`
		AmountMinor int64   `json:"amount_minor"`
		Currency    string  `json:"currency"`
		Title       string  `json:"title"`
		Description *string `json:"description,omitempty"`
		CategoryID  *string `json:"category_id,omitempty"`
		MediaID     *string `json:"media_id,omitempty"`
		OccurredAt  string  `json:"occurred_at"`
	}

	customCategories := make([]categoryJSON, 0, len(cats))
	for _, c := range cats {
		if c.IsSystem {
			continue
		}
		customCategories = append(customCategories, categoryJSON{
			ID: c.ID.String(), Name: c.Name, DirectionScope: c.DirectionScope, Color: c.Color,
		})
	}

	templateList := make([]templateJSON, 0, len(tmpls))
	for _, t := range tmpls {
		var categoryID *string
		if t.DefaultCategoryID != nil {
			s := t.DefaultCategoryID.String()
			categoryID = &s
		}
		templateList = append(templateList, templateJSON{
			ID: t.ID.String(), Direction: t.Direction, Title: t.Title,
			DefaultCategoryID: categoryID, DefaultDescription: t.DefaultDescription, UsageCount: t.UsageCount,
		})
	}

	transactionList := make([]transactionJSON, 0, len(txs))
	for _, t := range txs {
		var categoryID, mediaID *string
		if t.CategoryID != nil {
			s := t.CategoryID.String()
			categoryID = &s
		}
		if t.MediaID != nil {
			s := t.MediaID.String()
			mediaID = &s
		}
		transactionList = append(transactionList, transactionJSON{
			ID: t.ID.String(), WalletID: t.WalletID.String(), Direction: t.Direction, Kind: t.Kind, AmountMinor: t.AmountMinor,
			Currency: t.Currency, Title: t.Title, Description: t.Description,
			CategoryID: categoryID, MediaID: mediaID, OccurredAt: t.OccurredAt.Format(timeLayout),
		})
	}

	walletList := make([]walletJSON, 0, len(userWallets))
	for _, w := range userWallets {
		var archivedAt *string
		if w.ArchivedAt != nil {
			s := w.ArchivedAt.Format(timeLayout)
			archivedAt = &s
		}
		walletList = append(walletList, walletJSON{
			ID: w.ID.String(), Name: w.Name, Type: w.Type,
			Currency: w.Currency, CurrentBalanceMinor: w.CurrentBalanceMinor, Purpose: w.Purpose,
			ArchivedAt: archivedAt,
		})
	}

	return json.MarshalIndent(struct {
		Profile          profileJSON       `json:"profilo"`
		Wallets          []walletJSON      `json:"portafogli"`
		CustomCategories []categoryJSON    `json:"categorie_personalizzate"`
		Templates        []templateJSON    `json:"modelli"`
		Transactions     []transactionJSON `json:"transazioni"`
		AIContext        *aiContextJSON    `json:"contesto_analisi_ai,omitempty"`
		AIAnalyses       []aiAnalysisJSON  `json:"analisi_ai,omitempty"`
		MediaNote        string            `json:"nota_immagini"`
	}{
		Profile: profileJSON{
			ID: user.ID.String(), FirstName: user.FirstName, LastName: user.LastName,
			Username: user.Username, Email: user.Email, Locale: user.Locale, Timezone: user.Timezone,
			CreatedAt: user.CreatedAt.Format(timeLayout),
		},
		Wallets:          walletList,
		CustomCategories: customCategories,
		Templates:        templateList,
		Transactions:     transactionList,
		AIContext:        toAIContextJSON(aiContext),
		AIAnalyses:       analyses,
		MediaNote:        "Le immagini non sono incluse in questo export; ogni transazione con un'immagine riporta il relativo media_id.",
	}, "", "  ")
}

type aiContextJSON struct {
	HouseholdSize *int    `json:"persone_nucleo_familiare,omitempty"`
	IncomeType    *string `json:"tipo_reddito,omitempty"`
	AboutMe       *string `json:"su_di_me,omitempty"`
	Goals         *string `json:"obiettivi,omitempty"`
	IgnoreNotes   *string `json:"da_ignorare,omitempty"`
	ResponseStyle *string `json:"stile_risposte,omitempty"`
}

func toAIContextJSON(c *ai.UserContext) *aiContextJSON {
	if c == nil {
		return nil
	}
	return &aiContextJSON{
		HouseholdSize: c.HouseholdSize, IncomeType: c.IncomeType, AboutMe: c.AboutMe,
		Goals: c.Goals, IgnoreNotes: c.IgnoreNotes, ResponseStyle: c.ResponseStyle,
	}
}

// aiAnalysisJSON is one AI analysis with its conversation (plan.md section
// 20.2): the data that was sent (the CONTEXT message), the report, the
// questions and the answers. Never the system prompt or any API key.
type aiAnalysisJSON struct {
	ID           string           `json:"id"`
	Title        string           `json:"titolo"`
	Preset       string           `json:"preset"`
	PeriodFrom   *string          `json:"periodo_da,omitempty"`
	PeriodTo     string           `json:"periodo_a"`
	Timezone     string           `json:"fuso_orario"`
	WalletIDs    []string         `json:"portafogli"`
	Options      json.RawMessage  `json:"opzioni,omitempty"`
	Provider     string           `json:"fornitore"`
	Model        string           `json:"modello"`
	Runtime      *ai.LocalRuntime `json:"esecuzione,omitempty"`
	Status       string           `json:"stato"`
	ErrorCode    *string          `json:"codice_errore,omitempty"`
	InputTokens  int              `json:"token_input"`
	OutputTokens int              `json:"token_output"`
	CreatedAt    string           `json:"creata_il"`
	Messages     []aiMessageJSON  `json:"messaggi"`
}

type aiMessageJSON struct {
	Kind         string  `json:"tipo"`
	Content      string  `json:"contenuto"`
	Status       string  `json:"stato"`
	ErrorCode    *string `json:"codice_errore,omitempty"`
	Model        *string `json:"modello,omitempty"`
	InputTokens  *int    `json:"token_input,omitempty"`
	OutputTokens *int    `json:"token_output,omitempty"`
	Truncated    bool    `json:"troncato,omitempty"`
	DurationMs   *int    `json:"durata_ms,omitempty"`
	Attachment   *string `json:"allegato,omitempty"` // a chat question's attached data
	// ToolTrace is what a chat answer looked up, with the data returned.
	ToolTrace []ai.ToolTraceEntry `json:"ricerche,omitempty"`
	CreatedAt string              `json:"creato_il"`
}

// toAIAnalysesJSON shapes the history; rows still pending past their
// window are reported as failed, as the app shows them.
func (s *Service) toAIAnalysesJSON(history []ai.AnalysisWithMessages, now time.Time) []aiAnalysisJSON {
	out := make([]aiAnalysisJSON, 0, len(history))
	for _, h := range history {
		a := h.Analysis
		window := s.aiStream
		if a.Provider == ai.ProviderOnDevice {
			window = s.aiLocal
		}
		var from *string
		if a.PeriodFrom != nil {
			f := a.PeriodFrom.Format(timeLayout)
			from = &f
		}
		walletIDs := make([]string, len(a.WalletIDs))
		for i, id := range a.WalletIDs {
			walletIDs[i] = id.String()
		}
		var options json.RawMessage
		if b, err := json.Marshal(a.Options); err == nil {
			options = b
		}
		messages := make([]aiMessageJSON, 0, len(h.Messages))
		for _, m := range h.Messages {
			messages = append(messages, aiMessageJSON{
				Kind: m.Kind, Content: m.Content, Status: ai.EffectiveStatus(m.Status, m.UpdatedAt, now, window),
				ErrorCode: m.ErrorCode, Model: m.Model, InputTokens: m.InputTokens, OutputTokens: m.OutputTokens,
				Truncated: m.Truncated, DurationMs: m.DurationMs, CreatedAt: m.CreatedAt.Format(timeLayout),
				Attachment: m.Attachment, ToolTrace: m.ToolTrace,
			})
		}
		out = append(out, aiAnalysisJSON{
			ID: a.ID.String(), Title: a.Title, Preset: a.Preset, PeriodFrom: from, PeriodTo: a.PeriodTo.Format(timeLayout),
			Timezone: a.Timezone, WalletIDs: walletIDs, Options: options, Provider: a.Provider, Model: a.Model,
			Runtime: a.Runtime, Status: ai.EffectiveStatus(a.Status, a.UpdatedAt, now, window), ErrorCode: a.ErrorCode,
			InputTokens: a.InputTokensTotal, OutputTokens: a.OutputTokensTotal, CreatedAt: a.CreatedAt.Format(timeLayout),
			Messages: messages,
		})
	}
	return out
}
