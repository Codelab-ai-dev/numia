# Numia - Session Context (2026-06-04)

## Project Overview

Numia is a personal finance Flutter app with a Go REST API backend. The app helps users track budgets, expenses, goals, debts, and provides AI coaching.

## Architecture

### Backend (numia-api)
- **Language:** Go 1.25 with Gin framework
- **Database:** PostgreSQL with SQLC for type-safe queries, pgx/v5 driver
- **Migrations:** golang-migrate (versioned SQL files in `internal/database/migrations/`)
- **Auth:** JWT (access + refresh tokens), bcrypt passwords
- **Structure:**
  - `cmd/api/main.go` — entry point, wires all modules
  - `internal/auth/` — login, register, refresh, middleware
  - `internal/budget/` — service.go, handler.go, fcm.go
  - `internal/device/` — FCM device token CRUD
  - `internal/coach/` — AI coach with SSE streaming
  - `internal/goal/`, `internal/dashboard/`, `internal/transaction/`
  - `internal/database/sqlc/` — auto-generated from `internal/database/queries/*.sql`
  - `internal/config/config.go` — env-based config
  - `internal/middleware/` — auth middleware, error helpers
- **Docker:** `docker-compose.yml` with services: db (postgres), migrate, api, caddy
- **Dockerfile:** `golang:1.25-alpine` builder → `alpine:3.20` runtime

### Frontend (numia - Flutter)
- **State management:** Riverpod (flutter_riverpod)
- **Navigation:** GoRouter with ShellRoute for bottom nav
- **Design system:** Custom glass morphism — NColorTheme, NGlassCard, NTypography, NSpacing, NColors
- **Structure:**
  - `lib/core/` — api_client.dart, providers.dart, token_storage.dart, json_helpers.dart
  - `lib/app/` — router.dart (AppShell + GoRouter), theme.dart
  - `lib/shared/` — constants (n_colors, n_spacing, n_typography), widgets (n_glass_card, n_bottom_nav, n_gradient_bg, etc.)
  - `lib/features/` — auth, budget, coach, dashboard, goals, onboarding, profile, transactions
- **API:** Dio HTTP client with JWT interceptor for auto-refresh
- **.env:** `API_BASE_URL=http://localhost:8080`

### Local Development Setup
- Docker Compose runs the backend: `cd numia-api && docker compose up -d`
- API accessible at `localhost:8080` (Caddy proxies to API container)
- Android device connected via USB, port forwarding: `adb reverse tcp:8080 tcp:8080`
- Flutter app installed via: `flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk && adb shell am start -n com.numia.numia/.MainActivity`
- **IMPORTANT:** Do NOT use `flutter run` and then `kill` the process — it terminates the app on device. Use `adb install` + `adb shell am start` instead.

## Database Schema

### Migration 1: Core tables
- users, refresh_tokens, accounts, debts, transactions, goals, conversations, messages

### Migration 2: Budget tables (`000002_budget_tables`)
- `budget_categories` — predefined + custom categories per user (soft-delete via is_active)
- `budgets` — one per user, global_amount + cycle_start_day (1-28)
- `budget_allocations` — per-category allocation amounts
- `expenses` — amount, category, date, description, subcategory
- `devices` — FCM tokens for push notifications
- `budget_notifications` — tracks sent threshold alerts (80%, 100%)

## Budget & Expenses Feature (Completed)

### API Endpoints
| Method | Path | Description |
|--------|------|-------------|
| GET | /api/v1/budget/categories | List categories (auto-seeds defaults) |
| POST | /api/v1/budget/categories | Create custom category |
| DELETE | /api/v1/budget/categories/:id | Soft-delete category |
| GET | /api/v1/budget | Get budget + allocations |
| POST | /api/v1/budget | Create/update budget |
| PUT | /api/v1/budget/allocations | Set allocations (body: `{"items": [...]}`) |
| GET | /api/v1/budget/expenses?start=YYYY-MM-DD&end=YYYY-MM-DD | List expenses (filtered by month) |
| POST | /api/v1/budget/expenses | Create expense |
| PUT | /api/v1/budget/expenses/:id | Update expense |
| DELETE | /api/v1/budget/expenses/:id | Delete expense |
| GET | /api/v1/budget/summary | Budget summary with cycle info |

### Known JSON Field Mappings (Go → Flutter)
The Go backend and Flutter models use different field names in some places:
- `global.total_budget` → Flutter reads as `budgeted`
- `global.total_spent` → Flutter reads as `spent`
- `categories[].category_name` → Flutter reads as `name`
- `categories[].category_emoji` → Flutter reads as `emoji`
- `categories[].allocated` → Flutter reads as `budgeted`

These are handled in `budget_summary.dart` with fallback parsing: `json['total_budget'] ?? json['budgeted']`

### Key Behaviors
- **Expenses are independent of budget** — users can register expenses without configuring a budget
- **ListExpenses** falls back to current calendar month when no budget exists
- **Month filtering** — `selectedMonthProvider` (StateProvider<DateTime>) controls which month's expenses are shown. The `expensesProvider` sends start/end query params based on selected month.
- **Expense editing** — `AddExpenseSheet` accepts optional `expense` parameter for edit mode. Tap on expense tile opens edit sheet.
- **Predefined categories**: Alimentacion, Transporte, Vivienda, Salud, Entretenimiento, Ropa, Educacion, Tecnologia, Viajes, Hogar, Mascotas, Otros
- **Budget cycle** computed from `cycle_start_day` (1-28), wraps across months
- **Push notifications** via FCM at 80% and 100% thresholds (async goroutine)

### Flutter Providers (budget-related)
- `budgetRepositoryProvider` — BudgetRepository instance
- `budgetProvider` — FutureProvider<Budget?>
- `budgetSummaryProvider` — FutureProvider<BudgetSummary?> (returns null if no budget)
- `selectedMonthProvider` — StateProvider<DateTime> (controls month filter)
- `expensesProvider` — FutureProvider<List<Expense>> (filtered by selectedMonth)

### Flutter Screens (budget)
- `BudgetScreen` — main screen with two states:
  - No budget: setup banner + month selector + expense list
  - Active budget: progress ring + categories + month selector + expense list
- `BudgetSetupScreen` — 2-step wizard (amount/cycle → allocations)
- `AddExpenseSheet` — bottom sheet for create/edit expense
- `CategoryDetailScreen` — category progress + expense list + swipe-to-delete

## Bottom Navigation (6 tabs)
1. Inicio (dashboard)
2. Presupuesto (budget)
3. Movimientos (transactions)
4. IA (coach)
5. Metas (goals)
6. Perfil (profile)

Labels only shown on active tab. Uses `MediaQuery.viewPadding.bottom` for safe area margin.

## Fixed Issues This Session
1. **Locale not initialized** — Added `initializeDateFormatting('es')` in main.dart
2. **Dashboard overflow** — Wrapped "META ACTIVA" text in Flexible with ellipsis
3. **AddExpenseSheet overflow** — Wrapped Column in SingleChildScrollView
4. **Allocations 400 error** — Flutter sent `{"allocations": [...]}` but Go expects `{"items": [...]}`
5. **Summary showing zeros** — Fixed JSON field name mismatches in budget_summary.dart
6. **App crashing** — Was caused by killing `flutter run` process; switched to `adb install` workflow

## Test User
- Email: `test@numia.mx`
- Password: unknown (bcrypt hash in DB)
- User ID: `a1c84bf1-94cc-4ea1-9513-5de7790b0883`

## Device
- Android device connected via USB
- Device ID may change between connections (was `25028PC03G`, then `863d00583048313238510d56e01d4c`)
- Always check with `adb devices` before deploying
