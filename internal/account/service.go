package account

import (
	"context"
	"fmt"

	"numia-api/internal/database/sqlc"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

// CreateRequest is the payload for creating an account.
type CreateRequest struct {
	Name        string   `json:"name" binding:"required"`
	Type        string   `json:"type" binding:"required"`
	Currency    string   `json:"currency" binding:"required"`
	Balance     float64  `json:"balance"`
	CreditLimit *float64 `json:"credit_limit"`
}

// UpdateRequest is the payload for updating an account.
type UpdateRequest struct {
	Name     *string  `json:"name"`
	Balance  *float64 `json:"balance"`
	IsActive *bool    `json:"is_active"`
}

// Service provides account-related business logic.
type Service struct {
	q *sqlc.Queries
}

// NewService creates a new account Service.
func NewService(q *sqlc.Queries) *Service {
	return &Service{q: q}
}

func numericFromFloat(f float64) pgtype.Numeric {
	var n pgtype.Numeric
	_ = n.Scan(fmt.Sprintf("%.2f", f))
	return n
}

// List returns all active accounts for the given userID.
func (s *Service) List(ctx context.Context, userID uuid.UUID) ([]sqlc.Account, error) {
	return s.q.ListAccountsByUser(ctx, pgtype.UUID{Bytes: userID, Valid: true})
}

// Create inserts a new account for the given userID.
func (s *Service) Create(ctx context.Context, userID uuid.UUID, req CreateRequest) (sqlc.Account, error) {
	creditLimit := numericFromFloat(0)
	if req.CreditLimit != nil {
		creditLimit = numericFromFloat(*req.CreditLimit)
	}
	params := sqlc.CreateAccountParams{
		UserID:      pgtype.UUID{Bytes: userID, Valid: true},
		Name:        req.Name,
		Type:        pgtype.Text{String: req.Type, Valid: true},
		Currency:    req.Currency,
		Balance:     numericFromFloat(req.Balance),
		CreditLimit: creditLimit,
	}
	return s.q.CreateAccount(ctx, params)
}

// Update modifies an existing account owned by userID.
func (s *Service) Update(ctx context.Context, userID uuid.UUID, accountID uuid.UUID, req UpdateRequest) (sqlc.Account, error) {
	params := sqlc.UpdateAccountParams{
		ID:     pgtype.UUID{Bytes: accountID, Valid: true},
		UserID: pgtype.UUID{Bytes: userID, Valid: true},
	}
	if req.Name != nil {
		params.Name = pgtype.Text{String: *req.Name, Valid: true}
	}
	if req.Balance != nil {
		params.Balance = numericFromFloat(*req.Balance)
	}
	if req.IsActive != nil {
		params.IsActive = pgtype.Bool{Bool: *req.IsActive, Valid: true}
	}
	return s.q.UpdateAccount(ctx, params)
}

// Delete removes an account owned by userID.
func (s *Service) Delete(ctx context.Context, userID uuid.UUID, accountID uuid.UUID) error {
	return s.q.DeleteAccount(ctx, sqlc.DeleteAccountParams{
		ID:     pgtype.UUID{Bytes: accountID, Valid: true},
		UserID: pgtype.UUID{Bytes: userID, Valid: true},
	})
}
