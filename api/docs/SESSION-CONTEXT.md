# Numia API - Session Context (2026-06-04)

## Overview
Go REST API backend for the Numia personal finance app.

## Tech Stack
- Go 1.25, Gin framework, PostgreSQL, pgx/v5, SQLC
- Docker Compose: db (postgres:16-alpine), migrate (golang-migrate), api, caddy
- Dockerfile: `golang:1.25-alpine` builder → `alpine:3.20` runtime
- SQLC binary at: `~/go/bin/sqlc`

## Project Structure
```
cmd/api/main.go              — entry point
internal/
  auth/                      — JWT auth (login, register, refresh)
  budget/
    service.go               — business logic (categories, budgets, allocations, expenses, summary, notifications)
    handler.go               — HTTP handlers for /budget/* endpoints
    fcm.go                   — Firebase Cloud Messaging client
  coach/                     — AI coach with SSE streaming
  config/config.go           — env-based config
  dashboard/                 — financial summary, accounts, debts
  database/
    migrations/              — SQL migration files (000001, 000002)
    queries/                 — SQLC query files (.sql)
    sqlc/                    — auto-generated Go code
  device/                    — FCM device token CRUD
  goal/                      — goals CRUD
  middleware/                — auth middleware, error response helpers
  transaction/               — transactions CRUD
```

## Budget Module API
| Method | Path | Handler |
|--------|------|---------|
| GET | /budget/categories | listCategories (auto-seeds 12 defaults) |
| POST | /budget/categories | createCategory |
| DELETE | /budget/categories/:id | deleteCategory (soft) |
| GET | /budget | getBudget |
| POST | /budget | createOrUpdateBudget (upsert) |
| PUT | /budget/allocations | setAllocations (body: `{"items": [...]}`) |
| GET | /budget/expenses?start=&end= | listExpenses (optional date range) |
| POST | /budget/expenses | createExpense |
| PUT | /budget/expenses/:id | updateExpense |
| DELETE | /budget/expenses/:id | deleteExpense |
| GET | /budget/summary | getSummary |

## Key Implementation Details

### ListExpenses
Accepts optional `start` and `end` query params (YYYY-MM-DD). If not provided, falls back to current budget cycle or current calendar month if no budget exists.

### Summary Response JSON
```json
{
  "cycle": {"start": "2026-06-01", "end": "2026-06-30"},
  "global": {"total_budget": 10000, "total_spent": 3500, "total_remaining": 6500, "percentage": 35},
  "categories": [
    {"category_id": "...", "category_name": "Alimentacion", "category_emoji": "🍔", "allocated": 3000, "spent": 1200, "remaining": 1800, "percentage": 40}
  ]
}
```

**Note:** Flutter models use different field names (budgeted, name, emoji instead of total_budget, category_name, category_emoji). Handled via fallback parsing on Flutter side.

### Notifications
`checkAndNotify` runs as a goroutine after each expense creation. Checks 80% and 100% thresholds per category and sends FCM push notifications. Records sent notifications to avoid duplicates per cycle.

### Predefined Categories
Alimentacion, Transporte, Vivienda, Salud, Entretenimiento, Ropa, Educacion, Tecnologia, Viajes, Hogar, Mascotas, Otros

## Database
- PostgreSQL 16
- Migrations managed by golang-migrate
- 2 migration versions applied
- Test user: `test@numia.mx` (ID: `a1c84bf1-94cc-4ea1-9513-5de7790b0883`)

## Docker Commands
```bash
docker compose up -d              # start all
docker compose up -d --build api  # rebuild API only
docker logs numia-api-api-1       # check API logs
docker exec numia-api-db-1 psql -U numia -d numia -c "..."  # query DB
```
