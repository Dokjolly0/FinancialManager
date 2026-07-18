package templates

import (
	"context"
	"errors"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"

	"financial-manager-backend/internal/platform/apierror"
)

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

type templateResponse struct {
	ID                 string  `json:"id"`
	Direction          string  `json:"direction"`
	Title              string  `json:"title"`
	DefaultCategoryID  *string `json:"default_category_id,omitempty"`
	DefaultDescription *string `json:"default_description,omitempty"`
	UsageCount         int64   `json:"usage_count"`
	LastUsedAt         *string `json:"last_used_at,omitempty"`
}

const timeLayout = "2006-01-02T15:04:05Z07:00"

func toTemplateResponse(t Template) templateResponse {
	var categoryID *string
	if t.DefaultCategoryID != nil {
		s := t.DefaultCategoryID.String()
		categoryID = &s
	}
	var lastUsed *string
	if t.LastUsedAt != nil {
		s := t.LastUsedAt.Format(timeLayout)
		lastUsed = &s
	}
	return templateResponse{
		ID: t.ID.String(), Direction: t.Direction, Title: t.Title,
		DefaultCategoryID: categoryID, DefaultDescription: t.DefaultDescription,
		UsageCount: t.UsageCount, LastUsedAt: lastUsed,
	}
}

func isValidDirection(d string) bool { return d == "CREDIT" || d == "DEBIT" }

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}

func validateFields(direction, title string) map[string]string {
	fieldErrors := map[string]string{}
	if !isValidDirection(direction) {
		fieldErrors["direction"] = "Deve essere CREDIT o DEBIT."
	}
	if strings.TrimSpace(title) == "" || len(title) > 120 {
		fieldErrors["title"] = "Deve avere tra 1 e 120 caratteri."
	}
	return fieldErrors
}

type SearchInput struct {
	UserID    uuid.UUID
	Direction string
	Query     string
	Limit     int
}

func (s *Service) Search(ctx context.Context, in SearchInput) ([]templateResponse, error) {
	if !isValidDirection(in.Direction) {
		return nil, apierror.NewValidation(map[string]string{"direction": "Deve essere CREDIT o DEBIT."})
	}

	list, err := s.repo.Search(ctx, SearchFilter{UserID: in.UserID, Direction: in.Direction, Query: in.Query, Limit: in.Limit})
	if err != nil {
		return nil, err
	}
	out := make([]templateResponse, 0, len(list))
	for _, t := range list {
		out = append(out, toTemplateResponse(t))
	}
	return out, nil
}

type CreateServiceInput struct {
	UserID             uuid.UUID
	Direction          string
	Title              string
	DefaultCategoryID  *uuid.UUID
	DefaultDescription *string
}

func (s *Service) Create(ctx context.Context, in CreateServiceInput) (templateResponse, error) {
	if fieldErrors := validateFields(in.Direction, in.Title); len(fieldErrors) > 0 {
		return templateResponse{}, apierror.NewValidation(fieldErrors)
	}

	created, err := s.repo.Create(ctx, CreateInput{
		UserID: in.UserID, Direction: in.Direction, Title: in.Title,
		DefaultCategoryID: in.DefaultCategoryID, DefaultDescription: in.DefaultDescription,
	})
	if isUniqueViolation(err) {
		return templateResponse{}, apierror.New(409, "TEMPLATE_ALREADY_EXISTS", "Esiste già un modello con questo titolo per questa direzione.")
	}
	if err != nil {
		return templateResponse{}, err
	}
	return toTemplateResponse(created), nil
}

type UpdateServiceInput struct {
	UserID             uuid.UUID
	TemplateID         uuid.UUID
	Title              string
	DefaultCategoryID  *uuid.UUID
	DefaultDescription *string
}

func (s *Service) Update(ctx context.Context, in UpdateServiceInput) (templateResponse, error) {
	if strings.TrimSpace(in.Title) == "" || len(in.Title) > 120 {
		return templateResponse{}, apierror.NewValidation(map[string]string{"title": "Deve avere tra 1 e 120 caratteri."})
	}

	updated, err := s.repo.Update(ctx, in.TemplateID, in.UserID, UpdateInput{
		Title: in.Title, DefaultCategoryID: in.DefaultCategoryID, DefaultDescription: in.DefaultDescription,
	})
	if errors.Is(err, ErrNotFound) {
		return templateResponse{}, apierror.ErrNotFound
	}
	if isUniqueViolation(err) {
		return templateResponse{}, apierror.New(409, "TEMPLATE_ALREADY_EXISTS", "Esiste già un modello con questo titolo per questa direzione.")
	}
	if err != nil {
		return templateResponse{}, err
	}
	return toTemplateResponse(updated), nil
}

func (s *Service) Delete(ctx context.Context, userID, templateID uuid.UUID) error {
	if err := s.repo.Archive(ctx, templateID, userID); err != nil {
		if errors.Is(err, ErrNotFound) {
			return apierror.ErrNotFound
		}
		return err
	}
	return nil
}
