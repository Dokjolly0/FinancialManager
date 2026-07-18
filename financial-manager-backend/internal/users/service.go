package users

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"financial-manager-backend/internal/platform/apierror"
)

var ErrVersionConflict = errors.New("user version conflict")

type Service struct {
	repo *Repository
}

func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

func (s *Service) GetProfile(ctx context.Context, userID uuid.UUID) (User, error) {
	user, err := s.repo.GetByID(ctx, userID)
	if errors.Is(err, ErrNotFound) {
		return User{}, apierror.ErrNotFound
	}
	return user, err
}

type UpdateProfileInput struct {
	FirstName       string
	LastName        string
	Timezone        string
	Locale          string
	Theme           string
	ExpectedVersion int64
}

func (s *Service) UpdateProfile(ctx context.Context, userID uuid.UUID, in UpdateProfileInput) (User, error) {
	fields := UpdateProfileFields{
		FirstName: in.FirstName,
		LastName:  in.LastName,
		Timezone:  in.Timezone,
		Locale:    in.Locale,
		Theme:     in.Theme,
	}

	updated, err := s.repo.UpdateProfile(ctx, userID, in.ExpectedVersion, fields)
	if errors.Is(err, ErrNotFound) {
		// Either the user doesn't exist, or expectedVersion is stale — the
		// distinction only matters for the error the client sees.
		if _, getErr := s.repo.GetByID(ctx, userID); getErr == nil {
			return User{}, apierror.ErrConflict
		}
		return User{}, apierror.ErrNotFound
	}
	return updated, err
}
