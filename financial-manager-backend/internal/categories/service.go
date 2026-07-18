package categories

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

type categoryResponse struct {
	ID             string  `json:"id"`
	Name           string  `json:"name"`
	DirectionScope string  `json:"direction_scope"`
	Color          *string `json:"color,omitempty"`
	IsSystem       bool    `json:"is_system"`
	SortOrder      int     `json:"sort_order"`
}

func toCategoryResponse(c Category) categoryResponse {
	return categoryResponse{
		ID:             c.ID.String(),
		Name:           c.Name,
		DirectionScope: c.DirectionScope,
		Color:          c.Color,
		IsSystem:       c.IsSystem,
		SortOrder:      c.SortOrder,
	}
}

func validateFields(name, directionScope string) map[string]string {
	fieldErrors := map[string]string{}
	if strings.TrimSpace(name) == "" || len(name) > 80 {
		fieldErrors["name"] = "Deve avere tra 1 e 80 caratteri."
	}
	if !IsValidScope(directionScope) {
		fieldErrors["direction_scope"] = "Deve essere DEBIT, CREDIT o BOTH."
	}
	return fieldErrors
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}

func (s *Service) List(ctx context.Context, userID uuid.UUID) ([]categoryResponse, error) {
	list, err := s.repo.ListForUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]categoryResponse, 0, len(list))
	for _, c := range list {
		out = append(out, toCategoryResponse(c))
	}
	return out, nil
}

type CreateServiceInput struct {
	UserID         uuid.UUID
	Name           string
	DirectionScope string
	Color          *string
}

func (s *Service) Create(ctx context.Context, in CreateServiceInput) (categoryResponse, error) {
	if fieldErrors := validateFields(in.Name, in.DirectionScope); len(fieldErrors) > 0 {
		return categoryResponse{}, apierror.NewValidation(fieldErrors)
	}

	created, err := s.repo.Create(ctx, CreateInput{
		OwnerUserID: in.UserID, Name: in.Name, DirectionScope: in.DirectionScope, Color: in.Color,
	})
	if isUniqueViolation(err) {
		return categoryResponse{}, apierror.New(409, "CATEGORY_ALREADY_EXISTS", "Esiste già una categoria con questo nome per questa direzione.")
	}
	if err != nil {
		return categoryResponse{}, err
	}
	return toCategoryResponse(created), nil
}

type UpdateServiceInput struct {
	UserID         uuid.UUID
	CategoryID     uuid.UUID
	Name           string
	DirectionScope string
	Color          *string
}

func (s *Service) Update(ctx context.Context, in UpdateServiceInput) (categoryResponse, error) {
	if fieldErrors := validateFields(in.Name, in.DirectionScope); len(fieldErrors) > 0 {
		return categoryResponse{}, apierror.NewValidation(fieldErrors)
	}

	existing, err := s.repo.GetByIDAndVisibility(ctx, in.CategoryID, in.UserID)
	if errors.Is(err, ErrNotFound) {
		return categoryResponse{}, apierror.ErrNotFound
	}
	if err != nil {
		return categoryResponse{}, err
	}
	if existing.IsSystem {
		return categoryResponse{}, apierror.New(403, "SYSTEM_CATEGORY_NOT_EDITABLE", "Le categorie di sistema non possono essere modificate.")
	}

	updated, err := s.repo.Update(ctx, in.CategoryID, in.UserID, UpdateInput{
		Name: in.Name, DirectionScope: in.DirectionScope, Color: in.Color,
	})
	if errors.Is(err, ErrNotFound) {
		return categoryResponse{}, apierror.ErrNotFound
	}
	if isUniqueViolation(err) {
		return categoryResponse{}, apierror.New(409, "CATEGORY_ALREADY_EXISTS", "Esiste già una categoria con questo nome per questa direzione.")
	}
	if err != nil {
		return categoryResponse{}, err
	}
	return toCategoryResponse(updated), nil
}

// Delete soft-deletes a user-owned category (plan.md section 14.7: "Le
// categorie di sistema non sono eliminabili"). Per-user hiding of system
// categories isn't modeled — plan.md section 11 doesn't define a per-user
// visibility table, so a system category can only be hidden by a future,
// explicitly designed extension, not silently archived here (which would
// hide it for every user sharing it).
func (s *Service) Delete(ctx context.Context, userID, categoryID uuid.UUID) error {
	existing, err := s.repo.GetByIDAndVisibility(ctx, categoryID, userID)
	if errors.Is(err, ErrNotFound) {
		return apierror.ErrNotFound
	}
	if err != nil {
		return err
	}
	if existing.IsSystem {
		return apierror.New(403, "SYSTEM_CATEGORY_NOT_DELETABLE", "Le categorie di sistema non possono essere eliminate.")
	}

	if err := s.repo.Archive(ctx, categoryID, userID); err != nil {
		if errors.Is(err, ErrNotFound) {
			return apierror.ErrNotFound
		}
		return err
	}
	return nil
}
