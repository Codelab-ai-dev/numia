package debt

import (
	"context"
	"fmt"

	"numia-api/internal/database/sqlc"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

// CreateRequest is the payload for creating a debt.
type CreateRequest struct {
	Type           string   `json:"type" binding:"required"`
	Name           string   `json:"name" binding:"required"`
	Institution    *string  `json:"institution"`
	TotalAmount    float64  `json:"total_amount" binding:"required"`
	OriginalAmount *float64 `json:"original_amount"`
	MonthlyPayment *float64 `json:"monthly_payment"`
	InterestRate   *float64 `json:"interest_rate"`
	Notes          *string  `json:"notes"`
}

// UpdateRequest is the payload for updating a debt.
type UpdateRequest struct {
	Type           *string  `json:"type"`
	Name           *string  `json:"name"`
	Institution    *string  `json:"institution"`
	TotalAmount    *float64 `json:"total_amount"`
	OriginalAmount *float64 `json:"original_amount"`
	MonthlyPayment *float64 `json:"monthly_payment"`
	InterestRate   *float64 `json:"interest_rate"`
	IsActive       *bool    `json:"is_active"`
	Notes          *string  `json:"notes"`
}

// Service provides debt-related business logic.
type Service struct {
	q *sqlc.Queries
}

// NewService creates a new debt Service.
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

// List returns debts for userID, optionally filtered by active status.
func (s *Service) List(ctx context.Context, userID uuid.UUID, activeOnly *bool) ([]sqlc.Debt, error) {
	params := sqlc.ListDebtsParams{
		UserID: pgtype.UUID{Bytes: userID, Valid: true},
	}
	if activeOnly != nil {
		params.ActiveOnly = pgtype.Bool{Bool: *activeOnly, Valid: true}
	}
	return s.q.ListDebts(ctx, params)
}

// Create inserts a new debt for userID.
func (s *Service) Create(ctx context.Context, userID uuid.UUID, req CreateRequest) (sqlc.Debt, error) {
	originalAmount := numericFromFloat(req.TotalAmount)
	if req.OriginalAmount != nil {
		originalAmount = numericFromFloat(*req.OriginalAmount)
	}
	params := sqlc.CreateDebtParams{
		UserID:         pgtype.UUID{Bytes: userID, Valid: true},
		Type:           req.Type,
		Name:           req.Name,
		Institution:    optText(req.Institution),
		TotalAmount:    numericFromFloat(req.TotalAmount),
		OriginalAmount: originalAmount,
		MonthlyPayment: optNumeric(req.MonthlyPayment),
		InterestRate:   optNumeric(req.InterestRate),
		Notes:          optText(req.Notes),
	}
	return s.q.CreateDebt(ctx, params)
}

// Update modifies fields of a debt owned by userID.
func (s *Service) Update(ctx context.Context, userID uuid.UUID, debtID uuid.UUID, req UpdateRequest) (sqlc.Debt, error) {
	params := sqlc.UpdateDebtParams{
		ID:             pgtype.UUID{Bytes: debtID, Valid: true},
		UserID:         pgtype.UUID{Bytes: userID, Valid: true},
		Type:           optText(req.Type),
		Name:           optText(req.Name),
		Institution:    optText(req.Institution),
		TotalAmount:    optNumeric(req.TotalAmount),
		OriginalAmount: optNumeric(req.OriginalAmount),
		MonthlyPayment: optNumeric(req.MonthlyPayment),
		InterestRate:   optNumeric(req.InterestRate),
		Notes:          optText(req.Notes),
	}
	if req.IsActive != nil {
		params.IsActive = pgtype.Bool{Bool: *req.IsActive, Valid: true}
	}
	return s.q.UpdateDebt(ctx, params)
}

// Delete removes a debt owned by userID.
func (s *Service) Delete(ctx context.Context, userID uuid.UUID, debtID uuid.UUID) error {
	return s.q.DeleteDebt(ctx, sqlc.DeleteDebtParams{
		ID:     pgtype.UUID{Bytes: debtID, Valid: true},
		UserID: pgtype.UUID{Bytes: userID, Valid: true},
	})
}
