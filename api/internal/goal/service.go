package goal

import (
	"context"
	"fmt"
	"time"

	"numia-api/internal/database/sqlc"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

// CreateRequest is the payload for creating a goal.
type CreateRequest struct {
	Type                string   `json:"type" binding:"required"`
	Name                string   `json:"name" binding:"required"`
	TargetAmount        float64  `json:"target_amount" binding:"required"`
	MonthlyContribution *float64 `json:"monthly_contribution"`
	TargetDate          *string  `json:"target_date"`
	Priority            *int16   `json:"priority"`
	Emoji               *string  `json:"emoji"`
	Notes               *string  `json:"notes"`
}

// UpdateRequest is the payload for updating a goal.
type UpdateRequest struct {
	Name                *string  `json:"name"`
	TargetAmount        *float64 `json:"target_amount"`
	CurrentAmount       *float64 `json:"current_amount"`
	MonthlyContribution *float64 `json:"monthly_contribution"`
	Status              *string  `json:"status"`
	Emoji               *string  `json:"emoji"`
	Notes               *string  `json:"notes"`
}

// ContributeRequest is the payload for adding a contribution.
type ContributeRequest struct {
	Amount float64 `json:"amount" binding:"required"`
}

// Service provides goal-related business logic.
type Service struct {
	q *sqlc.Queries
}

// NewService creates a new goal Service.
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

// List returns goals for userID, optionally filtered by status.
func (s *Service) List(ctx context.Context, userID uuid.UUID, status *string) ([]sqlc.Goal, error) {
	params := sqlc.ListGoalsParams{
		UserID: pgtype.UUID{Bytes: userID, Valid: true},
	}
	if status != nil {
		params.Status = pgtype.Text{String: *status, Valid: true}
	}
	return s.q.ListGoals(ctx, params)
}

// Create inserts a new goal for userID.
func (s *Service) Create(ctx context.Context, userID uuid.UUID, req CreateRequest) (sqlc.Goal, error) {
	params := sqlc.CreateGoalParams{
		UserID:       pgtype.UUID{Bytes: userID, Valid: true},
		Type:         req.Type,
		Name:         req.Name,
		TargetAmount: numericFromFloat(req.TargetAmount),
		Emoji:        optText(req.Emoji),
		Notes:        optText(req.Notes),
	}
	if req.MonthlyContribution != nil {
		params.MonthlyContribution = numericFromFloat(*req.MonthlyContribution)
	}
	if req.Priority != nil {
		params.Priority = *req.Priority
	}
	if req.TargetDate != nil {
		t, err := time.Parse("2006-01-02", *req.TargetDate)
		if err != nil {
			return sqlc.Goal{}, fmt.Errorf("invalid target_date: %w", err)
		}
		params.TargetDate = pgtype.Date{Time: t, Valid: true}
	}
	return s.q.CreateGoal(ctx, params)
}

// Update modifies fields of a goal owned by userID.
func (s *Service) Update(ctx context.Context, userID uuid.UUID, goalID uuid.UUID, req UpdateRequest) (sqlc.Goal, error) {
	params := sqlc.UpdateGoalParams{
		ID:                  pgtype.UUID{Bytes: goalID, Valid: true},
		UserID:              pgtype.UUID{Bytes: userID, Valid: true},
		Name:                optText(req.Name),
		TargetAmount:        optNumeric(req.TargetAmount),
		CurrentAmount:       optNumeric(req.CurrentAmount),
		MonthlyContribution: optNumeric(req.MonthlyContribution),
		Status:              optText(req.Status),
		Emoji:               optText(req.Emoji),
		Notes:               optText(req.Notes),
	}
	return s.q.UpdateGoal(ctx, params)
}

// AddContribution increments the current_amount of a goal.
func (s *Service) AddContribution(ctx context.Context, userID uuid.UUID, goalID uuid.UUID, amount float64) (sqlc.Goal, error) {
	return s.q.AddContribution(ctx, sqlc.AddContributionParams{
		ID:            pgtype.UUID{Bytes: goalID, Valid: true},
		UserID:        pgtype.UUID{Bytes: userID, Valid: true},
		CurrentAmount: numericFromFloat(amount),
	})
}

// Delete removes a goal owned by userID.
func (s *Service) Delete(ctx context.Context, userID uuid.UUID, goalID uuid.UUID) error {
	return s.q.DeleteGoal(ctx, sqlc.DeleteGoalParams{
		ID:     pgtype.UUID{Bytes: goalID, Valid: true},
		UserID: pgtype.UUID{Bytes: userID, Valid: true},
	})
}
