# Budget & Expenses Feature — Design Spec

## Goal

Add a budget and expense tracking system where users define a monthly global budget, distribute it across categories, register expenses, and receive push notifications when approaching or exceeding limits. Each budget cycle starts on a user-configurable day of the month.

## Architecture

The feature spans both the Go API (`numia-api`) and the Flutter app (`numia`). The backend adds 5 new tables, a new `budget` feature package, and FCM integration for push notifications. The Flutter app adds a new bottom nav tab with 4 screens.

Gastos (expenses) are independent from existing transactions — a lighter record designed for quick daily tracking against the budget.

---

## 1. Data Model

### Table: `budget_categories`

User-scoped category catalog. Seeded with predefined categories when the user creates their first budget.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | `gen_random_uuid()` |
| user_id | UUID FK → users | |
| name | VARCHAR(100) NOT NULL | |
| emoji | VARCHAR(10) NOT NULL | |
| is_custom | BOOLEAN DEFAULT FALSE | TRUE if user-created |
| is_active | BOOLEAN DEFAULT TRUE | Soft delete |
| created_at | TIMESTAMPTZ DEFAULT now() | |

Unique constraint: `(user_id, name)` — no duplicate category names per user.

**Predefined categories (12):**

| Emoji | Name |
|-------|------|
| 🍔 | Comida |
| 🚗 | Transporte |
| 🏠 | Vivienda |
| 🎬 | Entretenimiento |
| 👕 | Ropa |
| 💊 | Salud |
| 📚 | Educación |
| 💼 | Servicios |
| 🎁 | Regalos |
| 🐕 | Mascotas |
| ✈️ | Viajes |
| 📦 | Otros |

### Table: `budgets`

One active budget per user.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | `gen_random_uuid()` |
| user_id | UUID FK → users | UNIQUE (one budget per user) |
| global_amount | NUMERIC(12,2) NOT NULL | Total monthly budget |
| cycle_start_day | SMALLINT NOT NULL DEFAULT 1 | 1-28 |
| is_active | BOOLEAN DEFAULT TRUE | |
| created_at | TIMESTAMPTZ DEFAULT now() | |
| updated_at | TIMESTAMPTZ DEFAULT now() | |

Check constraint: `cycle_start_day BETWEEN 1 AND 28`.

### Table: `budget_allocations`

Per-category amount within the budget.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | `gen_random_uuid()` |
| budget_id | UUID FK → budgets | |
| category_id | UUID FK → budget_categories | |
| amount | NUMERIC(12,2) NOT NULL | |
| created_at | TIMESTAMPTZ DEFAULT now() | |
| updated_at | TIMESTAMPTZ DEFAULT now() | |

Unique constraint: `(budget_id, category_id)` — one allocation per category per budget.

Sum of allocations may be ≤ `budgets.global_amount`. Unallocated remainder is shown as "Sin asignar" in the UI.

### Table: `expenses`

Individual expense records.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | `gen_random_uuid()` |
| user_id | UUID FK → users | |
| category_id | UUID FK → budget_categories | |
| amount | NUMERIC(12,2) NOT NULL | |
| description | TEXT | Optional |
| subcategory | VARCHAR(100) | Optional |
| expense_date | DATE NOT NULL | |
| created_at | TIMESTAMPTZ DEFAULT now() | |

Index on `(user_id, expense_date)` for cycle-based queries.

### Table: `devices`

FCM token registry for push notifications.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | `gen_random_uuid()` |
| user_id | UUID FK → users | |
| fcm_token | TEXT NOT NULL UNIQUE | |
| platform | VARCHAR(10) NOT NULL | "android" or "ios" |
| created_at | TIMESTAMPTZ DEFAULT now() | |

### Table: `budget_notifications`

Tracks which threshold notifications have been sent per cycle to avoid duplicates.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | `gen_random_uuid()` |
| user_id | UUID FK → users | |
| category_id | UUID FK → budget_categories | |
| cycle_start | DATE NOT NULL | First day of the cycle when sent |
| threshold | SMALLINT NOT NULL | 80 or 100 |
| sent_at | TIMESTAMPTZ DEFAULT now() | |

Unique constraint: `(user_id, category_id, cycle_start, threshold)` — one notification per threshold per category per cycle.

---

## 2. API Endpoints

All endpoints are under the protected group (require JWT Bearer token).

### Categories

**`GET /api/v1/budget/categories`**
Returns the user's categories (predefined + custom), ordered by `is_custom ASC, name ASC`.
Response: `[{id, name, emoji, is_custom, is_active}]`

**`POST /api/v1/budget/categories`**
Create a custom category.
Request: `{name, emoji}`
Response: `201` with the created category.
Error: `409` if name already exists for user.

**`DELETE /api/v1/budget/categories/:id`**
Soft-delete (set `is_active = false`). Only allowed for `is_custom = true` categories.
Error: `403` if trying to delete a predefined category.

### Budget

**`GET /api/v1/budget`**
Returns the user's active budget with allocations.
Response: `{id, global_amount, cycle_start_day, allocations: [{id, category_id, category_name, category_emoji, amount}]}` or `null` if no budget configured.

**`POST /api/v1/budget`**
Create or update the user's budget. If no budget exists, creates one and seeds predefined categories. If a budget exists, updates `global_amount` and `cycle_start_day`.
Request: `{global_amount, cycle_start_day}`
Response: the budget object.

**`PUT /api/v1/budget/allocations`**
Bulk upsert allocations. Replaces all existing allocations.
Request: `{allocations: [{category_id, amount}]}`
Validation: sum of amounts must be ≤ budget's `global_amount`.
Response: updated list of allocations.

### Expenses

**`GET /api/v1/budget/expenses?cycle=current`**
Returns expenses for the current cycle. `cycle=current` is the default and only supported value for now.
Response: `[{id, category_id, category_name, category_emoji, amount, description, subcategory, expense_date, created_at}]`

**`POST /api/v1/budget/expenses`**
Register an expense.
Request: `{category_id, amount, description?, subcategory?, expense_date}`
Response: `201` with the created expense.
Side effect: checks if this expense pushes the category to ≥80% or ≥100% of its allocation. If so, and a notification hasn't been sent for this threshold in this cycle, sends a push notification via FCM.

**`DELETE /api/v1/budget/expenses/:id`**
Delete an expense. Only the owner can delete.
Response: `204`.

### Summary

**`GET /api/v1/budget/summary`**
Full budget summary for the current cycle.
Response:
```json
{
  "cycle": {
    "start": "2026-06-15",
    "end": "2026-07-14"
  },
  "global": {
    "budgeted": 20000.00,
    "spent": 12500.00,
    "percentage": 62.5
  },
  "categories": [
    {
      "category_id": "uuid",
      "name": "Comida",
      "emoji": "🍔",
      "budgeted": 5000.00,
      "spent": 4200.00,
      "percentage": 84.0
    }
  ],
  "unallocated_spent": 300.00
}
```

Only categories that have an allocation are included in `categories`. Expenses in categories without allocation contribute to `global.spent` and are summed in `unallocated_spent`.

### Devices

**`POST /api/v1/devices`**
Register or update FCM token.
Request: `{fcm_token, platform}`
If the token already exists for this user, it's a no-op. If it exists for another user, it gets reassigned.
Response: `201`.

**`DELETE /api/v1/devices`**
Remove the device's FCM token (on logout).
Request: `{fcm_token}`
Response: `204`.

---

## 3. Push Notifications

### Flow

1. Flutter registers FCM token on successful login → `POST /api/v1/devices`
2. On `POST /api/v1/budget/expenses`, the backend:
   a. Calculates total spent for that category in the current cycle
   b. Gets the allocation amount for that category
   c. If allocation exists and percentage ≥ 80 or ≥ 100:
      - Check `budget_notifications` if this threshold was already sent for this cycle
      - If not sent: send FCM notification and insert into `budget_notifications`
3. On logout, Flutter calls `DELETE /api/v1/devices`

### Notification Content

- **80% threshold:** Title: "⚠️ Presupuesto", Body: "{emoji} {name}: llevas el 80% de tu presupuesto"
- **100% threshold:** Title: "🚨 Presupuesto", Body: "{emoji} {name}: superaste tu presupuesto"

### Dependencies

- **Go:** `firebase.google.com/go/v4` with a service account JSON (env var `FIREBASE_CREDENTIALS_PATH`)
- **Flutter:** `firebase_messaging` package. Permission requested when user configures their first budget.

---

## 4. Flutter Screens

### Navigation Change

Bottom nav goes from 3 tabs to 4: **Dashboard, Presupuesto, Coach, Perfil**.
New tab icon: `Icons.pie_chart_rounded`.

### 4.1 Budget Screen (main tab screen)

**Empty state** (no budget configured):
- Illustration/icon, "Configura tu presupuesto" title, description, "Comenzar" button → navigates to Budget Setup.

**Active state:**
- Cycle info bar: "15 Jun — 14 Jul" with remaining days
- Circular progress ring: spent / budgeted with percentage in center
- Category list: each row shows emoji + name, horizontal progress bar (green < 60%, yellow 60-80%, orange 80-100%, red > 100%), "$spent / $budgeted" text
- Categories sorted by percentage descending (most consumed first)
- FAB button to add expense quickly
- Tap a category → Category Detail Screen
- Settings icon → Budget Setup Screen (edit mode)

### 4.2 Budget Setup Screen

**Step 1 — Global config:**
- Monto global mensual (numeric input)
- Día de inicio del ciclo (number picker 1-28)
- "Siguiente" button

**Step 2 — Category allocation:**
- List of categories with amount input field each
- Running total at bottom: "Asignado: $X / $Y" with remaining shown
- "Guardar" button (calls `POST /budget` then `PUT /budget/allocations`)

Accessible from empty state (create) and from settings icon on budget screen (edit — prefills current values).

### 4.3 Add Expense Screen (bottom sheet)

- Category selector: grid of emoji + name chips, scrollable
- Amount input with large numeric keypad feel
- Date picker (defaults to today)
- Description text field (optional)
- Subcategory text field (optional)
- "Guardar" button
- On save: if response triggers alert (category ≥80%), show inline warning banner before dismissing

### 4.4 Category Detail Screen

- Header: emoji + name, large progress bar, "$spent / $budgeted"
- List of expenses in this category for the current cycle, sorted by date descending
- Each expense row: amount, description (if any), date
- Swipe to delete an expense

---

## 5. Cycle Calculation Logic

Cycles are computed dynamically, not stored. Given `cycle_start_day` and a reference date:

```
function getCurrentCycle(cycleStartDay, referenceDate):
    if referenceDate.day >= cycleStartDay:
        cycleStart = date(referenceDate.year, referenceDate.month, cycleStartDay)
    else:
        cycleStart = date(referenceDate.year, referenceDate.month - 1, cycleStartDay)

    cycleEnd = cycleStart + 1 month - 1 day

    // Handle months where cycleStartDay > last day of month
    // Use min(cycleStartDay, lastDayOfMonth)

    return (cycleStart, cycleEnd)
```

All expense queries filter by `expense_date BETWEEN cycle_start AND cycle_end`.

---

## 6. Go Project Structure

New package: `internal/budget/`
- `model.go` — Request/response types
- `service.go` — Business logic (CRUD, cycle calculation, summary aggregation, notification trigger)
- `handler.go` — HTTP handlers
- `fcm.go` — Firebase Cloud Messaging client wrapper

New package: `internal/device/`
- `service.go` — Device token CRUD
- `handler.go` — HTTP handlers

New migration: `000002_budget_tables.up.sql` — Creates all 5 new tables with indexes and constraints.

New sqlc queries: `budget_categories.sql`, `budgets.sql`, `budget_allocations.sql`, `expenses.sql`, `devices.sql`, `budget_notifications.sql`

## 7. Flutter Project Structure

New feature: `lib/features/budget/`
- `domain/` — `budget.dart`, `budget_category.dart`, `expense.dart`, `budget_summary.dart`
- `data/` — `budget_repository.dart`
- `presentation/` — `budget_screen.dart`, `budget_setup_screen.dart`, `add_expense_sheet.dart`, `category_detail_screen.dart`

Updates:
- `lib/core/providers.dart` — Add budget providers
- `lib/app/router.dart` or `providers.dart` — Add budget route + bottom nav tab
- `lib/main.dart` — FCM initialization and token registration
