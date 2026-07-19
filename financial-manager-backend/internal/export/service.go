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

	"github.com/google/uuid"

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
}

type Deps struct {
	Repo         *Repository
	Store        storage.Store
	Users        *users.Repository
	Wallets      *wallets.Repository
	Categories   *categories.Repository
	Templates    *templates.Repository
	Transactions *transactions.Repository
}

func NewService(d Deps) *Service {
	return &Service{
		repo: d.Repo, store: d.Store, users: d.Users, wallets: d.Wallets,
		categories: d.Categories, templates: d.Templates, transactions: d.Transactions,
	}
}

// RequestExport generates the export synchronously and returns the
// completed record (plan.md section 20.2). The two-endpoint shape
// (create then poll) is kept even though generation is synchronous today,
// so moving it to the worker later needs no API change — see migration
// 0018's comment.
func (s *Service) RequestExport(ctx context.Context, userID uuid.UUID, format string) (Record, error) {
	if !IsValidFormat(format) {
		return Record{}, apierror.NewValidation(map[string]string{"format": "Deve essere csv o json."})
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
		return Record{}, nil, apierror.New(http.StatusConflict, "EXPORT_NOT_READY", "L'esportazione non è ancora pronta.")
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
	wallet, err := s.wallets.GetByUserID(ctx, userID)
	if err != nil {
		return nil, "", fmt.Errorf("get wallet: %w", err)
	}
	tmpls, err := s.templates.ListAllForUser(ctx, userID)
	if err != nil {
		return nil, "", fmt.Errorf("list templates: %w", err)
	}

	content, err := buildJSON(user, wallet, cats, tmpls, txs)
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
// portafoglio, categorie personalizzate, modelli, transazioni. Image
// bytes are never embedded — media_id on each transaction/category is
// already a reference into the separate object-storage archive (section
// 20.2: "riferimenti immagini o archivio separato").
func buildJSON(user users.User, wallet wallets.Wallet, cats []categories.Category, tmpls []templates.Template, txs []transactions.Transaction) ([]byte, error) {
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
		ID                  string `json:"id"`
		Currency            string `json:"currency"`
		CurrentBalanceMinor int64  `json:"current_balance_minor"`
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
			ID: t.ID.String(), Direction: t.Direction, Kind: t.Kind, AmountMinor: t.AmountMinor,
			Currency: t.Currency, Title: t.Title, Description: t.Description,
			CategoryID: categoryID, MediaID: mediaID, OccurredAt: t.OccurredAt.Format(timeLayout),
		})
	}

	return json.MarshalIndent(struct {
		Profile          profileJSON       `json:"profilo"`
		Wallet           walletJSON        `json:"portafoglio"`
		CustomCategories []categoryJSON    `json:"categorie_personalizzate"`
		Templates        []templateJSON    `json:"modelli"`
		Transactions     []transactionJSON `json:"transazioni"`
		MediaNote        string            `json:"nota_immagini"`
	}{
		Profile: profileJSON{
			ID: user.ID.String(), FirstName: user.FirstName, LastName: user.LastName,
			Username: user.Username, Email: user.Email, Locale: user.Locale, Timezone: user.Timezone,
			CreatedAt: user.CreatedAt.Format(timeLayout),
		},
		Wallet: walletJSON{
			ID: wallet.ID.String(), Currency: wallet.Currency, CurrentBalanceMinor: wallet.CurrentBalanceMinor,
		},
		CustomCategories: customCategories,
		Templates:        templateList,
		Transactions:     transactionList,
		MediaNote:        "Le immagini non sono incluse in questo export; ogni transazione con un'immagine riporta il relativo media_id.",
	}, "", "  ")
}
