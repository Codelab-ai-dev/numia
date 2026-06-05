package dashboard

import (
	"context"
	"fmt"
	"time"

	"numia-api/internal/database/sqlc"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

// Service provides dashboard-related business logic.
type Service struct {
	queries *sqlc.Queries
}

// NewService creates a new dashboard Service.
func NewService(q *sqlc.Queries) *Service {
	return &Service{queries: q}
}

// Summary holds the full dashboard data for a user.
type Summary struct {
	NetWorth       NetWorth       `json:"net_worth"`
	MonthlySummary MonthlySummary `json:"monthly_summary"`
	ActiveGoals    []GoalSummary  `json:"active_goals"`
	ActiveDebts    []DebtSummary  `json:"active_debts"`
}

// NetWorth holds asset and debt totals.
type NetWorth struct {
	TotalAssets float64 `json:"total_assets"`
	TotalDebt   float64 `json:"total_debt"`
	NetWorth    float64 `json:"net_worth"`
}

// MonthlySummary holds income/expense data for the current month.
type MonthlySummary struct {
	Income   float64 `json:"income"`
	Expenses float64 `json:"expenses"`
	Net      float64 `json:"net"`
	TxCount  int64   `json:"tx_count"`
}

// GoalSummary is a lightweight goal representation.
type GoalSummary struct {
	ID            string  `json:"id"`
	Name          string  `json:"name"`
	TargetAmount  float64 `json:"target_amount"`
	CurrentAmount float64 `json:"current_amount"`
	Emoji         *string `json:"emoji"`
}

// DebtSummary is a lightweight debt representation.
type DebtSummary struct {
	ID             string   `json:"id"`
	Name           string   `json:"name"`
	TotalAmount    float64  `json:"total_amount"`
	MonthlyPayment *float64 `json:"monthly_payment"`
}

// numericToFloat64 converts pgtype.Numeric to float64.
func numericToFloat64(n pgtype.Numeric) float64 {
	f8, err := n.Float64Value()
	if err != nil {
		return 0
	}
	if !f8.Valid {
		return 0
	}
	return f8.Float64
}

// GetSummary returns the full dashboard summary for a user.
func (s *Service) GetSummary(ctx context.Context, userID uuid.UUID) (Summary, error) {
	pgID := pgtype.UUID{Bytes: userID, Valid: true}

	// Total assets
	totalAssetsNum, err := s.queries.GetTotalAssets(ctx, pgID)
	if err != nil {
		return Summary{}, fmt.Errorf("get total assets: %w", err)
	}

	// Total debt
	totalDebtNum, err := s.queries.GetTotalDebt(ctx, pgID)
	if err != nil {
		return Summary{}, fmt.Errorf("get total debt: %w", err)
	}

	// Monthly summary (current month)
	now := time.Now()
	firstOfMonth := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
	monthDate := pgtype.Date{Time: firstOfMonth, Valid: true}

	monthlySummaryRow, err := s.queries.GetMonthlySummary(ctx, sqlc.GetMonthlySummaryParams{
		UserID:  pgID,
		Column2: monthDate,
	})
	if err != nil {
		return Summary{}, fmt.Errorf("get monthly summary: %w", err)
	}

	// Active goals
	goalRows, err := s.queries.GetActiveGoalsSummary(ctx, pgID)
	if err != nil {
		return Summary{}, fmt.Errorf("get active goals: %w", err)
	}

	// Active debts
	debtRows, err := s.queries.GetActiveDebtsSummary(ctx, pgID)
	if err != nil {
		return Summary{}, fmt.Errorf("get active debts: %w", err)
	}

	// Assemble net worth
	totalAssets := numericToFloat64(totalAssetsNum)
	totalDebt := numericToFloat64(totalDebtNum)
	nw := NetWorth{
		TotalAssets: totalAssets,
		TotalDebt:   totalDebt,
		NetWorth:    totalAssets - totalDebt,
	}

	// Assemble monthly summary
	ms := MonthlySummary{
		Income:   numericToFloat64(monthlySummaryRow.Income),
		Expenses: numericToFloat64(monthlySummaryRow.Expenses),
		Net:      numericToFloat64(monthlySummaryRow.Net),
		TxCount:  monthlySummaryRow.TxCount,
	}

	// Assemble goals
	goals := make([]GoalSummary, 0, len(goalRows))
	for _, g := range goalRows {
		gs := GoalSummary{
			ID:            g.ID.String(),
			Name:          g.Name,
			TargetAmount:  numericToFloat64(g.TargetAmount),
			CurrentAmount: numericToFloat64(g.CurrentAmount),
		}
		if g.Emoji.Valid {
			v := g.Emoji.String
			gs.Emoji = &v
		}
		goals = append(goals, gs)
	}

	// Assemble debts
	debts := make([]DebtSummary, 0, len(debtRows))
	for _, d := range debtRows {
		ds := DebtSummary{
			ID:          d.ID.String(),
			Name:        d.Name,
			TotalAmount: numericToFloat64(d.TotalAmount),
		}
		if d.MonthlyPayment.Valid {
			mp := numericToFloat64(d.MonthlyPayment)
			ds.MonthlyPayment = &mp
		}
		debts = append(debts, ds)
	}

	return Summary{
		NetWorth:       nw,
		MonthlySummary: ms,
		ActiveGoals:    goals,
		ActiveDebts:    debts,
	}, nil
}
