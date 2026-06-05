# Budget & Expenses Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add budget and expense tracking with per-category allocations, push notifications at 80%/100% thresholds, and a new Flutter bottom nav tab with 4 screens.

**Architecture:** Go backend adds 2 new packages (`budget`, `device`) with 6 new DB tables, SQLC queries, and FCM integration. Flutter adds a `budget` feature with domain models, repository, and 4 screens. Bottom nav expands from 5 to 6 tabs.

**Tech Stack:** Go/Gin/SQLC/pgx (backend), Flutter/Riverpod/GoRouter/Dio (frontend), Firebase Cloud Messaging (push notifications)

**Spec:** `docs/superpowers/specs/2026-06-04-budget-expenses-design.md`

---

## File Structure

### Go Backend (`numia-api`)

| File | Responsibility |
|------|---------------|
| `internal/database/migrations/000002_budget_tables.up.sql` | New tables: budget_categories, budgets, budget_allocations, expenses, devices, budget_notifications |
| `internal/database/migrations/000002_budget_tables.down.sql` | Drop all 6 new tables |
| `internal/database/queries/budget_categories.sql` | SQLC queries for category CRUD |
| `internal/database/queries/budgets.sql` | SQLC queries for budget + allocations |
| `internal/database/queries/expenses.sql` | SQLC queries for expense CRUD + summary aggregation |
| `internal/database/queries/devices.sql` | SQLC queries for FCM device token CRUD |
| `internal/database/queries/budget_notifications.sql` | SQLC queries for notification tracking |
| `internal/budget/service.go` | Business logic: categories, budget, allocations, expenses, summary, cycle calculation, notification trigger |
| `internal/budget/handler.go` | HTTP handlers for all /budget/* endpoints |
| `internal/budget/fcm.go` | Firebase Cloud Messaging client wrapper |
| `internal/device/service.go` | Device token CRUD logic |
| `internal/device/handler.go` | HTTP handlers for /devices endpoints |
| `internal/config/config.go` | Add FirebaseCredentialsPath field |
| `cmd/api/main.go` | Wire budget + device modules |

### Flutter (`numia`)

| File | Responsibility |
|------|---------------|
| `lib/features/budget/domain/budget_category.dart` | BudgetCategory model |
| `lib/features/budget/domain/budget.dart` | Budget + BudgetAllocation models |
| `lib/features/budget/domain/expense.dart` | Expense model |
| `lib/features/budget/domain/budget_summary.dart` | BudgetSummary model |
| `lib/features/budget/data/budget_repository.dart` | API calls for all budget endpoints |
| `lib/features/budget/presentation/budget_screen.dart` | Main tab screen (empty + active states) |
| `lib/features/budget/presentation/budget_setup_screen.dart` | 2-step budget setup wizard |
| `lib/features/budget/presentation/add_expense_sheet.dart` | Bottom sheet for adding expenses |
| `lib/features/budget/presentation/category_detail_screen.dart` | Category drill-down with expense list |
| `lib/core/providers.dart` | Add budget providers |
| `lib/app/router.dart` | Add /budget route + update shell routes |
| `lib/shared/widgets/n_bottom_nav.dart` | Add 6th "Presupuesto" tab |

---

### Task 1: Database Migration

**Files:**
- Create: `numia-api/internal/database/migrations/000002_budget_tables.up.sql`
- Create: `numia-api/internal/database/migrations/000002_budget_tables.down.sql`

- [ ] **Step 1: Create up migration**

```sql
-- 000002_budget_tables.up.sql

-- Budget categories (user-scoped)
CREATE TABLE budget_categories (
    id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name       VARCHAR(100) NOT NULL,
    emoji      VARCHAR(10)  NOT NULL,
    is_custom  BOOLEAN     NOT NULL DEFAULT FALSE,
    is_active  BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, name)
);

-- Budgets (one active per user)
CREATE TABLE budgets (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    global_amount   NUMERIC(12,2) NOT NULL,
    cycle_start_day SMALLINT    NOT NULL DEFAULT 1 CHECK (cycle_start_day BETWEEN 1 AND 28),
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Budget allocations (per-category within a budget)
CREATE TABLE budget_allocations (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id   UUID        NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
    category_id UUID        NOT NULL REFERENCES budget_categories(id) ON DELETE CASCADE,
    amount      NUMERIC(12,2) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(budget_id, category_id)
);

-- Expenses
CREATE TABLE expenses (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id  UUID        NOT NULL REFERENCES budget_categories(id),
    amount       NUMERIC(12,2) NOT NULL,
    description  TEXT,
    subcategory  VARCHAR(100),
    expense_date DATE        NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Devices (FCM tokens)
CREATE TABLE devices (
    id        UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id   UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    fcm_token TEXT        NOT NULL UNIQUE,
    platform  VARCHAR(10) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Budget notifications (dedup per cycle)
CREATE TABLE budget_notifications (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id UUID        NOT NULL REFERENCES budget_categories(id),
    cycle_start DATE        NOT NULL,
    threshold   SMALLINT    NOT NULL,
    sent_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, category_id, cycle_start, threshold)
);

-- Indexes
CREATE INDEX idx_budget_categories_user ON budget_categories(user_id);
CREATE INDEX idx_budget_allocations_budget ON budget_allocations(budget_id);
CREATE INDEX idx_expenses_user_date ON expenses(user_id, expense_date);
CREATE INDEX idx_expenses_user_category ON expenses(user_id, category_id);
CREATE INDEX idx_devices_user ON devices(user_id);
CREATE INDEX idx_budget_notifications_user ON budget_notifications(user_id, category_id, cycle_start);

-- Triggers
CREATE TRIGGER trg_budgets_updated_at
    BEFORE UPDATE ON budgets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_budget_allocations_updated_at
    BEFORE UPDATE ON budget_allocations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

- [ ] **Step 2: Create down migration**

```sql
-- 000002_budget_tables.down.sql
DROP TABLE IF EXISTS budget_notifications;
DROP TABLE IF EXISTS devices;
DROP TABLE IF EXISTS expenses;
DROP TABLE IF EXISTS budget_allocations;
DROP TABLE IF EXISTS budgets;
DROP TABLE IF EXISTS budget_categories;
```

- [ ] **Step 3: Run migration against local DB**

Run: `cd /Users/gustavo/Desktop/numia-api && docker compose exec db psql -U numia -d numia -f /dev/stdin < internal/database/migrations/000002_budget_tables.up.sql`

Or if using migrate tool: apply migration 000002.

- [ ] **Step 4: Verify tables exist**

Run: `docker compose exec db psql -U numia -d numia -c "\dt"` — should show all 6 new tables.

- [ ] **Step 5: Commit**

```bash
git add internal/database/migrations/000002_budget_tables.up.sql internal/database/migrations/000002_budget_tables.down.sql
git commit -m "feat: add budget tables migration (categories, budgets, allocations, expenses, devices, notifications)"
```

---

### Task 2: SQLC Queries — Categories, Budgets, Allocations

**Files:**
- Create: `numia-api/internal/database/queries/budget_categories.sql`
- Create: `numia-api/internal/database/queries/budgets.sql`

- [ ] **Step 1: Write budget_categories.sql**

```sql
-- name: ListBudgetCategories :many
SELECT * FROM budget_categories
WHERE user_id = $1
ORDER BY is_custom ASC, name ASC;

-- name: GetBudgetCategoryByID :one
SELECT * FROM budget_categories
WHERE id = $1 AND user_id = $2;

-- name: CreateBudgetCategory :one
INSERT INTO budget_categories (user_id, name, emoji, is_custom)
VALUES ($1, $2, $3, $4)
RETURNING *;

-- name: SoftDeleteBudgetCategory :exec
UPDATE budget_categories
SET is_active = FALSE
WHERE id = $1 AND user_id = $2 AND is_custom = TRUE;
```

- [ ] **Step 2: Write budgets.sql**

```sql
-- name: GetBudgetByUserID :one
SELECT * FROM budgets
WHERE user_id = $1 AND is_active = TRUE;

-- name: UpsertBudget :one
INSERT INTO budgets (user_id, global_amount, cycle_start_day)
VALUES ($1, $2, $3)
ON CONFLICT (user_id) DO UPDATE
SET global_amount = EXCLUDED.global_amount,
    cycle_start_day = EXCLUDED.cycle_start_day,
    is_active = TRUE
RETURNING *;

-- name: ListBudgetAllocations :many
SELECT ba.*, bc.name AS category_name, bc.emoji AS category_emoji
FROM budget_allocations ba
JOIN budget_categories bc ON bc.id = ba.category_id
WHERE ba.budget_id = $1
ORDER BY bc.name ASC;

-- name: DeleteAllocationsByBudget :exec
DELETE FROM budget_allocations WHERE budget_id = $1;

-- name: CreateBudgetAllocation :one
INSERT INTO budget_allocations (budget_id, category_id, amount)
VALUES ($1, $2, $3)
RETURNING *;

-- name: GetAllocationByCategoryAndBudget :one
SELECT ba.amount FROM budget_allocations ba
WHERE ba.budget_id = $1 AND ba.category_id = $2;
```

- [ ] **Step 3: Run sqlc generate**

Run: `cd /Users/gustavo/Desktop/numia-api && sqlc generate`
Expected: No errors. New Go files generated in `internal/database/sqlc/`.

- [ ] **Step 4: Verify generated code compiles**

Run: `cd /Users/gustavo/Desktop/numia-api && go build ./...`
Expected: Build success.

- [ ] **Step 5: Commit**

```bash
git add internal/database/queries/budget_categories.sql internal/database/queries/budgets.sql internal/database/sqlc/
git commit -m "feat: add SQLC queries for budget categories and budgets"
```

---

### Task 3: SQLC Queries — Expenses, Devices, Notifications

**Files:**
- Create: `numia-api/internal/database/queries/expenses.sql`
- Create: `numia-api/internal/database/queries/devices.sql`
- Create: `numia-api/internal/database/queries/budget_notifications.sql`

- [ ] **Step 1: Write expenses.sql**

```sql
-- name: ListExpensesByCycle :many
SELECT e.*, bc.name AS category_name, bc.emoji AS category_emoji
FROM expenses e
JOIN budget_categories bc ON bc.id = e.category_id
WHERE e.user_id = $1
  AND e.expense_date >= $2
  AND e.expense_date <= $3
ORDER BY e.expense_date DESC, e.created_at DESC;

-- name: CreateExpense :one
INSERT INTO expenses (user_id, category_id, amount, description, subcategory, expense_date)
VALUES ($1, $2, $3, sqlc.narg('description'), sqlc.narg('subcategory'), $4)
RETURNING *;

-- name: DeleteExpense :exec
DELETE FROM expenses WHERE id = $1 AND user_id = $2;

-- name: SumExpensesByCategoryCycle :many
SELECT category_id, COALESCE(SUM(amount), 0)::NUMERIC(12,2) AS total_spent
FROM expenses
WHERE user_id = $1
  AND expense_date >= $2
  AND expense_date <= $3
GROUP BY category_id;

-- name: SumExpensesByCategoryID :one
SELECT COALESCE(SUM(amount), 0)::NUMERIC(12,2) AS total_spent
FROM expenses
WHERE user_id = $1
  AND category_id = $2
  AND expense_date >= $3
  AND expense_date <= $4;

-- name: SumAllExpensesCycle :one
SELECT COALESCE(SUM(amount), 0)::NUMERIC(12,2) AS total_spent
FROM expenses
WHERE user_id = $1
  AND expense_date >= $2
  AND expense_date <= $3;
```

- [ ] **Step 2: Write devices.sql**

```sql
-- name: UpsertDevice :exec
INSERT INTO devices (user_id, fcm_token, platform)
VALUES ($1, $2, $3)
ON CONFLICT (fcm_token) DO UPDATE
SET user_id = EXCLUDED.user_id,
    platform = EXCLUDED.platform;

-- name: DeleteDevice :exec
DELETE FROM devices WHERE fcm_token = $1;

-- name: ListDevicesByUser :many
SELECT * FROM devices WHERE user_id = $1;
```

- [ ] **Step 3: Write budget_notifications.sql**

```sql
-- name: CheckNotificationSent :one
SELECT EXISTS(
    SELECT 1 FROM budget_notifications
    WHERE user_id = $1
      AND category_id = $2
      AND cycle_start = $3
      AND threshold = $4
) AS sent;

-- name: InsertNotification :exec
INSERT INTO budget_notifications (user_id, category_id, cycle_start, threshold)
VALUES ($1, $2, $3, $4)
ON CONFLICT (user_id, category_id, cycle_start, threshold) DO NOTHING;
```

- [ ] **Step 4: Run sqlc generate and verify**

Run: `cd /Users/gustavo/Desktop/numia-api && sqlc generate && go build ./...`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add internal/database/queries/expenses.sql internal/database/queries/devices.sql internal/database/queries/budget_notifications.sql internal/database/sqlc/
git commit -m "feat: add SQLC queries for expenses, devices, and budget notifications"
```

---

### Task 4: Budget Service — Cycle Logic, Categories, Budget CRUD

**Files:**
- Create: `numia-api/internal/budget/service.go`

- [ ] **Step 1: Create service.go with types and cycle logic**

```go
package budget

import (
	"context"
	"fmt"
	"time"

	"numia-api/internal/database/sqlc"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

// ── Request types ───────────────────────────────────────────

type CreateCategoryRequest struct {
	Name  string `json:"name" binding:"required"`
	Emoji string `json:"emoji" binding:"required"`
}

type CreateBudgetRequest struct {
	GlobalAmount  float64 `json:"global_amount" binding:"required"`
	CycleStartDay int16   `json:"cycle_start_day" binding:"required"`
}

type AllocationItem struct {
	CategoryID string  `json:"category_id" binding:"required"`
	Amount     float64 `json:"amount" binding:"required"`
}

type AllocationsRequest struct {
	Allocations []AllocationItem `json:"allocations" binding:"required"`
}

type CreateExpenseRequest struct {
	CategoryID  string  `json:"category_id" binding:"required"`
	Amount      float64 `json:"amount" binding:"required"`
	Description *string `json:"description"`
	Subcategory *string `json:"subcategory"`
	ExpenseDate string  `json:"expense_date" binding:"required"`
}

// ── Response types ───────────────────────────────────────────

type BudgetResponse struct {
	ID            string               `json:"id"`
	GlobalAmount  float64              `json:"global_amount"`
	CycleStartDay int16                `json:"cycle_start_day"`
	Allocations   []AllocationResponse `json:"allocations"`
}

type AllocationResponse struct {
	ID            string  `json:"id"`
	CategoryID    string  `json:"category_id"`
	CategoryName  string  `json:"category_name"`
	CategoryEmoji string  `json:"category_emoji"`
	Amount        float64 `json:"amount"`
}

type SummaryResponse struct {
	Cycle            CycleInfo         `json:"cycle"`
	Global           GlobalSummary     `json:"global"`
	Categories       []CategorySummary `json:"categories"`
	UnallocatedSpent float64           `json:"unallocated_spent"`
}

type CycleInfo struct {
	Start string `json:"start"`
	End   string `json:"end"`
}

type GlobalSummary struct {
	Budgeted   float64 `json:"budgeted"`
	Spent      float64 `json:"spent"`
	Percentage float64 `json:"percentage"`
}

type CategorySummary struct {
	CategoryID string  `json:"category_id"`
	Name       string  `json:"name"`
	Emoji      string  `json:"emoji"`
	Budgeted   float64 `json:"budgeted"`
	Spent      float64 `json:"spent"`
	Percentage float64 `json:"percentage"`
}

// ── Predefined categories ────────────────────────────────────

var predefinedCategories = []struct {
	Emoji string
	Name  string
}{
	{"🍔", "Comida"},
	{"🚗", "Transporte"},
	{"🏠", "Vivienda"},
	{"🎬", "Entretenimiento"},
	{"👕", "Ropa"},
	{"💊", "Salud"},
	{"📚", "Educación"},
	{"💼", "Servicios"},
	{"🎁", "Regalos"},
	{"🐕", "Mascotas"},
	{"✈️", "Viajes"},
	{"📦", "Otros"},
}

// ── Helpers ──────────────────────────────────────────────────

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

// ── Cycle calculation ────────────────────────────────────────

func getCurrentCycle(cycleStartDay int16, ref time.Time) (start, end time.Time) {
	day := int(cycleStartDay)
	year, month, d := ref.Date()

	if d >= day {
		start = time.Date(year, month, day, 0, 0, 0, 0, time.UTC)
	} else {
		start = time.Date(year, month-1, day, 0, 0, 0, 0, time.UTC)
	}
	// End = start + 1 month - 1 day
	end = start.AddDate(0, 1, -1)
	return
}

// ── Service ──────────────────────────────────────────────────

type Service struct {
	q   *sqlc.Queries
	fcm *FCMClient
}

func NewService(q *sqlc.Queries, fcm *FCMClient) *Service {
	return &Service{q: q, fcm: fcm}
}

// ── Categories ───────────────────────────────────────────────

func (s *Service) ListCategories(ctx context.Context, userID uuid.UUID) ([]sqlc.BudgetCategory, error) {
	return s.q.ListBudgetCategories(ctx, pgUUID(userID))
}

func (s *Service) CreateCategory(ctx context.Context, userID uuid.UUID, req CreateCategoryRequest) (sqlc.BudgetCategory, error) {
	return s.q.CreateBudgetCategory(ctx, sqlc.CreateBudgetCategoryParams{
		UserID:   pgUUID(userID),
		Name:     req.Name,
		Emoji:    req.Emoji,
		IsCustom: true,
	})
}

func (s *Service) DeleteCategory(ctx context.Context, userID uuid.UUID, categoryID uuid.UUID) error {
	cat, err := s.q.GetBudgetCategoryByID(ctx, sqlc.GetBudgetCategoryByIDParams{
		ID:     pgUUID(categoryID),
		UserID: pgUUID(userID),
	})
	if err != nil {
		return fmt.Errorf("category not found")
	}
	if !cat.IsCustom {
		return fmt.Errorf("cannot delete predefined category")
	}
	return s.q.SoftDeleteBudgetCategory(ctx, sqlc.SoftDeleteBudgetCategoryParams{
		ID:     pgUUID(categoryID),
		UserID: pgUUID(userID),
	})
}

// seedPredefinedCategories creates the 12 default categories for a user.
func (s *Service) seedPredefinedCategories(ctx context.Context, userID uuid.UUID) error {
	for _, cat := range predefinedCategories {
		_, err := s.q.CreateBudgetCategory(ctx, sqlc.CreateBudgetCategoryParams{
			UserID:   pgUUID(userID),
			Name:     cat.Name,
			Emoji:    cat.Emoji,
			IsCustom: false,
		})
		if err != nil {
			return fmt.Errorf("seeding category %s: %w", cat.Name, err)
		}
	}
	return nil
}

// ── Budget CRUD ──────────────────────────────────────────────

func (s *Service) GetBudget(ctx context.Context, userID uuid.UUID) (*BudgetResponse, error) {
	budget, err := s.q.GetBudgetByUserID(ctx, pgUUID(userID))
	if err != nil {
		return nil, nil // no budget configured
	}
	allocations, err := s.q.ListBudgetAllocations(ctx, pgUUID(budget.ID.Bytes))
	if err != nil {
		return nil, err
	}
	allocs := make([]AllocationResponse, len(allocations))
	for i, a := range allocations {
		allocs[i] = AllocationResponse{
			ID:            uuid.UUID(a.ID.Bytes).String(),
			CategoryID:    uuid.UUID(a.CategoryID.Bytes).String(),
			CategoryName:  a.CategoryName,
			CategoryEmoji: a.CategoryEmoji,
			Amount:        numericToFloat(a.Amount),
		}
	}
	return &BudgetResponse{
		ID:            uuid.UUID(budget.ID.Bytes).String(),
		GlobalAmount:  numericToFloat(budget.GlobalAmount),
		CycleStartDay: budget.CycleStartDay,
		Allocations:   allocs,
	}, nil
}

func (s *Service) CreateOrUpdateBudget(ctx context.Context, userID uuid.UUID, req CreateBudgetRequest) (*BudgetResponse, error) {
	// Check if categories exist; if not, seed them
	cats, err := s.q.ListBudgetCategories(ctx, pgUUID(userID))
	if err != nil {
		return nil, err
	}
	if len(cats) == 0 {
		if err := s.seedPredefinedCategories(ctx, userID); err != nil {
			return nil, err
		}
	}

	budget, err := s.q.UpsertBudget(ctx, sqlc.UpsertBudgetParams{
		UserID:       pgUUID(userID),
		GlobalAmount: numericFromFloat(req.GlobalAmount),
		CycleStartDay: req.CycleStartDay,
	})
	if err != nil {
		return nil, err
	}

	return &BudgetResponse{
		ID:            uuid.UUID(budget.ID.Bytes).String(),
		GlobalAmount:  numericToFloat(budget.GlobalAmount),
		CycleStartDay: budget.CycleStartDay,
		Allocations:   []AllocationResponse{},
	}, nil
}

func (s *Service) SetAllocations(ctx context.Context, userID uuid.UUID, req AllocationsRequest) ([]AllocationResponse, error) {
	budget, err := s.q.GetBudgetByUserID(ctx, pgUUID(userID))
	if err != nil {
		return nil, fmt.Errorf("no budget configured")
	}

	// Validate sum <= global_amount
	budgetAmt := numericToFloat(budget.GlobalAmount)
	var sum float64
	for _, a := range req.Allocations {
		sum += a.Amount
	}
	if sum > budgetAmt {
		return nil, fmt.Errorf("allocation sum %.2f exceeds budget %.2f", sum, budgetAmt)
	}

	budgetUUID := uuid.UUID(budget.ID.Bytes)

	// Delete existing allocations and re-create
	if err := s.q.DeleteAllocationsByBudget(ctx, pgUUID(budgetUUID)); err != nil {
		return nil, err
	}

	allocs := make([]AllocationResponse, 0, len(req.Allocations))
	for _, item := range req.Allocations {
		catID, err := uuid.Parse(item.CategoryID)
		if err != nil {
			return nil, fmt.Errorf("invalid category_id: %s", item.CategoryID)
		}
		a, err := s.q.CreateBudgetAllocation(ctx, sqlc.CreateBudgetAllocationParams{
			BudgetID:   pgUUID(budgetUUID),
			CategoryID: pgUUID(catID),
			Amount:     numericFromFloat(item.Amount),
		})
		if err != nil {
			return nil, err
		}
		// Fetch category info for response
		cat, err := s.q.GetBudgetCategoryByID(ctx, sqlc.GetBudgetCategoryByIDParams{
			ID:     pgUUID(catID),
			UserID: pgUUID(userID),
		})
		if err != nil {
			return nil, err
		}
		allocs = append(allocs, AllocationResponse{
			ID:            uuid.UUID(a.ID.Bytes).String(),
			CategoryID:    uuid.UUID(a.CategoryID.Bytes).String(),
			CategoryName:  cat.Name,
			CategoryEmoji: cat.Emoji,
			Amount:        numericToFloat(a.Amount),
		})
	}
	return allocs, nil
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/gustavo/Desktop/numia-api && go build ./...`
Expected: Build success (FCMClient will be a stub at this point — add a placeholder in next task).

- [ ] **Step 3: Commit**

```bash
git add internal/budget/service.go
git commit -m "feat: add budget service with cycle logic, categories, and budget CRUD"
```

---

### Task 5: Budget Service — Expenses, Summary, Notification Trigger

**Files:**
- Modify: `numia-api/internal/budget/service.go` (append expense and summary methods)

- [ ] **Step 1: Add expense and summary methods to service.go**

Append after the `SetAllocations` method:

```go
// ── Expenses ─────────────────────────────────────────────────

func (s *Service) ListExpenses(ctx context.Context, userID uuid.UUID) ([]sqlc.ListExpensesByCycleRow, error) {
	budget, err := s.q.GetBudgetByUserID(ctx, pgUUID(userID))
	if err != nil {
		return nil, fmt.Errorf("no budget configured")
	}
	start, end := getCurrentCycle(budget.CycleStartDay, time.Now())
	return s.q.ListExpensesByCycle(ctx, sqlc.ListExpensesByCycleParams{
		UserID:       pgUUID(userID),
		ExpenseDate:  pgDate(start),
		ExpenseDate_2: pgDate(end),
	})
}

type CreateExpenseResponse struct {
	Expense       sqlc.Expense `json:"expense"`
	AlertCategory *string      `json:"alert_category,omitempty"`
	AlertPercent  *float64     `json:"alert_percent,omitempty"`
}

func (s *Service) CreateExpense(ctx context.Context, userID uuid.UUID, req CreateExpenseRequest) (*CreateExpenseResponse, error) {
	catID, err := uuid.Parse(req.CategoryID)
	if err != nil {
		return nil, fmt.Errorf("invalid category_id")
	}
	expDate, err := time.Parse("2006-01-02", req.ExpenseDate)
	if err != nil {
		return nil, fmt.Errorf("invalid expense_date: use YYYY-MM-DD")
	}

	expense, err := s.q.CreateExpense(ctx, sqlc.CreateExpenseParams{
		UserID:      pgUUID(userID),
		CategoryID:  pgUUID(catID),
		Amount:      numericFromFloat(req.Amount),
		Description: optText(req.Description),
		Subcategory: optText(req.Subcategory),
		ExpenseDate: pgDate(expDate),
	})
	if err != nil {
		return nil, err
	}

	resp := &CreateExpenseResponse{Expense: expense}

	// Check notification thresholds
	go s.checkAndNotify(context.Background(), userID, catID)

	return resp, nil
}

func (s *Service) DeleteExpense(ctx context.Context, userID uuid.UUID, expenseID uuid.UUID) error {
	return s.q.DeleteExpense(ctx, sqlc.DeleteExpenseParams{
		ID:     pgUUID(expenseID),
		UserID: pgUUID(userID),
	})
}

// ── Summary ──────────────────────────────────────────────────

func (s *Service) GetSummary(ctx context.Context, userID uuid.UUID) (*SummaryResponse, error) {
	budget, err := s.q.GetBudgetByUserID(ctx, pgUUID(userID))
	if err != nil {
		return nil, fmt.Errorf("no budget configured")
	}

	start, end := getCurrentCycle(budget.CycleStartDay, time.Now())
	budgetUUID := uuid.UUID(budget.ID.Bytes)
	globalAmt := numericToFloat(budget.GlobalAmount)

	// Get total spent
	totalRow, err := s.q.SumAllExpensesCycle(ctx, sqlc.SumAllExpensesCycleParams{
		UserID:        pgUUID(userID),
		ExpenseDate:   pgDate(start),
		ExpenseDate_2: pgDate(end),
	})
	if err != nil {
		return nil, err
	}
	totalSpent := numericToFloat(totalRow)

	// Get per-category spent
	catSpent, err := s.q.SumExpensesByCategoryCycle(ctx, sqlc.SumExpensesByCategoryCycleParams{
		UserID:        pgUUID(userID),
		ExpenseDate:   pgDate(start),
		ExpenseDate_2: pgDate(end),
	})
	if err != nil {
		return nil, err
	}
	spentMap := make(map[uuid.UUID]float64)
	for _, cs := range catSpent {
		spentMap[uuid.UUID(cs.CategoryID.Bytes)] = numericToFloat(cs.TotalSpent)
	}

	// Get allocations
	allocs, err := s.q.ListBudgetAllocations(ctx, pgUUID(budgetUUID))
	if err != nil {
		return nil, err
	}

	var allocatedSpent float64
	categories := make([]CategorySummary, 0, len(allocs))
	for _, a := range allocs {
		catID := uuid.UUID(a.CategoryID.Bytes)
		allocated := numericToFloat(a.Amount)
		spent := spentMap[catID]
		allocatedSpent += spent
		pct := float64(0)
		if allocated > 0 {
			pct = (spent / allocated) * 100
		}
		categories = append(categories, CategorySummary{
			CategoryID: catID.String(),
			Name:       a.CategoryName,
			Emoji:      a.CategoryEmoji,
			Budgeted:   allocated,
			Spent:      spent,
			Percentage: pct,
		})
	}

	globalPct := float64(0)
	if globalAmt > 0 {
		globalPct = (totalSpent / globalAmt) * 100
	}

	return &SummaryResponse{
		Cycle: CycleInfo{
			Start: start.Format("2006-01-02"),
			End:   end.Format("2006-01-02"),
		},
		Global: GlobalSummary{
			Budgeted:   globalAmt,
			Spent:      totalSpent,
			Percentage: globalPct,
		},
		Categories:       categories,
		UnallocatedSpent: totalSpent - allocatedSpent,
	}, nil
}

// ── Notification check (runs async) ──────────────────────────

func (s *Service) checkAndNotify(ctx context.Context, userID uuid.UUID, categoryID uuid.UUID) {
	budget, err := s.q.GetBudgetByUserID(ctx, pgUUID(userID))
	if err != nil {
		return
	}
	start, end := getCurrentCycle(budget.CycleStartDay, time.Now())
	budgetUUID := uuid.UUID(budget.ID.Bytes)

	// Get allocation for this category
	allocRow, err := s.q.GetAllocationByCategoryAndBudget(ctx, sqlc.GetAllocationByCategoryAndBudgetParams{
		BudgetID:   pgUUID(budgetUUID),
		CategoryID: pgUUID(categoryID),
	})
	if err != nil {
		return // no allocation for this category
	}
	allocated := numericToFloat(allocRow)

	if allocated <= 0 {
		return
	}

	// Get spent for this category in this cycle
	spentRow, err := s.q.SumExpensesByCategoryID(ctx, sqlc.SumExpensesByCategoryIDParams{
		UserID:        pgUUID(userID),
		CategoryID:    pgUUID(categoryID),
		ExpenseDate:   pgDate(start),
		ExpenseDate_2: pgDate(end),
	})
	if err != nil {
		return
	}
	spent := numericToFloat(spentRow)
	pct := (spent / allocated) * 100

	cat, err := s.q.GetBudgetCategoryByID(ctx, sqlc.GetBudgetCategoryByIDParams{
		ID:     pgUUID(categoryID),
		UserID: pgUUID(userID),
	})
	if err != nil {
		return
	}

	cycleStartDate := pgDate(start)

	// Check 100% first (so both can fire if crossing both in one expense)
	for _, threshold := range []int16{100, 80} {
		if (threshold == 100 && pct >= 100) || (threshold == 80 && pct >= 80) {
			sent, err := s.q.CheckNotificationSent(ctx, sqlc.CheckNotificationSentParams{
				UserID:     pgUUID(userID),
				CategoryID: pgUUID(categoryID),
				CycleStart: cycleStartDate,
				Threshold:  threshold,
			})
			if err != nil || sent {
				continue
			}
			// Send push
			var title, body string
			if threshold == 100 {
				title = "🚨 Presupuesto"
				body = fmt.Sprintf("%s %s: superaste tu presupuesto", cat.Emoji, cat.Name)
			} else {
				title = "⚠️ Presupuesto"
				body = fmt.Sprintf("%s %s: llevas el 80%% de tu presupuesto", cat.Emoji, cat.Name)
			}
			if s.fcm != nil {
				devices, err := s.q.ListDevicesByUser(ctx, pgUUID(userID))
				if err == nil {
					for _, d := range devices {
						_ = s.fcm.Send(ctx, d.FcmToken, title, body)
					}
				}
			}
			_ = s.q.InsertNotification(ctx, sqlc.InsertNotificationParams{
				UserID:     pgUUID(userID),
				CategoryID: pgUUID(categoryID),
				CycleStart: cycleStartDate,
				Threshold:  threshold,
			})
		}
	}
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/gustavo/Desktop/numia-api && go build ./...`

- [ ] **Step 3: Commit**

```bash
git add internal/budget/service.go
git commit -m "feat: add expense CRUD, summary aggregation, and notification trigger to budget service"
```

---

### Task 6: FCM Client + Device Package

**Files:**
- Create: `numia-api/internal/budget/fcm.go`
- Create: `numia-api/internal/device/service.go`
- Create: `numia-api/internal/device/handler.go`
- Modify: `numia-api/internal/config/config.go`

- [ ] **Step 1: Create fcm.go**

```go
package budget

import (
	"context"
	"log"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

type FCMClient struct {
	client *messaging.Client
}

func NewFCMClient(credentialsPath string) *FCMClient {
	if credentialsPath == "" {
		log.Println("FCM: no credentials path, notifications disabled")
		return nil
	}
	opt := option.WithCredentialsFile(credentialsPath)
	app, err := firebase.NewApp(context.Background(), nil, opt)
	if err != nil {
		log.Printf("FCM: failed to init app: %v", err)
		return nil
	}
	client, err := app.Messaging(context.Background())
	if err != nil {
		log.Printf("FCM: failed to init messaging: %v", err)
		return nil
	}
	return &FCMClient{client: client}
}

func (f *FCMClient) Send(ctx context.Context, token, title, body string) error {
	if f == nil || f.client == nil {
		return nil
	}
	msg := &messaging.Message{
		Token: token,
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
	}
	_, err := f.client.Send(ctx, msg)
	if err != nil {
		log.Printf("FCM: send error to %s: %v", token[:20], err)
	}
	return err
}
```

- [ ] **Step 2: Create device/service.go**

```go
package device

import (
	"context"

	"numia-api/internal/database/sqlc"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

type RegisterRequest struct {
	FCMToken string `json:"fcm_token" binding:"required"`
	Platform string `json:"platform" binding:"required"`
}

type DeleteRequest struct {
	FCMToken string `json:"fcm_token" binding:"required"`
}

type Service struct {
	q *sqlc.Queries
}

func NewService(q *sqlc.Queries) *Service {
	return &Service{q: q}
}

func (s *Service) Register(ctx context.Context, userID uuid.UUID, req RegisterRequest) error {
	return s.q.UpsertDevice(ctx, sqlc.UpsertDeviceParams{
		UserID:   pgtype.UUID{Bytes: userID, Valid: true},
		FcmToken: req.FCMToken,
		Platform: req.Platform,
	})
}

func (s *Service) Remove(ctx context.Context, fcmToken string) error {
	return s.q.DeleteDevice(ctx, fcmToken)
}
```

- [ ] **Step 3: Create device/handler.go**

```go
package device

import (
	"net/http"

	"numia-api/internal/middleware"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	s *Service
}

func NewHandler(s *Service) *Handler {
	return &Handler{s: s}
}

func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	g := rg.Group("/devices")
	g.POST("", h.register)
	g.DELETE("", h.remove)
}

func (h *Handler) register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	if err := h.s.Register(c.Request.Context(), userID, req); err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to register device")
		return
	}
	c.Status(http.StatusCreated)
}

func (h *Handler) remove(c *gin.Context) {
	var req DeleteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	if err := h.s.Remove(c.Request.Context(), req.FCMToken); err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to remove device")
		return
	}
	c.Status(http.StatusNoContent)
}
```

- [ ] **Step 4: Update config.go to add FirebaseCredentialsPath**

In `internal/config/config.go`, add to the Config struct:

```go
type Config struct {
	DBURL                   string
	JWTSecret               string
	GroqAPIKey              string
	Port                    string
	GinMode                 string
	FirebaseCredentialsPath string
}
```

And in `Load()`, add:

```go
FirebaseCredentialsPath: os.Getenv("FIREBASE_CREDENTIALS_PATH"),
```

- [ ] **Step 5: Add firebase dependency**

Run: `cd /Users/gustavo/Desktop/numia-api && go get firebase.google.com/go/v4 && go get google.golang.org/api/option`

- [ ] **Step 6: Verify everything compiles**

Run: `cd /Users/gustavo/Desktop/numia-api && go build ./...`

- [ ] **Step 7: Commit**

```bash
git add internal/budget/fcm.go internal/device/ internal/config/config.go go.mod go.sum
git commit -m "feat: add FCM client, device package, and Firebase config"
```

---

### Task 7: Budget Handler + Wire to Main

**Files:**
- Create: `numia-api/internal/budget/handler.go`
- Modify: `numia-api/cmd/api/main.go`

- [ ] **Step 1: Create budget/handler.go**

```go
package budget

import (
	"net/http"

	"numia-api/internal/middleware"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type Handler struct {
	s *Service
}

func NewHandler(s *Service) *Handler {
	return &Handler{s: s}
}

func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	g := rg.Group("/budget")

	// Categories
	g.GET("/categories", h.listCategories)
	g.POST("/categories", h.createCategory)
	g.DELETE("/categories/:id", h.deleteCategory)

	// Budget
	g.GET("", h.getBudget)
	g.POST("", h.createOrUpdateBudget)
	g.PUT("/allocations", h.setAllocations)

	// Expenses
	g.GET("/expenses", h.listExpenses)
	g.POST("/expenses", h.createExpense)
	g.DELETE("/expenses/:id", h.deleteExpense)

	// Summary
	g.GET("/summary", h.getSummary)
}

// ── Categories ───────────────────────────────────────────────

func (h *Handler) listCategories(c *gin.Context) {
	userID := middleware.GetUserID(c)
	cats, err := h.s.ListCategories(c.Request.Context(), userID)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to list categories")
		return
	}
	c.JSON(http.StatusOK, cats)
}

func (h *Handler) createCategory(c *gin.Context) {
	var req CreateCategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	cat, err := h.s.CreateCategory(c.Request.Context(), userID, req)
	if err != nil {
		middleware.RespondError(c, http.StatusConflict, "DUPLICATE_CATEGORY", err.Error())
		return
	}
	c.JSON(http.StatusCreated, cat)
}

func (h *Handler) deleteCategory(c *gin.Context) {
	catID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "INVALID_ID", "invalid category id")
		return
	}
	userID := middleware.GetUserID(c)
	if err := h.s.DeleteCategory(c.Request.Context(), userID, catID); err != nil {
		middleware.RespondError(c, http.StatusForbidden, "FORBIDDEN", err.Error())
		return
	}
	c.Status(http.StatusNoContent)
}

// ── Budget ───────────────────────────────────────────────────

func (h *Handler) getBudget(c *gin.Context) {
	userID := middleware.GetUserID(c)
	budget, err := h.s.GetBudget(c.Request.Context(), userID)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
		return
	}
	if budget == nil {
		c.JSON(http.StatusOK, nil)
		return
	}
	c.JSON(http.StatusOK, budget)
}

func (h *Handler) createOrUpdateBudget(c *gin.Context) {
	var req CreateBudgetRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	budget, err := h.s.CreateOrUpdateBudget(c.Request.Context(), userID, req)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
		return
	}
	c.JSON(http.StatusOK, budget)
}

func (h *Handler) setAllocations(c *gin.Context) {
	var req AllocationsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	allocs, err := h.s.SetAllocations(c.Request.Context(), userID, req)
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "ALLOCATION_ERROR", err.Error())
		return
	}
	c.JSON(http.StatusOK, allocs)
}

// ── Expenses ─────────────────────────────────────────────────

func (h *Handler) listExpenses(c *gin.Context) {
	userID := middleware.GetUserID(c)
	expenses, err := h.s.ListExpenses(c.Request.Context(), userID)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
		return
	}
	c.JSON(http.StatusOK, expenses)
}

func (h *Handler) createExpense(c *gin.Context) {
	var req CreateExpenseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	resp, err := h.s.CreateExpense(c.Request.Context(), userID, req)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
		return
	}
	c.JSON(http.StatusCreated, resp)
}

func (h *Handler) deleteExpense(c *gin.Context) {
	expID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "INVALID_ID", "invalid expense id")
		return
	}
	userID := middleware.GetUserID(c)
	if err := h.s.DeleteExpense(c.Request.Context(), userID, expID); err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to delete expense")
		return
	}
	c.Status(http.StatusNoContent)
}

// ── Summary ──────────────────────────────────────────────────

func (h *Handler) getSummary(c *gin.Context) {
	userID := middleware.GetUserID(c)
	summary, err := h.s.GetSummary(c.Request.Context(), userID)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
		return
	}
	c.JSON(http.StatusOK, summary)
}
```

- [ ] **Step 2: Update main.go to wire budget and device modules**

Add imports for `"numia-api/internal/budget"` and `"numia-api/internal/device"`, then add after the coach section:

```go
	// Budget
	fcmClient := budget.NewFCMClient(cfg.FirebaseCredentialsPath)
	budgetService := budget.NewService(queries, fcmClient)
	budgetHandler := budget.NewHandler(budgetService)
	budgetHandler.RegisterRoutes(protected)

	// Devices
	deviceService := device.NewService(queries)
	deviceHandler := device.NewHandler(deviceService)
	deviceHandler.RegisterRoutes(protected)
```

- [ ] **Step 3: Verify build**

Run: `cd /Users/gustavo/Desktop/numia-api && go build ./...`

- [ ] **Step 4: Rebuild Docker image and test health**

Run: `cd /Users/gustavo/Desktop/numia-api && docker compose up -d --build api`
Run: `curl http://localhost:8080/api/v1/health`
Expected: `{"db":"connected","status":"ok"}`

- [ ] **Step 5: Commit**

```bash
git add internal/budget/handler.go cmd/api/main.go
git commit -m "feat: add budget handler and wire budget+device modules to main"
```

---

### Task 8: Flutter Domain Models

**Files:**
- Create: `numia/lib/features/budget/domain/budget_category.dart`
- Create: `numia/lib/features/budget/domain/budget.dart`
- Create: `numia/lib/features/budget/domain/expense.dart`
- Create: `numia/lib/features/budget/domain/budget_summary.dart`

- [ ] **Step 1: Create budget_category.dart**

```dart
import 'package:equatable/equatable.dart';

class BudgetCategory extends Equatable {
  final String id;
  final String name;
  final String emoji;
  final bool isCustom;
  final bool isActive;

  const BudgetCategory({
    required this.id,
    required this.name,
    required this.emoji,
    this.isCustom = false,
    this.isActive = true,
  });

  factory BudgetCategory.fromJson(Map<String, dynamic> json) {
    return BudgetCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      isCustom: json['is_custom'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [id, name, emoji];
}
```

- [ ] **Step 2: Create budget.dart**

```dart
import 'package:equatable/equatable.dart';
import '../../../core/json_helpers.dart';

class BudgetAllocation extends Equatable {
  final String id;
  final String categoryId;
  final String categoryName;
  final String categoryEmoji;
  final double amount;

  const BudgetAllocation({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.categoryEmoji,
    required this.amount,
  });

  factory BudgetAllocation.fromJson(Map<String, dynamic> json) {
    return BudgetAllocation(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String,
      categoryEmoji: json['category_emoji'] as String,
      amount: toDouble(json['amount']),
    );
  }

  @override
  List<Object?> get props => [id, categoryId];
}

class Budget extends Equatable {
  final String id;
  final double globalAmount;
  final int cycleStartDay;
  final List<BudgetAllocation> allocations;

  const Budget({
    required this.id,
    required this.globalAmount,
    required this.cycleStartDay,
    required this.allocations,
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String,
      globalAmount: toDouble(json['global_amount']),
      cycleStartDay: json['cycle_start_day'] as int,
      allocations: (json['allocations'] as List?)
              ?.map((e) => BudgetAllocation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  List<Object?> get props => [id, globalAmount, cycleStartDay];
}
```

- [ ] **Step 3: Create expense.dart**

```dart
import 'package:equatable/equatable.dart';
import '../../../core/json_helpers.dart';

class Expense extends Equatable {
  final String id;
  final String categoryId;
  final String? categoryName;
  final String? categoryEmoji;
  final double amount;
  final String? description;
  final String? subcategory;
  final DateTime expenseDate;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.categoryId,
    this.categoryName,
    this.categoryEmoji,
    required this.amount,
    this.description,
    this.subcategory,
    required this.expenseDate,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String?,
      categoryEmoji: json['category_emoji'] as String?,
      amount: toDouble(json['amount']),
      description: json['description'] as String?,
      subcategory: json['subcategory'] as String?,
      expenseDate: DateTime.parse(json['expense_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, categoryId, amount];
}
```

- [ ] **Step 4: Create budget_summary.dart**

```dart
import 'package:equatable/equatable.dart';
import '../../../core/json_helpers.dart';

class BudgetSummary extends Equatable {
  final CycleInfo cycle;
  final GlobalBudgetSummary global;
  final List<CategoryBudgetSummary> categories;
  final double unallocatedSpent;

  const BudgetSummary({
    required this.cycle,
    required this.global,
    required this.categories,
    required this.unallocatedSpent,
  });

  factory BudgetSummary.fromJson(Map<String, dynamic> json) {
    return BudgetSummary(
      cycle: CycleInfo.fromJson(json['cycle'] as Map<String, dynamic>),
      global: GlobalBudgetSummary.fromJson(json['global'] as Map<String, dynamic>),
      categories: (json['categories'] as List?)
              ?.map((e) => CategoryBudgetSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      unallocatedSpent: toDouble(json['unallocated_spent']),
    );
  }

  @override
  List<Object?> get props => [cycle, global];
}

class CycleInfo extends Equatable {
  final String start;
  final String end;

  const CycleInfo({required this.start, required this.end});

  factory CycleInfo.fromJson(Map<String, dynamic> json) {
    return CycleInfo(
      start: json['start'] as String,
      end: json['end'] as String,
    );
  }

  int get remainingDays {
    final endDate = DateTime.parse(end);
    return endDate.difference(DateTime.now()).inDays.clamp(0, 999);
  }

  @override
  List<Object?> get props => [start, end];
}

class GlobalBudgetSummary extends Equatable {
  final double budgeted;
  final double spent;
  final double percentage;

  const GlobalBudgetSummary({
    required this.budgeted,
    required this.spent,
    required this.percentage,
  });

  factory GlobalBudgetSummary.fromJson(Map<String, dynamic> json) {
    return GlobalBudgetSummary(
      budgeted: toDouble(json['budgeted']),
      spent: toDouble(json['spent']),
      percentage: toDouble(json['percentage']),
    );
  }

  @override
  List<Object?> get props => [budgeted, spent, percentage];
}

class CategoryBudgetSummary extends Equatable {
  final String categoryId;
  final String name;
  final String emoji;
  final double budgeted;
  final double spent;
  final double percentage;

  const CategoryBudgetSummary({
    required this.categoryId,
    required this.name,
    required this.emoji,
    required this.budgeted,
    required this.spent,
    required this.percentage,
  });

  factory CategoryBudgetSummary.fromJson(Map<String, dynamic> json) {
    return CategoryBudgetSummary(
      categoryId: json['category_id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      budgeted: toDouble(json['budgeted']),
      spent: toDouble(json['spent']),
      percentage: toDouble(json['percentage']),
    );
  }

  @override
  List<Object?> get props => [categoryId, name, budgeted, spent];
}
```

- [ ] **Step 5: Verify flutter analyze**

Run: `cd /Users/gustavo/Desktop/numia && flutter analyze`
Expected: No issues found.

- [ ] **Step 6: Commit**

```bash
git add lib/features/budget/domain/
git commit -m "feat: add Flutter domain models for budget, categories, expenses, and summary"
```

---

### Task 9: Flutter Budget Repository + Providers

**Files:**
- Create: `numia/lib/features/budget/data/budget_repository.dart`
- Modify: `numia/lib/core/providers.dart`

- [ ] **Step 1: Create budget_repository.dart**

```dart
import '../../../core/api_client.dart';
import '../domain/budget.dart';
import '../domain/budget_category.dart';
import '../domain/budget_summary.dart';
import '../domain/expense.dart';

class BudgetRepository {
  BudgetRepository(this._client);
  final ApiClient _client;

  // ── Categories ──────────────────────────────────────────────

  Future<List<BudgetCategory>> getCategories() async {
    final response = await _client.dio.get('/api/v1/budget/categories');
    final data = response.data as List;
    return data
        .map((e) => BudgetCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BudgetCategory> createCategory({
    required String name,
    required String emoji,
  }) async {
    final response = await _client.dio.post('/api/v1/budget/categories', data: {
      'name': name,
      'emoji': emoji,
    });
    return BudgetCategory.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteCategory(String id) async {
    await _client.dio.delete('/api/v1/budget/categories/$id');
  }

  // ── Budget ──────────────────────────────────────────────────

  Future<Budget?> getBudget() async {
    final response = await _client.dio.get('/api/v1/budget');
    if (response.data == null) return null;
    return Budget.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Budget> createOrUpdateBudget({
    required double globalAmount,
    required int cycleStartDay,
  }) async {
    final response = await _client.dio.post('/api/v1/budget', data: {
      'global_amount': globalAmount,
      'cycle_start_day': cycleStartDay,
    });
    return Budget.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> setAllocations(
      List<Map<String, dynamic>> allocations) async {
    await _client.dio.put('/api/v1/budget/allocations', data: {
      'allocations': allocations,
    });
  }

  // ── Expenses ────────────────────────────────────────────────

  Future<List<Expense>> getExpenses() async {
    final response = await _client.dio.get('/api/v1/budget/expenses');
    final data = response.data as List;
    return data
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createExpense({
    required String categoryId,
    required double amount,
    required String expenseDate,
    String? description,
    String? subcategory,
  }) async {
    await _client.dio.post('/api/v1/budget/expenses', data: {
      'category_id': categoryId,
      'amount': amount,
      'expense_date': expenseDate,
      if (description != null) 'description': description,
      if (subcategory != null) 'subcategory': subcategory,
    });
  }

  Future<void> deleteExpense(String id) async {
    await _client.dio.delete('/api/v1/budget/expenses/$id');
  }

  // ── Summary ─────────────────────────────────────────────────

  Future<BudgetSummary> getSummary() async {
    final response = await _client.dio.get('/api/v1/budget/summary');
    return BudgetSummary.fromJson(response.data as Map<String, dynamic>);
  }

  // ── Devices ─────────────────────────────────────────────────

  Future<void> registerDevice({
    required String fcmToken,
    required String platform,
  }) async {
    await _client.dio.post('/api/v1/devices', data: {
      'fcm_token': fcmToken,
      'platform': platform,
    });
  }

  Future<void> removeDevice(String fcmToken) async {
    await _client.dio.delete('/api/v1/devices', data: {
      'fcm_token': fcmToken,
    });
  }
}
```

- [ ] **Step 2: Add budget providers to providers.dart**

Add imports at the top of `lib/core/providers.dart`:

```dart
import '../features/budget/data/budget_repository.dart';
import '../features/budget/domain/budget.dart';
import '../features/budget/domain/budget_summary.dart';
```

Add after the `conversationRepositoryProvider`:

```dart
final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(apiClientProvider)),
);
```

Add after `goalsProvider`:

```dart
final budgetProvider = FutureProvider<Budget?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(budgetRepositoryProvider).getBudget();
});

final budgetSummaryProvider = FutureProvider<BudgetSummary?>((ref) async {
  ref.watch(authStateProvider);
  try {
    return await ref.watch(budgetRepositoryProvider).getSummary();
  } catch (_) {
    return null;
  }
});
```

- [ ] **Step 3: Verify flutter analyze**

Run: `cd /Users/gustavo/Desktop/numia && flutter analyze`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/features/budget/data/budget_repository.dart lib/core/providers.dart
git commit -m "feat: add budget repository and providers"
```

---

### Task 10: Flutter Bottom Nav + Router Update

**Files:**
- Modify: `numia/lib/shared/widgets/n_bottom_nav.dart`
- Modify: `numia/lib/app/router.dart`
- Modify: `numia/lib/core/providers.dart` (add import)

- [ ] **Step 1: Update n_bottom_nav.dart — add Presupuesto tab**

Replace the `_items` list (insert new item at index 1):

```dart
  static const _items = [
    (icon: Icons.home_outlined,          activeIcon: Icons.home_rounded,          label: 'Inicio'),
    (icon: Icons.pie_chart_outline_rounded, activeIcon: Icons.pie_chart_rounded,  label: 'Presupuesto'),
    (icon: Icons.swap_horiz_rounded,     activeIcon: Icons.swap_horiz_rounded,    label: 'Movimientos'),
    (icon: Icons.auto_awesome_outlined,  activeIcon: Icons.auto_awesome,          label: 'IA'),
    (icon: Icons.adjust_rounded,         activeIcon: Icons.adjust_rounded,        label: 'Metas'),
    (icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded,        label: 'Perfil'),
  ];
```

Update the `isAI` check from `i == 2` to `i == 3`:

```dart
final isAI = i == 3;
```

- [ ] **Step 2: Update router.dart — add /budget route**

In `AppShell`, update `_routes`:

```dart
static const _routes = ['/', '/budget', '/transactions', '/coach', '/goals', '/profile'];
```

In the `routerProvider` ShellRoute routes, add after the `/` route:

```dart
GoRoute(path: '/budget', builder: (_, __) => const BudgetScreen()),
```

Add import at the top:

```dart
import '../features/budget/presentation/budget_screen.dart';
```

- [ ] **Step 3: Create minimal budget_screen.dart placeholder**

Create `lib/features/budget/presentation/budget_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/widgets/n_gradient_bg.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ct = NColorTheme.of(context);
    return Scaffold(
      backgroundColor: ct.bg,
      body: NGradientBg(
        child: Center(
          child: Text(
            'Presupuesto',
            style: NTypography.h2.copyWith(color: ct.textPrimary),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Verify flutter analyze**

Run: `cd /Users/gustavo/Desktop/numia && flutter analyze`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/n_bottom_nav.dart lib/app/router.dart lib/features/budget/presentation/budget_screen.dart lib/core/providers.dart
git commit -m "feat: add Presupuesto tab to bottom nav and wire budget route"
```

---

### Task 11: Flutter Budget Screen (Empty + Active States)

**Files:**
- Modify: `numia/lib/features/budget/presentation/budget_screen.dart`

- [ ] **Step 1: Implement full budget screen**

Replace the placeholder with the full implementation. The screen should:
- Watch `budgetSummaryProvider` for data
- Show empty state when no budget configured (illustration, title, CTA button)
- Show active state with: cycle info bar, circular progress ring, category list with progress bars
- FAB to add expense
- Settings icon to edit budget
- Tap category to navigate to detail

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../../core/providers.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/widgets/n_glass_card.dart';
import '../../../shared/widgets/n_gradient_bg.dart';
import '../domain/budget_summary.dart';
import 'budget_setup_screen.dart';
import 'add_expense_sheet.dart';
import 'category_detail_screen.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ct = NColorTheme.of(context);
    final summaryAsync = ref.watch(budgetSummaryProvider);

    return Scaffold(
      backgroundColor: ct.bg,
      body: NGradientBg(
        child: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _EmptyBudgetState(),
          data: (summary) =>
              summary == null ? _EmptyBudgetState() : _ActiveBudgetState(summary: summary),
        ),
      ),
      floatingActionButton: summaryAsync.valueOrNull != null
          ? FloatingActionButton(
              onPressed: () => _showAddExpense(context, ref),
              backgroundColor: NColors.indigo,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  void _showAddExpense(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddExpenseSheet(),
    ).then((_) => ref.invalidate(budgetSummaryProvider));
  }
}

class _EmptyBudgetState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                gradient: NColors.grad,
                shape: BoxShape.circle,
                boxShadow: [NColors.glowIndigo],
              ),
              child: const Icon(Icons.pie_chart_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: NSpacing.sp6),
            Text(
              'Configura tu presupuesto',
              style: NTypography.h2.copyWith(color: ct.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: NSpacing.sp2),
            Text(
              'Define un presupuesto mensual y distribuye\ntu dinero por categorías',
              style: NTypography.body.copyWith(color: ct.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: NSpacing.sp8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: NColors.grad,
                  borderRadius: BorderRadius.all(Radius.circular(NSpacing.rMd)),
                  boxShadow: [NColors.glowIndigo],
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BudgetSetupScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(NSpacing.rMd),
                    ),
                  ),
                  child: Text('Comenzar', style: NTypography.button.copyWith(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveBudgetState extends StatelessWidget {
  const _ActiveBudgetState({required this.summary});
  final BudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final sorted = List<CategoryBudgetSummary>.from(summary.categories)
      ..sort((a, b) => b.percentage.compareTo(a.percentage));

    return CustomScrollView(
      slivers: [
        SliverSafeArea(
          bottom: false,
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                NSpacing.pageH, NSpacing.sp3, NSpacing.pageH, 0,
              ),
              child: Row(
                children: [
                  Text('Presupuesto', style: NTypography.title.copyWith(color: ct.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BudgetSetupScreen(isEdit: true)),
                    ),
                    child: Icon(Icons.settings_outlined, color: ct.textSecondary, size: 22),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Cycle info
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(NSpacing.pageH, NSpacing.sp3, NSpacing.pageH, 0),
            child: NGlassCard(
              padding: const EdgeInsets.all(NSpacing.sp4),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 16, color: ct.textSecondary),
                  const SizedBox(width: NSpacing.sp2),
                  Text(
                    '${_formatDate(summary.cycle.start)} — ${_formatDate(summary.cycle.end)}',
                    style: NTypography.caption.copyWith(color: ct.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    '${summary.cycle.remainingDays} días restantes',
                    style: NTypography.caption.copyWith(color: ct.accent1),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Global progress ring
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(NSpacing.pageH, NSpacing.sp4, NSpacing.pageH, 0),
            child: NGlassCard(
              variant: NGlassVariant.featured,
              child: Column(
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CustomPaint(
                      painter: _RingPainter(
                        percentage: summary.global.percentage.clamp(0, 100) / 100,
                        color: _colorForPercent(summary.global.percentage),
                        bgColor: ct.surface3,
                      ),
                      child: Center(
                        child: Text(
                          '${summary.global.percentage.toStringAsFixed(0)}%',
                          style: NTypography.numericMd.copyWith(color: ct.textPrimary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: NSpacing.sp3),
                  Text(
                    '\$${_fmt(summary.global.spent)} / \$${_fmt(summary.global.budgeted)}',
                    style: NTypography.body.copyWith(color: ct.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Category list
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(NSpacing.pageH, NSpacing.sp4, NSpacing.pageH, 100),
          sliver: SliverList.builder(
            itemCount: sorted.length,
            itemBuilder: (context, i) {
              final cat = sorted[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: NSpacing.sp3),
                child: NGlassCard(
                  padding: const EdgeInsets.all(NSpacing.sp4),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CategoryDetailScreen(
                        categoryId: cat.categoryId,
                        categoryName: cat.name,
                        categoryEmoji: cat.emoji,
                        budgeted: cat.budgeted,
                        spent: cat.spent,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: NSpacing.sp2),
                          Expanded(
                            child: Text(
                              cat.name,
                              style: NTypography.caption.copyWith(
                                color: ct.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '\$${_fmt(cat.spent)} / \$${_fmt(cat.budgeted)}',
                            style: NTypography.caption.copyWith(color: ct.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: NSpacing.sp2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (cat.percentage / 100).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: ct.surface3,
                          valueColor: AlwaysStoppedAnimation(_colorForPercent(cat.percentage)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static Color _colorForPercent(double pct) {
    if (pct > 100) return NColors.error;
    if (pct >= 80) return NColors.amber;
    if (pct >= 60) return NColors.amberLight;
    return NColors.emerald;
  }

  static String _fmt(double v) => NumberFormat('#,##0', 'es_MX').format(v);

  static String _formatDate(String iso) {
    final d = DateTime.parse(iso);
    return DateFormat('d MMM', 'es').format(d);
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.percentage, required this.color, required this.bgColor});
  final double percentage;
  final Color color;
  final Color bgColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final strokeWidth = 10.0;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * percentage,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.percentage != percentage || old.color != color;
}
```

- [ ] **Step 2: Verify flutter analyze**

Run: `cd /Users/gustavo/Desktop/numia && flutter analyze`

- [ ] **Step 3: Commit**

```bash
git add lib/features/budget/presentation/budget_screen.dart
git commit -m "feat: implement budget screen with empty and active states"
```

---

### Task 12: Flutter Budget Setup Screen

**Files:**
- Create: `numia/lib/features/budget/presentation/budget_setup_screen.dart`

- [ ] **Step 1: Implement 2-step budget setup wizard**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/widgets/n_glass_card.dart';
import '../../../shared/widgets/n_gradient_bg.dart';
import '../domain/budget_category.dart';
import 'package:intl/intl.dart';

class BudgetSetupScreen extends ConsumerStatefulWidget {
  const BudgetSetupScreen({super.key, this.isEdit = false});
  final bool isEdit;

  @override
  ConsumerState<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends ConsumerState<BudgetSetupScreen> {
  int _step = 0;
  final _amountCtrl = TextEditingController();
  int _cycleDay = 1;
  bool _loading = false;
  String? _budgetId;

  List<BudgetCategory> _categories = [];
  final Map<String, TextEditingController> _allocCtrls = {};

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final repo = ref.read(budgetRepositoryProvider);
    try {
      final budget = await repo.getBudget();
      if (budget != null && widget.isEdit) {
        _amountCtrl.text = budget.globalAmount.toStringAsFixed(0);
        _cycleDay = budget.cycleStartDay;
        _budgetId = budget.id;
        for (final a in budget.allocations) {
          _allocCtrls[a.categoryId] = TextEditingController(
            text: a.amount > 0 ? a.amount.toStringAsFixed(0) : '',
          );
        }
      }
      final cats = await repo.getCategories();
      if (mounted) {
        setState(() {
          _categories = cats.where((c) => c.isActive).toList();
          for (final c in _categories) {
            _allocCtrls.putIfAbsent(c.id, () => TextEditingController());
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    for (final c in _allocCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _totalAllocated {
    double sum = 0;
    for (final ctrl in _allocCtrls.values) {
      sum += double.tryParse(ctrl.text) ?? 0;
    }
    return sum;
  }

  double get _globalAmount => double.tryParse(_amountCtrl.text) ?? 0;

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(budgetRepositoryProvider);
      await repo.createOrUpdateBudget(
        globalAmount: _globalAmount,
        cycleStartDay: _cycleDay,
      );
      // Build allocations list
      final allocs = <Map<String, dynamic>>[];
      for (final entry in _allocCtrls.entries) {
        final amt = double.tryParse(entry.value.text) ?? 0;
        if (amt > 0) {
          allocs.add({'category_id': entry.key, 'amount': amt});
        }
      }
      if (allocs.isNotEmpty) {
        await repo.setAllocations(allocs);
      }
      ref.invalidate(budgetSummaryProvider);
      ref.invalidate(budgetProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    return Scaffold(
      backgroundColor: ct.bg,
      body: NGradientBg(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(NSpacing.sp4, NSpacing.sp3, NSpacing.pageH, NSpacing.sp3),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: ct.textPrimary),
                      onPressed: () {
                        if (_step == 1) {
                          setState(() => _step = 0);
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    Text(
                      _step == 0 ? 'Presupuesto mensual' : 'Asignar por categoría',
                      style: NTypography.title.copyWith(color: ct.textPrimary),
                    ),
                  ],
                ),
              ),
              Expanded(child: _step == 0 ? _buildStep1(ct) : _buildStep2(ct)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(NColorTheme ct) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: NSpacing.sp6),
          Text('Monto global mensual', style: NTypography.caption.copyWith(color: ct.textSecondary)),
          const SizedBox(height: NSpacing.sp2),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            style: NTypography.numericMd.copyWith(color: ct.textPrimary),
            decoration: InputDecoration(
              prefixText: '\$ ',
              prefixStyle: NTypography.numericMd.copyWith(color: ct.textSecondary),
              filled: true,
              fillColor: ct.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(NSpacing.rMd),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: NSpacing.sp6),
          Text('Día de inicio del ciclo', style: NTypography.caption.copyWith(color: ct.textSecondary)),
          const SizedBox(height: NSpacing.sp2),
          NGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: NSpacing.sp4, vertical: NSpacing.sp2),
            child: Row(
              children: [
                Text('Día $_cycleDay de cada mes',
                    style: NTypography.body.copyWith(color: ct.textPrimary)),
                const Spacer(),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline, color: ct.textSecondary),
                      onPressed: _cycleDay > 1 ? () => setState(() => _cycleDay--) : null,
                    ),
                    Text('$_cycleDay',
                        style: NTypography.title.copyWith(color: ct.accent1)),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline, color: ct.textSecondary),
                      onPressed: _cycleDay < 28 ? () => setState(() => _cycleDay++) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _globalAmount > 0 ? NColors.grad : null,
                color: _globalAmount > 0 ? null : ct.surface3,
                borderRadius: BorderRadius.circular(NSpacing.rMd),
              ),
              child: ElevatedButton(
                onPressed: _globalAmount > 0 ? () => setState(() => _step = 1) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(NSpacing.rMd),
                  ),
                ),
                child: Text('Siguiente', style: NTypography.button.copyWith(color: Colors.white)),
              ),
            ),
          ),
          const SizedBox(height: NSpacing.sp6),
        ],
      ),
    );
  }

  Widget _buildStep2(NColorTheme ct) {
    final remaining = _globalAmount - _totalAllocated;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
            itemCount: _categories.length,
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final ctrl = _allocCtrls[cat.id]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: NSpacing.sp3),
                child: Row(
                  children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: NSpacing.sp3),
                    Expanded(
                      flex: 2,
                      child: Text(cat.name,
                          style: NTypography.body.copyWith(color: ct.textPrimary)),
                    ),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.plusJakartaSans(
                          color: ct.textPrimary,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          prefixStyle: GoogleFonts.plusJakartaSans(
                            color: ct.textSecondary,
                            fontSize: 15,
                          ),
                          filled: true,
                          fillColor: ct.surface2,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: NSpacing.sp3,
                            vertical: NSpacing.sp2,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(NSpacing.rSm),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Bottom bar
        Container(
          padding: const EdgeInsets.fromLTRB(NSpacing.pageH, NSpacing.sp3, NSpacing.pageH, NSpacing.sp6),
          decoration: BoxDecoration(
            color: ct.surface1,
            border: Border(top: BorderSide(color: ct.borderSubtle)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Asignado', style: NTypography.caption.copyWith(color: ct.textSecondary)),
                  Text(
                    '\$${NumberFormat('#,##0', 'es_MX').format(_totalAllocated)} / \$${NumberFormat('#,##0', 'es_MX').format(_globalAmount)}',
                    style: NTypography.caption.copyWith(
                      color: remaining < 0 ? NColors.error : ct.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (remaining > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Sin asignar: \$${NumberFormat('#,##0', 'es_MX').format(remaining)}',
                    style: NTypography.caption.copyWith(color: ct.accent2),
                  ),
                ),
              const SizedBox(height: NSpacing.sp3),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: remaining >= 0 && !_loading ? NColors.grad : null,
                    color: remaining >= 0 && !_loading ? null : ct.surface3,
                    borderRadius: BorderRadius.circular(NSpacing.rMd),
                  ),
                  child: ElevatedButton(
                    onPressed: remaining >= 0 && !_loading ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(NSpacing.rMd),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Guardar', style: NTypography.button.copyWith(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify flutter analyze**

Run: `cd /Users/gustavo/Desktop/numia && flutter analyze`

- [ ] **Step 3: Commit**

```bash
git add lib/features/budget/presentation/budget_setup_screen.dart
git commit -m "feat: implement budget setup screen with 2-step wizard"
```

---

### Task 13: Flutter Add Expense Bottom Sheet

**Files:**
- Create: `numia/lib/features/budget/presentation/add_expense_sheet.dart`

- [ ] **Step 1: Implement add expense bottom sheet**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/providers.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../domain/budget_category.dart';

class AddExpenseSheet extends ConsumerStatefulWidget {
  const AddExpenseSheet({super.key});

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<AddExpenseSheet> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _subCatCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;
  List<BudgetCategory> _categories = [];
  bool _loading = false;
  bool _categoriesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ref.read(budgetRepositoryProvider).getCategories();
      if (mounted) {
        setState(() {
          _categories = cats.where((c) => c.isActive).toList();
          _categoriesLoaded = true;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _subCatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedCategoryId == null || _amountCtrl.text.isEmpty) return;
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) return;

    setState(() => _loading = true);
    try {
      await ref.read(budgetRepositoryProvider).createExpense(
            categoryId: _selectedCategoryId!,
            amount: amount,
            expenseDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
            description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
            subcategory: _subCatCtrl.text.isEmpty ? null : _subCatCtrl.text,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: ct.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(NSpacing.rXl)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(NSpacing.pageH, NSpacing.sp4, NSpacing.pageH, NSpacing.sp6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ct.surface3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: NSpacing.sp4),
            Text('Nuevo gasto', style: NTypography.title.copyWith(color: ct.textPrimary)),
            const SizedBox(height: NSpacing.sp4),

            // Category selector
            Text('Categoría', style: NTypography.caption.copyWith(color: ct.textSecondary)),
            const SizedBox(height: NSpacing.sp2),
            if (!_categoriesLoaded)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: NSpacing.sp2,
                runSpacing: NSpacing.sp2,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategoryId == cat.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategoryId = cat.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: NSpacing.sp3,
                        vertical: NSpacing.sp2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? NColors.indigoSoft : ct.surface2,
                        borderRadius: BorderRadius.circular(NSpacing.rSm),
                        border: Border.all(
                          color: isSelected ? NColors.indigo : ct.borderSubtle,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text(
                            cat.name,
                            style: NTypography.caption.copyWith(
                              color: isSelected ? NColors.indigo : ct.textPrimary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: NSpacing.sp4),

            // Amount
            Text('Monto', style: NTypography.caption.copyWith(color: ct.textSecondary)),
            const SizedBox(height: NSpacing.sp2),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: NTypography.numericMd.copyWith(color: ct.textPrimary),
              decoration: InputDecoration(
                prefixText: '\$ ',
                prefixStyle: NTypography.numericMd.copyWith(color: ct.textSecondary),
                filled: true,
                fillColor: ct.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(NSpacing.rMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: NSpacing.sp4),

            // Date
            Text('Fecha', style: NTypography.caption.copyWith(color: ct.textSecondary)),
            const SizedBox(height: NSpacing.sp2),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(NSpacing.sp4),
                decoration: BoxDecoration(
                  color: ct.surface2,
                  borderRadius: BorderRadius.circular(NSpacing.rMd),
                ),
                child: Text(
                  DateFormat('dd/MM/yyyy').format(_selectedDate),
                  style: NTypography.body.copyWith(color: ct.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: NSpacing.sp4),

            // Description (optional)
            TextField(
              controller: _descCtrl,
              style: GoogleFonts.plusJakartaSans(color: ct.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Descripción (opcional)',
                hintStyle: GoogleFonts.plusJakartaSans(color: ct.textTertiary, fontSize: 15),
                filled: true,
                fillColor: ct.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(NSpacing.rMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: NSpacing.sp3),

            // Subcategory (optional)
            TextField(
              controller: _subCatCtrl,
              style: GoogleFonts.plusJakartaSans(color: ct.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Subcategoría (opcional)',
                hintStyle: GoogleFonts.plusJakartaSans(color: ct.textTertiary, fontSize: 15),
                filled: true,
                fillColor: ct.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(NSpacing.rMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: NSpacing.sp6),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _selectedCategoryId != null && !_loading ? NColors.grad : null,
                  color: _selectedCategoryId != null && !_loading ? null : ct.surface3,
                  borderRadius: BorderRadius.circular(NSpacing.rMd),
                  boxShadow: _selectedCategoryId != null ? [NColors.glowIndigo] : null,
                ),
                child: ElevatedButton(
                  onPressed: _selectedCategoryId != null && !_loading ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(NSpacing.rMd),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Guardar', style: NTypography.button.copyWith(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify flutter analyze**

Run: `cd /Users/gustavo/Desktop/numia && flutter analyze`

- [ ] **Step 3: Commit**

```bash
git add lib/features/budget/presentation/add_expense_sheet.dart
git commit -m "feat: implement add expense bottom sheet"
```

---

### Task 14: Flutter Category Detail Screen

**Files:**
- Create: `numia/lib/features/budget/presentation/category_detail_screen.dart`

- [ ] **Step 1: Implement category detail screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/widgets/n_glass_card.dart';
import '../../../shared/widgets/n_gradient_bg.dart';
import '../domain/expense.dart';

class CategoryDetailScreen extends ConsumerStatefulWidget {
  const CategoryDetailScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryEmoji,
    required this.budgeted,
    required this.spent,
  });

  final String categoryId;
  final String categoryName;
  final String categoryEmoji;
  final double budgeted;
  final double spent;

  @override
  ConsumerState<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  List<Expense>? _expenses;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await ref.read(budgetRepositoryProvider).getExpenses();
      if (mounted) {
        setState(() {
          _expenses = all.where((e) => e.categoryId == widget.categoryId).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteExpense(String id) async {
    try {
      await ref.read(budgetRepositoryProvider).deleteExpense(id);
      setState(() => _expenses?.removeWhere((e) => e.id == id));
      ref.invalidate(budgetSummaryProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final pct = widget.budgeted > 0 ? (widget.spent / widget.budgeted * 100) : 0.0;
    final color = pct > 100
        ? NColors.error
        : pct >= 80
            ? NColors.amber
            : pct >= 60
                ? NColors.amberLight
                : NColors.emerald;

    return Scaffold(
      backgroundColor: ct.bg,
      body: NGradientBg(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(NSpacing.sp4, NSpacing.sp3, NSpacing.pageH, NSpacing.sp3),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: ct.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(widget.categoryEmoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: NSpacing.sp2),
                    Text(widget.categoryName, style: NTypography.title.copyWith(color: ct.textPrimary)),
                  ],
                ),
              ),
              // Progress card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
                child: NGlassCard(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${NumberFormat('#,##0', 'es_MX').format(widget.spent)}',
                            style: NTypography.numericMd.copyWith(color: ct.textPrimary),
                          ),
                          Text(
                            '/ \$${NumberFormat('#,##0', 'es_MX').format(widget.budgeted)}',
                            style: NTypography.body.copyWith(color: ct.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: NSpacing.sp3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (pct / 100).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: ct.surface3,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                      const SizedBox(height: NSpacing.sp2),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${pct.toStringAsFixed(0)}%',
                          style: NTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: NSpacing.sp4),
              // Expense list
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _expenses == null || _expenses!.isEmpty
                        ? Center(
                            child: Text(
                              'Sin gastos en esta categoría',
                              style: NTypography.body.copyWith(color: ct.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
                            itemCount: _expenses!.length,
                            itemBuilder: (_, i) {
                              final exp = _expenses![i];
                              return Dismissible(
                                key: Key(exp.id),
                                direction: DismissDirection.endToStart,
                                onDismissed: (_) => _deleteExpense(exp.id),
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: NSpacing.sp4),
                                  color: NColors.error.withValues(alpha: 0.2),
                                  child: const Icon(Icons.delete_outline, color: NColors.error),
                                ),
                                child: NGlassCard(
                                  padding: const EdgeInsets.all(NSpacing.sp4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '\$${NumberFormat('#,##0.00', 'es_MX').format(exp.amount)}',
                                              style: NTypography.title.copyWith(color: ct.textPrimary),
                                            ),
                                            if (exp.description != null && exp.description!.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2),
                                                child: Text(
                                                  exp.description!,
                                                  style: NTypography.caption.copyWith(color: ct.textSecondary),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        DateFormat('dd MMM', 'es').format(exp.expenseDate),
                                        style: NTypography.caption.copyWith(color: ct.textTertiary),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify flutter analyze**

Run: `cd /Users/gustavo/Desktop/numia && flutter analyze`

- [ ] **Step 3: Commit**

```bash
git add lib/features/budget/presentation/category_detail_screen.dart
git commit -m "feat: implement category detail screen with swipe-to-delete"
```

---

### Task 15: Integration Test — End to End

**Files:** No new files. Manual testing.

- [ ] **Step 1: Apply migration to running DB**

Run the migration SQL against the Docker PostgreSQL container:
```bash
cd /Users/gustavo/Desktop/numia-api && docker compose exec db psql -U numia -d numia < internal/database/migrations/000002_budget_tables.up.sql
```

- [ ] **Step 2: Rebuild and restart the Go API**

```bash
cd /Users/gustavo/Desktop/numia-api && docker compose up -d --build api
```

- [ ] **Step 3: Verify API health + new endpoints**

```bash
curl http://localhost:8080/api/v1/health
```

- [ ] **Step 4: Run flutter analyze**

```bash
cd /Users/gustavo/Desktop/numia && flutter analyze
```
Expected: No issues found.

- [ ] **Step 5: Hot restart Flutter app on device**

If the app is running, press `R` for hot restart. Otherwise:
```bash
cd /Users/gustavo/Desktop/numia && flutter run
```

Verify:
1. New "Presupuesto" tab appears in bottom nav
2. Empty state shows with "Comenzar" button
3. Budget setup flow works (2 steps)
4. Budget screen shows categories with progress bars
5. FAB opens add expense sheet
6. Category detail screen shows expenses
7. Swipe to delete works

- [ ] **Step 6: Commit any final adjustments**

```bash
git add -A
git commit -m "feat: budget & expenses feature complete — integration verified"
```
