package categories

import (
	"context"
	"errors"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"financial-manager-backend/internal/platform/apierror"
	"financial-manager-backend/internal/platform/database"
)

// ReportVersionBumper invalidates a wallet's cached reports (plan.md
// section 18.9) — the same contract as transactions.ReportVersionBumper,
// satisfied by reportcache.Store. Optional: nil in tests that don't
// exercise report caching.
type ReportVersionBumper interface {
	Bump(ctx context.Context, walletID uuid.UUID) error
}

type Service struct {
	db             *database.Pool
	repo           *Repository
	reportVersions ReportVersionBumper
}

type Deps struct {
	DB             *database.Pool
	Repo           *Repository
	ReportVersions ReportVersionBumper
}

func NewService(d Deps) *Service {
	return &Service{db: d.DB, repo: d.Repo, reportVersions: d.ReportVersions}
}

type categoryResponse struct {
	ID             string  `json:"id"`
	Name           string  `json:"name"`
	DirectionScope string  `json:"direction_scope"`
	Color          *string `json:"color,omitempty"`
	IsSystem       bool    `json:"is_system"`
	SortOrder      int     `json:"sort_order"`
	UsageCount     int64   `json:"usage_count"`
	Hidden         bool    `json:"hidden"`
}

func toCategoryResponse(c Category) categoryResponse {
	return categoryResponse{
		ID:             c.ID.String(),
		Name:           c.Name,
		DirectionScope: c.DirectionScope,
		Color:          c.Color,
		IsSystem:       c.IsSystem,
		SortOrder:      c.SortOrder,
		UsageCount:     c.UsageCount,
		Hidden:         c.Hidden,
	}
}

func validateFields(name, directionScope string) map[string]string {
	fieldErrors := map[string]string{}
	if strings.TrimSpace(name) == "" || len(name) > 80 {
		fieldErrors["name"] = apierror.FieldCategoryNameLength
	}
	if !IsValidScope(directionScope) {
		fieldErrors["direction_scope"] = apierror.FieldInvalidCategoryScope
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
		return categoryResponse{}, apierror.New(409, "CATEGORY_ALREADY_EXISTS", "A category with this name already exists for this direction.")
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
		return categoryResponse{}, apierror.New(403, "SYSTEM_CATEGORY_NOT_EDITABLE", "System categories cannot be edited.")
	}

	updated, err := s.repo.Update(ctx, in.CategoryID, in.UserID, UpdateInput{
		Name: in.Name, DirectionScope: in.DirectionScope, Color: in.Color,
	})
	if errors.Is(err, ErrNotFound) {
		return categoryResponse{}, apierror.ErrNotFound
	}
	if isUniqueViolation(err) {
		return categoryResponse{}, apierror.New(409, "CATEGORY_ALREADY_EXISTS", "A category with this name already exists for this direction.")
	}
	if err != nil {
		return categoryResponse{}, err
	}
	return toCategoryResponse(updated), nil
}

// Delete soft-deletes a user-owned category (plan.md section 14.7:
// "System categories are not deletable" — they can only be hidden, see
// Hide). The user's transactions and templates filed under it are left
// without a category, in the same DB transaction, so nothing keeps
// pointing at an archived category; the clients warn about this before
// calling it, using the category's usage_count.
func (s *Service) Delete(ctx context.Context, userID, categoryID uuid.UUID) error {
	existing, err := s.repo.GetByIDAndVisibility(ctx, categoryID, userID)
	if errors.Is(err, ErrNotFound) {
		return apierror.ErrNotFound
	}
	if err != nil {
		return err
	}
	if existing.IsSystem {
		return apierror.New(403, "SYSTEM_CATEGORY_NOT_DELETABLE", "System categories cannot be deleted.")
	}

	var walletIDs []uuid.UUID
	err = s.db.WithTx(ctx, func(ctx context.Context, tx pgx.Tx) error {
		repo := s.repo.WithQuerier(tx)
		var err error
		if walletIDs, err = repo.DetachFromTransactions(ctx, categoryID, userID); err != nil {
			return err
		}
		if err := repo.DetachFromTemplates(ctx, categoryID, userID); err != nil {
			return err
		}
		return repo.Archive(ctx, categoryID, userID)
	})
	if errors.Is(err, ErrNotFound) {
		return apierror.ErrNotFound
	}
	if err != nil {
		return err
	}

	// After the commit, like transactions.Service: a failed bump only
	// leaves category breakdowns stale until the cache TTL expires.
	if s.reportVersions != nil {
		for _, walletID := range walletIDs {
			_ = s.reportVersions.Bump(ctx, walletID)
		}
	}
	return nil
}

// Hide hides a system category from the user's pickers; Unhide shows it
// again. Per user, unlike archiving, which would hide it for everyone
// sharing it. A custom category can't be hidden — the user deletes it.
func (s *Service) Hide(ctx context.Context, userID, categoryID uuid.UUID) error {
	if err := s.checkHideable(ctx, userID, categoryID); err != nil {
		return err
	}
	return s.repo.Hide(ctx, categoryID, userID)
}

func (s *Service) Unhide(ctx context.Context, userID, categoryID uuid.UUID) error {
	if err := s.checkHideable(ctx, userID, categoryID); err != nil {
		return err
	}
	return s.repo.Unhide(ctx, categoryID, userID)
}

func (s *Service) checkHideable(ctx context.Context, userID, categoryID uuid.UUID) error {
	existing, err := s.repo.GetByIDAndVisibility(ctx, categoryID, userID)
	if errors.Is(err, ErrNotFound) {
		return apierror.ErrNotFound
	}
	if err != nil {
		return err
	}
	if !existing.IsSystem {
		return apierror.New(422, "CATEGORY_NOT_HIDEABLE", "Only system categories can be hidden; delete a custom category instead.")
	}
	return nil
}
