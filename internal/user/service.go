package user

import (
	"context"
	"time"

	"numia-api/internal/auth"
	"numia-api/internal/database/sqlc"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

// OnboardingRequest holds the data needed to complete user onboarding.
type OnboardingRequest struct {
	FullName   string  `json:"full_name" binding:"required"`
	Country    string  `json:"country" binding:"required"`
	BirthDate  *string `json:"birth_date"`
	Occupation *string `json:"occupation"`
}

// Service provides user-related business logic.
type Service struct {
	q *sqlc.Queries
}

// NewService creates a new user Service.
func NewService(q *sqlc.Queries) *Service {
	return &Service{q: q}
}

// GetProfile fetches the profile for the given userID.
func (s *Service) GetProfile(ctx context.Context, userID uuid.UUID) (auth.UserJSON, error) {
	u, err := s.q.GetUserByID(ctx, pgtype.UUID{Bytes: userID, Valid: true})
	if err != nil {
		return auth.UserJSON{}, err
	}
	return auth.ToUserJSON(u), nil
}

// UpdateProfile updates full_name and/or avatar_url for the given userID.
func (s *Service) UpdateProfile(ctx context.Context, userID uuid.UUID, fullName *string, avatarURL *string) (auth.UserJSON, error) {
	params := sqlc.UpdateUserProfileParams{
		ID: pgtype.UUID{Bytes: userID, Valid: true},
	}
	if fullName != nil {
		params.FullName = pgtype.Text{String: *fullName, Valid: true}
	}
	if avatarURL != nil {
		params.AvatarUrl = pgtype.Text{String: *avatarURL, Valid: true}
	}
	u, err := s.q.UpdateUserProfile(ctx, params)
	if err != nil {
		return auth.UserJSON{}, err
	}
	return auth.ToUserJSON(u), nil
}

// CompleteOnboarding finalises the onboarding step for the given userID.
func (s *Service) CompleteOnboarding(ctx context.Context, userID uuid.UUID, req OnboardingRequest) (auth.UserJSON, error) {
	params := sqlc.CompleteOnboardingParams{
		ID:       pgtype.UUID{Bytes: userID, Valid: true},
		FullName: req.FullName,
		Country:  req.Country,
	}
	if req.BirthDate != nil {
		t, err := time.Parse("2006-01-02", *req.BirthDate)
		if err == nil {
			params.BirthDate = pgtype.Date{Time: t, Valid: true}
		}
	}
	if req.Occupation != nil {
		params.Occupation = pgtype.Text{String: *req.Occupation, Valid: true}
	}
	u, err := s.q.CompleteOnboarding(ctx, params)
	if err != nil {
		return auth.UserJSON{}, err
	}
	return auth.ToUserJSON(u), nil
}
