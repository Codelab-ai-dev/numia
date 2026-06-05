package budget

import (
	"context"
	"fmt"
	"log"
	"time"

	"numia-api/internal/database/sqlc"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

// predefinedCategory holds a default category seed.
type predefinedCategory struct {
	Name  string
	Emoji string
}

// predefinedCategories is the list of default categories seeded for new users.
var predefinedCategories = []predefinedCategory{
	{Name: "Alimentacion", Emoji: "🍔"},
	{Name: "Transporte", Emoji: "🚗"},
	{Name: "Vivienda", Emoji: "🏠"},
	{Name: "Salud", Emoji: "💊"},
	{Name: "Entretenimiento", Emoji: "🎬"},
	{Name: "Ropa", Emoji: "👗"},
	{Name: "Educacion", Emoji: "📚"},
	{Name: "Tecnologia", Emoji: "💻"},
	{Name: "Viajes", Emoji: "✈️"},
	{Name: "Hogar", Emoji: "🛋️"},
	{Name: "Mascotas", Emoji: "🐾"},
	{Name: "Otros", Emoji: "📦"},
}

// --- Request / Response types ---

// CreateCategoryRequest is the payload for creating a custom category.
type CreateCategoryRequest struct {
	Name  string `json:"name" binding:"required"`
	Emoji string `json:"emoji" binding:"required"`
}

// CreateBudgetRequest is the payload for creating or updating a budget.
type CreateBudgetRequest struct {
	GlobalAmount  float64 `json:"global_amount" binding:"required"`
	CycleStartDay int16   `json:"cycle_start_day" binding:"required"`
}

// AllocationItem represents a single category allocation in the budget.
type AllocationItem struct {
	CategoryID string  `json:"category_id" binding:"required"`
	Amount     float64 `json:"amount" binding:"required"`
}

// AllocationsRequest is the payload for setting budget allocations.
type AllocationsRequest struct {
	Items []AllocationItem `json:"items" binding:"required"`
}

// CreateExpenseRequest is the payload for creating an expense.
type CreateExpenseRequest struct {
	CategoryID  string   `json:"category_id" binding:"required"`
	Amount      float64  `json:"amount" binding:"required"`
	ExpenseDate string   `json:"expense_date" binding:"required"`
	Description *string  `json:"description"`
	Subcategory *string  `json:"subcategory"`
}

// UpdateExpenseRequest is the payload for updating an expense.
type UpdateExpenseRequest struct {
	CategoryID  string   `json:"category_id" binding:"required"`
	Amount      float64  `json:"amount" binding:"required"`
	ExpenseDate string   `json:"expense_date" binding:"required"`
	Description *string  `json:"description"`
	Subcategory *string  `json:"subcategory"`
}

// BudgetResponse is the API response for a budget.
type BudgetResponse struct {
	ID            string              `json:"id"`
	GlobalAmount  float64             `json:"global_amount"`
	CycleStartDay int16               `json:"cycle_start_day"`
	Allocations   []AllocationResponse `json:"allocations"`
}

// AllocationResponse is a single allocation in the budget response.
type AllocationResponse struct {
	ID            string  `json:"id"`
	CategoryID    string  `json:"category_id"`
	CategoryName  string  `json:"category_name"`
	CategoryEmoji string  `json:"category_emoji"`
	Amount        float64 `json:"amount"`
}

// CycleInfo holds start and end dates of the current cycle.
type CycleInfo struct {
	Start string `json:"start"`
	End   string `json:"end"`
}

// CategorySummary is a per-category summary row.
type CategorySummary struct {
	CategoryID    string  `json:"category_id"`
	CategoryName  string  `json:"category_name"`
	CategoryEmoji string  `json:"category_emoji"`
	Allocated     float64 `json:"allocated"`
	Spent         float64 `json:"spent"`
	Remaining     float64 `json:"remaining"`
	Percentage    float64 `json:"percentage"`
}

// GlobalSummary holds the overall budget summary for a cycle.
type GlobalSummary struct {
	TotalBudget    float64 `json:"total_budget"`
	TotalSpent     float64 `json:"total_spent"`
	TotalRemaining float64 `json:"total_remaining"`
	Percentage     float64 `json:"percentage"`
}

// SummaryResponse is the full summary response.
type SummaryResponse struct {
	Cycle      CycleInfo         `json:"cycle"`
	Global     GlobalSummary     `json:"global"`
	Categories []CategorySummary `json:"categories"`
}

// --- Helper functions ---

func numericFromFloat(f float64) pgtype.Numeric {
	var n pgtype.Numeric
	_ = n.Scan(fmt.Sprintf("%.2f", f))
	return n
}

func numericToFloat(n pgtype.Numeric) float64 {
	if !n.Valid {
		return 0
	}
	f, _ := n.Float64Value()
	return f.Float64
}

func optText(s *string) pgtype.Text {
	if s == nil {
		return pgtype.Text{}
	}
	return pgtype.Text{String: *s, Valid: true}
}

func pgUUID(id uuid.UUID) pgtype.UUID {
	return pgtype.UUID{Bytes: id, Valid: true}
}

func pgDate(t time.Time) pgtype.Date {
	return pgtype.Date{Time: t, Valid: true}
}

// getCurrentCycle returns the start and end of the current budget cycle
// given the cycleStartDay and a reference date.
func getCurrentCycle(cycleStartDay int16, ref time.Time) (start, end time.Time) {
	day := int(cycleStartDay)
	year, month, d := ref.Date()
	if d >= day {
		start = time.Date(year, month, day, 0, 0, 0, 0, time.UTC)
	} else {
		start = time.Date(year, month-1, day, 0, 0, 0, 0, time.UTC)
	}
	end = start.AddDate(0, 1, -1)
	return
}

// --- Service ---

// Service provides budget-related business logic.
type Service struct {
	q   *sqlc.Queries
	fcm *FCMClient
}

// NewService creates a new budget Service.
func NewService(q *sqlc.Queries, fcm *FCMClient) *Service {
	return &Service{q: q, fcm: fcm}
}

// seedPredefinedCategories inserts default categories for a new user if they
// do not already have any categories.
func (s *Service) seedPredefinedCategories(ctx context.Context, userID uuid.UUID) error {
	cats, err := s.q.ListBudgetCategories(ctx, pgUUID(userID))
	if err != nil {
		return err
	}
	if len(cats) > 0 {
		return nil
	}
	for _, pc := range predefinedCategories {
		_, err := s.q.CreateBudgetCategory(ctx, sqlc.CreateBudgetCategoryParams{
			UserID:   pgUUID(userID),
			Name:     pc.Name,
			Emoji:    pc.Emoji,
			IsCustom: false,
		})
		if err != nil {
			return err
		}
	}
	return nil
}

// ListCategories returns all active categories for a user, seeding defaults if needed.
func (s *Service) ListCategories(ctx context.Context, userID uuid.UUID) ([]sqlc.BudgetCategory, error) {
	if err := s.seedPredefinedCategories(ctx, userID); err != nil {
		return nil, err
	}
	all, err := s.q.ListBudgetCategories(ctx, pgUUID(userID))
	if err != nil {
		return nil, err
	}
	// Filter only active
	active := make([]sqlc.BudgetCategory, 0, len(all))
	for _, c := range all {
		if c.IsActive {
			active = append(active, c)
		}
	}
	return active, nil
}

// CreateCategory creates a custom category for a user.
func (s *Service) CreateCategory(ctx context.Context, userID uuid.UUID, req CreateCategoryRequest) (sqlc.BudgetCategory, error) {
	return s.q.CreateBudgetCategory(ctx, sqlc.CreateBudgetCategoryParams{
		UserID:   pgUUID(userID),
		Name:     req.Name,
		Emoji:    req.Emoji,
		IsCustom: true,
	})
}

// DeleteCategory soft-deletes a custom category.
func (s *Service) DeleteCategory(ctx context.Context, userID uuid.UUID, categoryID uuid.UUID) error {
	return s.q.SoftDeleteBudgetCategory(ctx, sqlc.SoftDeleteBudgetCategoryParams{
		ID:     pgUUID(categoryID),
		UserID: pgUUID(userID),
	})
}

// GetBudget returns the active budget and its allocations for a user.
func (s *Service) GetBudget(ctx context.Context, userID uuid.UUID) (BudgetResponse, error) {
	b, err := s.q.GetBudgetByUserID(ctx, pgUUID(userID))
	if err != nil {
		return BudgetResponse{}, err
	}
	allocRows, err := s.q.ListBudgetAllocations(ctx, b.ID)
	if err != nil {
		return BudgetResponse{}, err
	}
	allocations := make([]AllocationResponse, 0, len(allocRows))
	for _, a := range allocRows {
		allocations = append(allocations, AllocationResponse{
			ID:            uuidString(a.ID),
			CategoryID:    uuidString(a.CategoryID),
			CategoryName:  a.CategoryName,
			CategoryEmoji: a.CategoryEmoji,
			Amount:        numericToFloat(a.Amount),
		})
	}
	return BudgetResponse{
		ID:            uuidString(b.ID),
		GlobalAmount:  numericToFloat(b.GlobalAmount),
		CycleStartDay: b.CycleStartDay,
		Allocations:   allocations,
	}, nil
}

// CreateOrUpdateBudget upserts a budget for a user.
func (s *Service) CreateOrUpdateBudget(ctx context.Context, userID uuid.UUID, req CreateBudgetRequest) (BudgetResponse, error) {
	b, err := s.q.UpsertBudget(ctx, sqlc.UpsertBudgetParams{
		UserID:        pgUUID(userID),
		GlobalAmount:  numericFromFloat(req.GlobalAmount),
		CycleStartDay: req.CycleStartDay,
	})
	if err != nil {
		return BudgetResponse{}, err
	}
	allocRows, err := s.q.ListBudgetAllocations(ctx, b.ID)
	if err != nil {
		return BudgetResponse{}, err
	}
	allocations := make([]AllocationResponse, 0, len(allocRows))
	for _, a := range allocRows {
		allocations = append(allocations, AllocationResponse{
			ID:            uuidString(a.ID),
			CategoryID:    uuidString(a.CategoryID),
			CategoryName:  a.CategoryName,
			CategoryEmoji: a.CategoryEmoji,
			Amount:        numericToFloat(a.Amount),
		})
	}
	return BudgetResponse{
		ID:            uuidString(b.ID),
		GlobalAmount:  req.GlobalAmount,
		CycleStartDay: b.CycleStartDay,
		Allocations:   allocations,
	}, nil
}

// SetAllocations replaces all allocations for the user's budget.
func (s *Service) SetAllocations(ctx context.Context, userID uuid.UUID, req AllocationsRequest) (BudgetResponse, error) {
	b, err := s.q.GetBudgetByUserID(ctx, pgUUID(userID))
	if err != nil {
		return BudgetResponse{}, fmt.Errorf("budget not found: %w", err)
	}
	if err := s.q.DeleteAllocationsByBudget(ctx, b.ID); err != nil {
		return BudgetResponse{}, err
	}
	for _, item := range req.Items {
		catID, err := uuid.Parse(item.CategoryID)
		if err != nil {
			return BudgetResponse{}, fmt.Errorf("invalid category_id %s: %w", item.CategoryID, err)
		}
		_, err = s.q.CreateBudgetAllocation(ctx, sqlc.CreateBudgetAllocationParams{
			BudgetID:   b.ID,
			CategoryID: pgUUID(catID),
			Amount:     numericFromFloat(item.Amount),
		})
		if err != nil {
			return BudgetResponse{}, err
		}
	}
	return s.GetBudget(ctx, userID)
}

// ListExpenses returns expenses for a date range. If start/end are zero, uses
// the current budget cycle or calendar month as fallback.
func (s *Service) ListExpenses(ctx context.Context, userID uuid.UUID, startParam, endParam time.Time) ([]sqlc.ListExpensesByCycleRow, error) {
	var start, end time.Time

	if !startParam.IsZero() && !endParam.IsZero() {
		start = startParam
		end = endParam
	} else {
		now := time.Now().UTC()
		b, err := s.q.GetBudgetByUserID(ctx, pgUUID(userID))
		if err != nil {
			start = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
			end = start.AddDate(0, 1, -1)
		} else {
			start, end = getCurrentCycle(b.CycleStartDay, now)
		}
	}

	return s.q.ListExpensesByCycle(ctx, sqlc.ListExpensesByCycleParams{
		UserID:        pgUUID(userID),
		ExpenseDate:   pgDate(start),
		ExpenseDate_2: pgDate(end),
	})
}

// UpdateExpense updates an existing expense.
func (s *Service) UpdateExpense(ctx context.Context, userID uuid.UUID, expenseID uuid.UUID, req UpdateExpenseRequest) (sqlc.Expense, error) {
	catID, err := uuid.Parse(req.CategoryID)
	if err != nil {
		return sqlc.Expense{}, fmt.Errorf("invalid category_id: %w", err)
	}
	expDate, err := time.Parse("2006-01-02", req.ExpenseDate)
	if err != nil {
		return sqlc.Expense{}, fmt.Errorf("invalid expense_date: %w", err)
	}
	return s.q.UpdateExpense(ctx, sqlc.UpdateExpenseParams{
		ID:          pgUUID(expenseID),
		UserID:      pgUUID(userID),
		CategoryID:  pgUUID(catID),
		Amount:      numericFromFloat(req.Amount),
		Description: optText(req.Description),
		Subcategory: optText(req.Subcategory),
		ExpenseDate: pgDate(expDate),
	})
}

// CreateExpense creates a new expense for the user.
func (s *Service) CreateExpense(ctx context.Context, userID uuid.UUID, req CreateExpenseRequest) (sqlc.Expense, error) {
	catID, err := uuid.Parse(req.CategoryID)
	if err != nil {
		return sqlc.Expense{}, fmt.Errorf("invalid category_id: %w", err)
	}
	expDate, err := time.Parse("2006-01-02", req.ExpenseDate)
	if err != nil {
		return sqlc.Expense{}, fmt.Errorf("invalid expense_date: %w", err)
	}
	expense, err := s.q.CreateExpense(ctx, sqlc.CreateExpenseParams{
		UserID:      pgUUID(userID),
		CategoryID:  pgUUID(catID),
		Amount:      numericFromFloat(req.Amount),
		ExpenseDate: pgDate(expDate),
		Description: optText(req.Description),
		Subcategory: optText(req.Subcategory),
	})
	if err != nil {
		return sqlc.Expense{}, err
	}
	// Run notification check asynchronously
	go s.checkAndNotify(userID, catID)
	return expense, nil
}

// DeleteExpense removes an expense owned by the user.
func (s *Service) DeleteExpense(ctx context.Context, userID uuid.UUID, expenseID uuid.UUID) error {
	return s.q.DeleteExpense(ctx, sqlc.DeleteExpenseParams{
		ID:     pgUUID(expenseID),
		UserID: pgUUID(userID),
	})
}

// GetSummary returns the budget summary for the current cycle.
func (s *Service) GetSummary(ctx context.Context, userID uuid.UUID) (SummaryResponse, error) {
	b, err := s.q.GetBudgetByUserID(ctx, pgUUID(userID))
	if err != nil {
		return SummaryResponse{}, fmt.Errorf("budget not found: %w", err)
	}
	start, end := getCurrentCycle(b.CycleStartDay, time.Now().UTC())

	totalSpentN, err := s.q.SumAllExpensesCycle(ctx, sqlc.SumAllExpensesCycleParams{
		UserID:        pgUUID(userID),
		ExpenseDate:   pgDate(start),
		ExpenseDate_2: pgDate(end),
	})
	if err != nil {
		return SummaryResponse{}, err
	}
	totalSpent := numericToFloat(totalSpentN)
	globalAmount := numericToFloat(b.GlobalAmount)

	spentByCat, err := s.q.SumExpensesByCategoryCycle(ctx, sqlc.SumExpensesByCategoryCycleParams{
		UserID:        pgUUID(userID),
		ExpenseDate:   pgDate(start),
		ExpenseDate_2: pgDate(end),
	})
	if err != nil {
		return SummaryResponse{}, err
	}
	spentMap := make(map[string]float64)
	for _, row := range spentByCat {
		spentMap[uuidString(row.CategoryID)] = numericToFloat(row.TotalSpent)
	}

	allocRows, err := s.q.ListBudgetAllocations(ctx, b.ID)
	if err != nil {
		return SummaryResponse{}, err
	}

	categories := make([]CategorySummary, 0, len(allocRows))
	for _, a := range allocRows {
		catIDStr := uuidString(a.CategoryID)
		allocated := numericToFloat(a.Amount)
		spent := spentMap[catIDStr]
		remaining := allocated - spent
		var pct float64
		if allocated > 0 {
			pct = (spent / allocated) * 100
		}
		categories = append(categories, CategorySummary{
			CategoryID:    catIDStr,
			CategoryName:  a.CategoryName,
			CategoryEmoji: a.CategoryEmoji,
			Allocated:     allocated,
			Spent:         spent,
			Remaining:     remaining,
			Percentage:    pct,
		})
	}

	var globalPct float64
	if globalAmount > 0 {
		globalPct = (totalSpent / globalAmount) * 100
	}

	return SummaryResponse{
		Cycle: CycleInfo{
			Start: start.Format("2006-01-02"),
			End:   end.Format("2006-01-02"),
		},
		Global: GlobalSummary{
			TotalBudget:    globalAmount,
			TotalSpent:     totalSpent,
			TotalRemaining: globalAmount - totalSpent,
			Percentage:     globalPct,
		},
		Categories: categories,
	}, nil
}

// checkAndNotify checks budget thresholds and sends FCM notifications if needed.
// It runs as a goroutine and does not return errors.
func (s *Service) checkAndNotify(userID uuid.UUID, categoryID uuid.UUID) {
	ctx := context.Background()

	b, err := s.q.GetBudgetByUserID(ctx, pgUUID(userID))
	if err != nil {
		log.Printf("checkAndNotify: get budget: %v", err)
		return
	}
	start, end := getCurrentCycle(b.CycleStartDay, time.Now().UTC())

	// Get category info
	cat, err := s.q.GetBudgetCategoryByID(ctx, sqlc.GetBudgetCategoryByIDParams{
		ID:     pgUUID(categoryID),
		UserID: pgUUID(userID),
	})
	if err != nil {
		log.Printf("checkAndNotify: get category: %v", err)
		return
	}

	// Get allocated amount
	allocAmount, err := s.q.GetAllocationByCategoryAndBudget(ctx, sqlc.GetAllocationByCategoryAndBudgetParams{
		BudgetID:   b.ID,
		CategoryID: pgUUID(categoryID),
	})
	if err != nil {
		// No allocation for this category, skip
		return
	}
	allocated := numericToFloat(allocAmount)
	if allocated <= 0 {
		return
	}

	// Get spent sum for this category in cycle
	spentN, err := s.q.SumExpensesByCategoryID(ctx, sqlc.SumExpensesByCategoryIDParams{
		UserID:        pgUUID(userID),
		CategoryID:    pgUUID(categoryID),
		ExpenseDate:   pgDate(start),
		ExpenseDate_2: pgDate(end),
	})
	if err != nil {
		log.Printf("checkAndNotify: sum expenses: %v", err)
		return
	}
	spent := numericToFloat(spentN)
	pct := (spent / allocated) * 100

	// Get user devices
	devices, err := s.q.ListDevicesByUser(ctx, pgUUID(userID))
	if err != nil {
		log.Printf("checkAndNotify: list devices: %v", err)
		return
	}

	cycleStartDate := pgDate(start)

	for _, threshold := range []int16{100, 80} {
		var triggerPct float64
		if threshold == 100 {
			triggerPct = 100
		} else {
			triggerPct = 80
		}
		if pct < triggerPct {
			continue
		}

		sent, err := s.q.CheckNotificationSent(ctx, sqlc.CheckNotificationSentParams{
			UserID:     pgUUID(userID),
			CategoryID: pgUUID(categoryID),
			CycleStart: cycleStartDate,
			Threshold:  threshold,
		})
		if err != nil || sent {
			continue
		}

		// Determine notification content
		var title, body string
		if threshold == 100 {
			title = "Presupuesto"
			body = fmt.Sprintf("%s %s: superaste tu presupuesto", cat.Emoji, cat.Name)
		} else {
			title = "Presupuesto"
			body = fmt.Sprintf("%s %s: llevas el 80%% de tu presupuesto", cat.Emoji, cat.Name)
		}

		// Send to all devices
		if s.fcm != nil {
			for _, dev := range devices {
				if err := s.fcm.Send(ctx, dev.FcmToken, title, body); err != nil {
					log.Printf("checkAndNotify: send FCM: %v", err)
				}
			}
		}

		// Record notification
		if err := s.q.InsertNotification(ctx, sqlc.InsertNotificationParams{
			UserID:     pgUUID(userID),
			CategoryID: pgUUID(categoryID),
			CycleStart: cycleStartDate,
			Threshold:  threshold,
		}); err != nil {
			log.Printf("checkAndNotify: insert notification: %v", err)
		}
	}
}

// uuidString converts a pgtype.UUID to a string.
func uuidString(u pgtype.UUID) string {
	if !u.Valid {
		return ""
	}
	id := uuid.UUID(u.Bytes)
	return id.String()
}
