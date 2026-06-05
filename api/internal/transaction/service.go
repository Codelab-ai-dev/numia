package transaction

import (
	"context"
	"fmt"
	"time"

	"numia-api/internal/database/sqlc"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

// CreateRequest is the payload for creating a transaction.
type CreateRequest struct {
	AccountID    string   `json:"account_id" binding:"required"`
	Amount       float64  `json:"amount" binding:"required"`
	Currency     string   `json:"currency" binding:"required"`
	Description  *string  `json:"description"`
	MerchantName *string  `json:"merchant_name"`
	Category     *string  `json:"category"`
	Subcategory  *string  `json:"subcategory"`
	ValueDate    string   `json:"value_date" binding:"required"`
	IsManual     bool     `json:"is_manual"`
	Notes        *string  `json:"notes"`
}

// UpdateRequest is the payload for updating a transaction.
type UpdateRequest struct {
	Amount      *float64 `json:"amount"`
	Description *string  `json:"description"`
	Category    *string  `json:"category"`
	Notes       *string  `json:"notes"`
}

// Service provides transaction-related business logic.
type Service struct {
	q *sqlc.Queries
}

// NewService creates a new transaction Service.
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

// List returns paginated transactions for userID, optionally filtered by category.
func (s *Service) List(ctx context.Context, userID uuid.UUID, category *string, limit, offset int32) ([]sqlc.Transaction, error) {
	params := sqlc.ListTransactionsParams{
		UserID: pgtype.UUID{Bytes: userID, Valid: true},
		Limit:  limit,
		Offset: offset,
	}
	if category != nil {
		params.Category = pgtype.Text{String: *category, Valid: true}
	}
	return s.q.ListTransactions(ctx, params)
}

// Create inserts a new transaction for userID.
func (s *Service) Create(ctx context.Context, userID uuid.UUID, req CreateRequest) (sqlc.Transaction, error) {
	accountID, err := uuid.Parse(req.AccountID)
	if err != nil {
		return sqlc.Transaction{}, fmt.Errorf("invalid account_id: %w", err)
	}

	valueDate, err := time.Parse("2006-01-02", req.ValueDate)
	if err != nil {
		return sqlc.Transaction{}, fmt.Errorf("invalid value_date: %w", err)
	}

	params := sqlc.CreateTransactionParams{
		UserID:       pgtype.UUID{Bytes: userID, Valid: true},
		AccountID:    pgtype.UUID{Bytes: accountID, Valid: true},
		Amount:       numericFromFloat(req.Amount),
		Currency:     req.Currency,
		Description:  optText(req.Description),
		MerchantName: optText(req.MerchantName),
		Category:     optText(req.Category),
		Subcategory:  optText(req.Subcategory),
		ValueDate:    pgtype.Date{Time: valueDate, Valid: true},
		IsManual:     req.IsManual,
		Notes:        optText(req.Notes),
	}
	return s.q.CreateTransaction(ctx, params)
}

// Update modifies fields of a transaction owned by userID.
func (s *Service) Update(ctx context.Context, userID uuid.UUID, txID uuid.UUID, req UpdateRequest) (sqlc.Transaction, error) {
	params := sqlc.UpdateTransactionParams{
		ID:     pgtype.UUID{Bytes: txID, Valid: true},
		UserID: pgtype.UUID{Bytes: userID, Valid: true},
	}
	if req.Amount != nil {
		params.Amount = numericFromFloat(*req.Amount)
	}
	if req.Description != nil {
		params.Description = pgtype.Text{String: *req.Description, Valid: true}
	}
	if req.Category != nil {
		params.Category = pgtype.Text{String: *req.Category, Valid: true}
	}
	if req.Notes != nil {
		params.Notes = pgtype.Text{String: *req.Notes, Valid: true}
	}
	return s.q.UpdateTransaction(ctx, params)
}

// Delete removes a transaction owned by userID.
func (s *Service) Delete(ctx context.Context, userID uuid.UUID, txID uuid.UUID) error {
	return s.q.DeleteTransaction(ctx, sqlc.DeleteTransactionParams{
		ID:     pgtype.UUID{Bytes: txID, Valid: true},
		UserID: pgtype.UUID{Bytes: userID, Valid: true},
	})
}

// GetMonthlySummary returns income/expense summary for a given month.
func (s *Service) GetMonthlySummary(ctx context.Context, userID uuid.UUID, month time.Time) (sqlc.GetMonthlySummaryRow, error) {
	return s.q.GetMonthlySummary(ctx, sqlc.GetMonthlySummaryParams{
		UserID:  pgtype.UUID{Bytes: userID, Valid: true},
		Column2: pgtype.Date{Time: month, Valid: true},
	})
}

// GetCategoryBreakdown returns expense totals grouped by category for a given month.
func (s *Service) GetCategoryBreakdown(ctx context.Context, userID uuid.UUID, month time.Time) ([]sqlc.GetCategoryBreakdownRow, error) {
	return s.q.GetCategoryBreakdown(ctx, sqlc.GetCategoryBreakdownParams{
		UserID:  pgtype.UUID{Bytes: userID, Valid: true},
		Column2: pgtype.Date{Time: month, Valid: true},
	})
}
