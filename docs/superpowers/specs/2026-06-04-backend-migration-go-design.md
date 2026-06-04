# Numia Backend Migration: Supabase → Go + PostgreSQL

## Overview

Migrate Numia's backend from Supabase (managed BaaS) to a custom Go API with PostgreSQL, deployed on a Hostinger VPS via Docker. The Groq AI integration moves from the Flutter client to the backend.

## Technology Stack

| Component | Technology |
|-----------|-----------|
| Language | Go 1.23+ |
| HTTP Framework | Gin |
| Database | PostgreSQL 16 |
| Data Access | sqlc (type-safe generated code from SQL) |
| Migrations | golang-migrate (raw SQL files) |
| Auth | JWT (HS256) + sessions in DB |
| AI | Groq API (Llama 3.3 70B) — server-side |
| Reverse Proxy | Caddy |
| Containerization | Docker + Docker Compose |
| Hosting | Hostinger VPS, direct IP (HTTP), HTTPS-ready for when a domain is added |

## Project Structure

```
numia-api/
├── cmd/api/main.go
├── docker-compose.yml
├── Dockerfile
├── Caddyfile
├── sqlc.yaml
├── .env
├── internal/
│   ├── config/                     # Env var loading
│   ├── middleware/                  # JWT auth, CORS, logging
│   ├── database/
│   │   ├── connection.go           # Connection pool
│   │   ├── queries/                # .sql files for sqlc
│   │   ├── sqlc/                   # Generated Go code
│   │   └── migrations/             # golang-migrate SQL files
│   ├── auth/
│   │   ├── handler.go
│   │   ├── service.go
│   │   └── model.go
│   ├── user/
│   │   ├── handler.go
│   │   └── service.go
│   ├── account/
│   │   ├── handler.go
│   │   └── service.go
│   ├── transaction/
│   │   ├── handler.go
│   │   └── service.go
│   ├── goal/
│   │   ├── handler.go
│   │   └── service.go
│   ├── debt/
│   │   ├── handler.go
│   │   └── service.go
│   ├── dashboard/
│   │   ├── handler.go
│   │   └── service.go
│   └── coach/
│       ├── handler.go
│       ├── service.go
│       ├── groq.go
│       └── model.go
```

## Database Schema

6 tables. Removed from Supabase original: `bank_connections`, `subscriptions`, `ai_insights` (not implemented yet). Removed `belvo_*` and `category_override` fields.

### users

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | gen_random_uuid() |
| email | TEXT UNIQUE NOT NULL | Was in auth.users, now here |
| password_hash | TEXT NOT NULL | bcrypt |
| full_name | TEXT NOT NULL | |
| country | TEXT NOT NULL | DEFAULT 'MX' |
| birth_date | DATE | nullable |
| occupation | TEXT | nullable |
| onboarding_done | BOOLEAN NOT NULL | DEFAULT FALSE |
| plan | TEXT NOT NULL | DEFAULT 'free' |
| avatar_url | TEXT | nullable |
| created_at | TIMESTAMPTZ NOT NULL | DEFAULT now() |
| updated_at | TIMESTAMPTZ NOT NULL | DEFAULT now() |

### sessions

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | gen_random_uuid() |
| user_id | UUID NOT NULL | FK → users ON DELETE CASCADE |
| refresh_token | TEXT UNIQUE NOT NULL | |
| user_agent | TEXT | nullable |
| ip_address | TEXT | nullable |
| expires_at | TIMESTAMPTZ NOT NULL | |
| created_at | TIMESTAMPTZ NOT NULL | DEFAULT now() |

### accounts

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | gen_random_uuid() |
| user_id | UUID NOT NULL | FK → users ON DELETE CASCADE |
| name | TEXT NOT NULL | |
| type | TEXT | checking, savings, credit, wallet |
| currency | TEXT NOT NULL | DEFAULT 'MXN' |
| balance | NUMERIC NOT NULL | DEFAULT 0 |
| credit_limit | NUMERIC | nullable |
| is_active | BOOLEAN NOT NULL | DEFAULT TRUE |
| created_at | TIMESTAMPTZ NOT NULL | DEFAULT now() |
| updated_at | TIMESTAMPTZ NOT NULL | DEFAULT now() |

### transactions

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | gen_random_uuid() |
| user_id | UUID NOT NULL | FK → users ON DELETE CASCADE |
| account_id | UUID | FK → accounts ON DELETE SET NULL |
| amount | NUMERIC NOT NULL | Positive = income, negative = expense |
| currency | TEXT NOT NULL | DEFAULT 'MXN' |
| description | TEXT | nullable |
| merchant_name | TEXT | nullable |
| category | TEXT | nullable |
| subcategory | TEXT | nullable |
| value_date | DATE NOT NULL | DEFAULT CURRENT_DATE |
| is_manual | BOOLEAN NOT NULL | DEFAULT TRUE |
| notes | TEXT | nullable |
| created_at | TIMESTAMPTZ NOT NULL | DEFAULT now() |

### goals

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | gen_random_uuid() |
| user_id | UUID NOT NULL | FK → users ON DELETE CASCADE |
| type | TEXT NOT NULL | |
| name | TEXT NOT NULL | |
| target_amount | NUMERIC NOT NULL | |
| current_amount | NUMERIC NOT NULL | DEFAULT 0 |
| monthly_contribution | NUMERIC | nullable |
| target_date | DATE | nullable |
| priority | SMALLINT NOT NULL | DEFAULT 1 |
| status | TEXT NOT NULL | DEFAULT 'active' |
| emoji | TEXT | nullable |
| notes | TEXT | nullable |
| created_at | TIMESTAMPTZ NOT NULL | DEFAULT now() |
| updated_at | TIMESTAMPTZ NOT NULL | DEFAULT now() |

### debts

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | gen_random_uuid() |
| user_id | UUID NOT NULL | FK → users ON DELETE CASCADE |
| type | TEXT NOT NULL | |
| name | TEXT NOT NULL | |
| institution | TEXT | nullable |
| total_amount | NUMERIC NOT NULL | |
| original_amount | NUMERIC | nullable |
| monthly_payment | NUMERIC | nullable |
| interest_rate | NUMERIC | nullable |
| is_active | BOOLEAN NOT NULL | DEFAULT TRUE |
| notes | TEXT | nullable |
| created_at | TIMESTAMPTZ NOT NULL | DEFAULT now() |
| updated_at | TIMESTAMPTZ NOT NULL | DEFAULT now() |

### ai_conversations

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | gen_random_uuid() |
| user_id | UUID NOT NULL | FK → users ON DELETE CASCADE |
| title | TEXT | nullable |
| messages | JSONB NOT NULL | DEFAULT '[]' |
| context_snapshot | JSONB | nullable |
| message_count | INTEGER NOT NULL | DEFAULT 0 |
| created_at | TIMESTAMPTZ NOT NULL | DEFAULT now() |
| updated_at | TIMESTAMPTZ NOT NULL | DEFAULT now() |

### Indexes

```
idx_sessions_user          → sessions(user_id)
idx_sessions_refresh       → sessions(refresh_token)
idx_sessions_expires       → sessions(expires_at)
idx_transactions_user_date → transactions(user_id, value_date DESC)
idx_transactions_user_cat  → transactions(user_id, category)
idx_goals_user_status      → goals(user_id, status)
idx_accounts_user          → accounts(user_id)
idx_debts_user             → debts(user_id)
idx_ai_conversations_user  → ai_conversations(user_id)
```

### Triggers

- `updated_at` auto-update on: users, accounts, goals, debts, ai_conversations

## API Endpoints

All prefixed with `/api/v1`. Protected endpoints require `Authorization: Bearer <access_token>`.

### Auth (public)

```
POST /auth/register     ← { email, password, full_name }
                        → { access_token, refresh_token, user }

POST /auth/login        ← { email, password }
                        → { access_token, refresh_token, user }

POST /auth/refresh      ← { refresh_token }
                        → { access_token, refresh_token }

POST /auth/logout       ← { refresh_token }
                        → 204
```

- Access token: 15 min, HS256, payload: `{ user_id, exp, iat }`
- Refresh token: 30 days, stored in sessions table
- Refresh rotates the token (old one invalidated)

### User (protected)

```
GET  /users/me              → { user }
PUT  /users/me              ← { full_name, avatar_url }  → { user }
POST /users/onboarding      ← { full_name, country, birth_date?, occupation? }  → { user }
```

### Accounts (protected)

```
GET    /accounts             → [{ account }]
POST   /accounts             ← { name, type, currency?, balance?, credit_limit? }  → { account }
PUT    /accounts/:id         ← { name?, balance?, is_active? }  → { account }
DELETE /accounts/:id         → 204
```

### Transactions (protected)

```
GET    /transactions              → [{ transaction }]  ?category=&limit=50&offset=0
POST   /transactions              ← { account_id?, amount, description?, merchant_name?, category?, subcategory?, value_date?, notes? }  → { transaction }
PUT    /transactions/:id          ← { amount?, description?, category?, notes? }  → { transaction }
DELETE /transactions/:id          → 204
GET    /transactions/summary      → { income, expenses, net, tx_count }  ?month=2026-06
GET    /transactions/categories   → [{ category, total, tx_count }]  ?month=2026-06
```

### Goals (protected)

```
GET    /goals                     → [{ goal }]  ?status=active
POST   /goals                     ← { type, name, target_amount, monthly_contribution?, target_date?, priority?, emoji?, notes? }  → { goal }
PUT    /goals/:id                 ← { name?, target_amount?, current_amount?, status?, ... }  → { goal }
POST   /goals/:id/contribute      ← { amount }  → { goal }
DELETE /goals/:id                 → 204
```

### Debts (protected)

```
GET    /debts                     → [{ debt }]  ?active=true
POST   /debts                     ← { type, name, institution?, total_amount, original_amount?, monthly_payment?, interest_rate?, notes? }  → { debt }
PUT    /debts/:id                 ← { total_amount?, monthly_payment?, is_active?, ... }  → { debt }
DELETE /debts/:id                 → 204
```

### Dashboard (protected)

```
GET /dashboard/summary → {
  net_worth: { total_assets, total_debt, net_worth },
  monthly_summary: { income, expenses, net, tx_count },
  active_goals: [{ id, name, target_amount, current_amount, emoji }],
  active_debts: [{ id, name, total_amount, monthly_payment }]
}
```

### Coach (protected)

```
POST   /coach/chat                ← { conversation_id?, message }  → SSE stream
GET    /coach/conversations       → [{ id, title, message_count, updated_at }]
GET    /coach/conversations/:id   → { conversation with messages }
DELETE /coach/conversations/:id   → 204
```

Chat flow:
1. Create conversation if no conversation_id
2. Fetch user financial context (accounts, recent transactions, goals, debts)
3. Build system prompt with Mexican financial context + user data
4. Stream to Groq API
5. Relay tokens to client via SSE
6. Save user message + full response to ai_conversations

### Health (public)

```
GET /api/v1/health → { "status": "ok", "db": "connected" }
```

### Error Format

```json
{ "error": { "code": "VALIDATION_ERROR", "message": "El email ya está registrado" } }
```

HTTP codes: 400 validation, 401 unauthenticated, 403 forbidden, 404 not found, 500 internal.

## Docker Compose

3 services + 1 init container:

- **db**: postgres:16-alpine, volume for data, only exposed on 127.0.0.1:5432
- **migrate**: migrate/migrate, runs on startup, depends on db healthy
- **api**: Go binary (multi-stage build, ~15MB), depends on migrate completed, only exposed on 127.0.0.1:8080
- **caddy**: caddy:2-alpine, public ports 80/443, reverse proxies to api:8080

Startup order: db → migrate → api → caddy.

### Security

- PostgreSQL: 127.0.0.1 only
- API: 127.0.0.1 only
- Caddy: only public-facing service
- Passwords: bcrypt
- CORS: configured for mobile app

## Flutter Changes

### Remove

- `supabase_flutter` from pubspec.yaml
- `lib/core/supabase_client.dart`
- `lib/core/groq_client.dart`
- All Supabase references
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GROQ_API_KEY` from client .env

### Add

- `lib/core/api_client.dart` — Dio client with base URL, auth interceptor, refresh interceptor
- `lib/core/token_storage.dart` — Save/load/clear access + refresh tokens

### Modify

| File | Change |
|------|--------|
| pubspec.yaml | Remove supabase_flutter |
| lib/main.dart | Remove initSupabase(), init API client |
| lib/core/providers.dart | Rewrite all providers to use Dio |
| lib/app/router.dart | Auth guards based on token presence |
| lib/features/auth/data/user_repository.dart | Supabase → Dio |
| lib/features/auth/presentation/login_screen.dart | New auth flow |
| lib/features/auth/presentation/register_screen.dart | New auth flow |
| lib/features/dashboard/data/dashboard_repository.dart | Supabase → Dio |
| lib/features/transactions/data/transaction_repository.dart | Supabase → Dio |
| lib/features/goals/data/goal_repository.dart | Supabase → Dio |
| lib/features/coach/data/conversation_repository.dart | Supabase → Dio |
| lib/features/coach/presentation/coach_screen.dart | SSE from own API |
| lib/features/profile/presentation/profile_screen.dart | Logout via API |
| lib/features/onboarding/presentation/onboarding_notifier.dart | Supabase → Dio |

### Pattern

All repositories change from Supabase queries to HTTP calls:

```dart
// Before
final res = await supabase.rpc('get_dashboard_summary');
// After
final res = await dio.get('/api/v1/dashboard/summary');
```
