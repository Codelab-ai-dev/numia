package investment

import (
	"context"
	"fmt"

	"numia-api/internal/database/sqlc"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

// CreateRequest is the payload for creating an investment.
type CreateRequest struct {
	Name           string   `json:"name" binding:"required"`
	Institution    *string  `json:"institution"`
	Type           string   `json:"type" binding:"required"`
	AmountInvested float64  `json:"amount_invested" binding:"required"`
	CurrentValue   *float64 `json:"current_value"`
	Notes          *string  `json:"notes"`
}

// UpdateRequest is the payload for updating an investment.
type UpdateRequest struct {
	Name           *string  `json:"name"`
	Institution    *string  `json:"institution"`
	Type           *string  `json:"type"`
	AmountInvested *float64 `json:"amount_invested"`
	CurrentValue   *float64 `json:"current_value"`
	IsActive       *bool    `json:"is_active"`
	Notes          *string  `json:"notes"`
}

// Service provides investment-related business logic.
type Service struct {
	q *sqlc.Queries
}

// NewService creates a new investment Service.
func NewService(q *sqlc.Queries) *Service {
	return &Service{q: q}
}

func numericFromFloat(f float64) pgtype.Numeric {
	var n pgtype.Numeric
	_ = n.Scan(fmt.Sprintf("%.2f", f))
	return n
}

func optText(s *string) pgtype.Text {
	if s == nil {
		return pgtype.Text{}
	}
	return pgtype.Text{String: *s, Valid: true}
}

func optNumeric(f *float64) pgtype.Numeric {
	if f == nil {
		return pgtype.Numeric{}
	}
	return numericFromFloat(*f)
}

// List returns investments for userID, optionally filtered by active status.
func (s *Service) List(ctx context.Context, userID uuid.UUID, activeOnly *bool) ([]sqlc.Investment, error) {
	params := sqlc.ListInvestmentsParams{
		UserID: pgtype.UUID{Bytes: userID, Valid: true},
	}
	if activeOnly != nil {
		params.ActiveOnly = pgtype.Bool{Bool: *activeOnly, Valid: true}
	}
	return s.q.ListInvestments(ctx, params)
}

// Create inserts a new investment for userID.
func (s *Service) Create(ctx context.Context, userID uuid.UUID, req CreateRequest) (sqlc.Investment, error) {
	// If current value is not provided, default it to the amount invested.
	currentValue := numericFromFloat(req.AmountInvested)
	if req.CurrentValue != nil {
		currentValue = numericFromFloat(*req.CurrentValue)
	}
	params := sqlc.CreateInvestmentParams{
		UserID:         pgtype.UUID{Bytes: userID, Valid: true},
		Name:           req.Name,
		Institution:    optText(req.Institution),
		Type:           req.Type,
		AmountInvested: numericFromFloat(req.AmountInvested),
		CurrentValue:   currentValue,
		Notes:          optText(req.Notes),
	}
	return s.q.CreateInvestment(ctx, params)
}

// Update modifies fields of an investment owned by userID.
func (s *Service) Update(ctx context.Context, userID uuid.UUID, investmentID uuid.UUID, req UpdateRequest) (sqlc.Investment, error) {
	params := sqlc.UpdateInvestmentParams{
		ID:             pgtype.UUID{Bytes: investmentID, Valid: true},
		UserID:         pgtype.UUID{Bytes: userID, Valid: true},
		Name:           optText(req.Name),
		Institution:    optText(req.Institution),
		Type:           optText(req.Type),
		AmountInvested: optNumeric(req.AmountInvested),
		CurrentValue:   optNumeric(req.CurrentValue),
		Notes:          optText(req.Notes),
	}
	if req.IsActive != nil {
		params.IsActive = pgtype.Bool{Bool: *req.IsActive, Valid: true}
	}
	return s.q.UpdateInvestment(ctx, params)
}

// Delete removes an investment owned by userID.
func (s *Service) Delete(ctx context.Context, userID uuid.UUID, investmentID uuid.UUID) error {
	return s.q.DeleteInvestment(ctx, sqlc.DeleteInvestmentParams{
		ID:     pgtype.UUID{Bytes: investmentID, Valid: true},
		UserID: pgtype.UUID{Bytes: userID, Valid: true},
	})
}
