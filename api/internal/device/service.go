package device

import (
	"context"

	"numia-api/internal/database/sqlc"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

// RegisterRequest is the payload for registering a device token.
type RegisterRequest struct {
	FcmToken string `json:"fcm_token" binding:"required"`
	Platform string `json:"platform" binding:"required"`
}

// DeleteRequest is the payload for removing a device token.
type DeleteRequest struct {
	FcmToken string `json:"fcm_token" binding:"required"`
}

// Service provides device token CRUD operations.
type Service struct {
	q *sqlc.Queries
}

// NewService creates a new device Service.
func NewService(q *sqlc.Queries) *Service {
	return &Service{q: q}
}

// Register upserts a device token for the given user.
func (s *Service) Register(ctx context.Context, userID uuid.UUID, req RegisterRequest) error {
	return s.q.UpsertDevice(ctx, sqlc.UpsertDeviceParams{
		UserID:   pgtype.UUID{Bytes: userID, Valid: true},
		FcmToken: req.FcmToken,
		Platform: req.Platform,
	})
}

// Remove deletes a device token.
func (s *Service) Remove(ctx context.Context, req DeleteRequest) error {
	return s.q.DeleteDevice(ctx, req.FcmToken)
}
