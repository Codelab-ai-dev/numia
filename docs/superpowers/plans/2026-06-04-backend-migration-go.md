# Backend Migration: Go + PostgreSQL Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Go REST API with PostgreSQL that replaces Supabase, then migrate the Flutter client to use it.

**Architecture:** Feature-based Go project using Gin, sqlc, golang-migrate. Docker Compose orchestrates PostgreSQL, API, migrations, and Caddy. Flutter repositories switch from Supabase SDK to Dio HTTP calls.

**Tech Stack:** Go 1.23, Gin, sqlc, golang-migrate, PostgreSQL 16, Docker, Caddy, Dio (Flutter)

---

## Phase 1: Go Backend

### Task 1: Project Scaffolding

**Files:**
- Create: `numia-api/go.mod`
- Create: `numia-api/cmd/api/main.go`
- Create: `numia-api/internal/config/config.go`
- Create: `numia-api/.env`
- Create: `numia-api/.gitignore`

- [ ] **Step 1: Initialize Go module and install dependencies**

```bash
mkdir -p ~/Desktop/numia-api && cd ~/Desktop/numia-api
go mod init numia-api
go get github.com/gin-gonic/gin@v1.10.0
go get github.com/jackc/pgx/v5@v5.7.2
go get github.com/golang-jwt/jwt/v5@v5.2.1
go get golang.org/x/crypto@v0.31.0
go get github.com/joho/godotenv@v1.5.1
go get github.com/google/uuid@v1.6.0
```

- [ ] **Step 2: Create .gitignore**

```gitignore
.env
/tmp
/bin
```

- [ ] **Step 3: Create .env**

```env
DB_URL=postgres://numia:numia_dev@localhost:5432/numia?sslmode=disable
JWT_SECRET=dev-secret-change-in-production-must-be-64-chars-long-at-least!!
GROQ_API_KEY=gsk_your_groq_api_key_here
GIN_MODE=debug
PORT=8080
```

- [ ] **Step 4: Create config loader**

Create `numia-api/internal/config/config.go`:

```go
package config

import (
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	DBURL      string
	JWTSecret  string
	GroqAPIKey string
	Port       string
	GinMode    string
}

func Load() *Config {
	_ = godotenv.Load()

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	return &Config{
		DBURL:      os.Getenv("DB_URL"),
		JWTSecret:  os.Getenv("JWT_SECRET"),
		GroqAPIKey: os.Getenv("GROQ_API_KEY"),
		Port:       port,
		GinMode:    os.Getenv("GIN_MODE"),
	}
}
```

- [ ] **Step 5: Create main.go entry point**

Create `numia-api/cmd/api/main.go`:

```go
package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"numia-api/internal/config"
	"numia-api/internal/database"

	"github.com/gin-gonic/gin"
)

func main() {
	cfg := config.Load()

	if cfg.GinMode == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	db, err := database.Connect(cfg.DBURL)
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}
	defer db.Close()

	r := gin.Default()

	r.GET("/api/v1/health", func(c *gin.Context) {
		if err := db.Ping(c.Request.Context()); err != nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{
				"status": "error", "db": "disconnected",
			})
			return
		}
		c.JSON(http.StatusOK, gin.H{"status": "ok", "db": "connected"})
	})

	srv := &http.Server{Addr: ":" + cfg.Port, Handler: r}

	go func() {
		log.Printf("API listening on :%s", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("shutting down...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("forced shutdown: %v", err)
	}
}
```

- [ ] **Step 6: Commit**

```bash
git init && git add -A && git commit -m "feat: project scaffolding with config and main entry point"
```

---

### Task 2: Database Connection and Migrations

**Files:**
- Create: `numia-api/internal/database/connection.go`
- Create: `numia-api/internal/database/migrations/000001_initial_schema.up.sql`
- Create: `numia-api/internal/database/migrations/000001_initial_schema.down.sql`

- [ ] **Step 1: Create database connection pool**

Create `numia-api/internal/database/connection.go`:

```go
package database

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type DB struct {
	Pool *pgxpool.Pool
}

func Connect(dbURL string) (*DB, error) {
	cfg, err := pgxpool.ParseConfig(dbURL)
	if err != nil {
		return nil, err
	}

	cfg.MaxConns = 20
	cfg.MinConns = 2
	cfg.MaxConnLifetime = 30 * time.Minute
	cfg.MaxConnIdleTime = 5 * time.Minute

	pool, err := pgxpool.NewWithConfig(context.Background(), cfg)
	if err != nil {
		return nil, err
	}

	if err := pool.Ping(context.Background()); err != nil {
		pool.Close()
		return nil, err
	}

	return &DB{Pool: pool}, nil
}

func (db *DB) Close() {
	db.Pool.Close()
}

func (db *DB) Ping(ctx context.Context) error {
	return db.Pool.Ping(ctx)
}
```

- [ ] **Step 2: Create up migration**

Create `numia-api/internal/database/migrations/000001_initial_schema.up.sql`:

```sql
-- Users
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           TEXT UNIQUE NOT NULL,
    password_hash   TEXT NOT NULL,
    full_name       TEXT NOT NULL,
    country         TEXT NOT NULL DEFAULT 'MX',
    birth_date      DATE,
    occupation      TEXT,
    onboarding_done BOOLEAN NOT NULL DEFAULT FALSE,
    plan            TEXT NOT NULL DEFAULT 'free',
    avatar_url      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Sessions
CREATE TABLE sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token   TEXT UNIQUE NOT NULL,
    user_agent      TEXT,
    ip_address      TEXT,
    expires_at      TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Accounts
CREATE TABLE accounts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    type            TEXT,
    currency        TEXT NOT NULL DEFAULT 'MXN',
    balance         NUMERIC NOT NULL DEFAULT 0,
    credit_limit    NUMERIC,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Transactions
CREATE TABLE transactions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    account_id      UUID REFERENCES accounts(id) ON DELETE SET NULL,
    amount          NUMERIC NOT NULL,
    currency        TEXT NOT NULL DEFAULT 'MXN',
    description     TEXT,
    merchant_name   TEXT,
    category        TEXT,
    subcategory     TEXT,
    value_date      DATE NOT NULL DEFAULT CURRENT_DATE,
    is_manual       BOOLEAN NOT NULL DEFAULT TRUE,
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Goals
CREATE TABLE goals (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type                  TEXT NOT NULL,
    name                  TEXT NOT NULL,
    target_amount         NUMERIC NOT NULL,
    current_amount        NUMERIC NOT NULL DEFAULT 0,
    monthly_contribution  NUMERIC,
    target_date           DATE,
    priority              SMALLINT NOT NULL DEFAULT 1,
    status                TEXT NOT NULL DEFAULT 'active',
    emoji                 TEXT,
    notes                 TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Debts
CREATE TABLE debts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type            TEXT NOT NULL,
    name            TEXT NOT NULL,
    institution     TEXT,
    total_amount    NUMERIC NOT NULL,
    original_amount NUMERIC,
    monthly_payment NUMERIC,
    interest_rate   NUMERIC,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- AI Conversations
CREATE TABLE ai_conversations (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title             TEXT,
    messages          JSONB NOT NULL DEFAULT '[]',
    context_snapshot  JSONB,
    message_count     INTEGER NOT NULL DEFAULT 0,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_sessions_user ON sessions(user_id);
CREATE INDEX idx_sessions_refresh ON sessions(refresh_token);
CREATE INDEX idx_sessions_expires ON sessions(expires_at);
CREATE INDEX idx_transactions_user_date ON transactions(user_id, value_date DESC);
CREATE INDEX idx_transactions_user_cat ON transactions(user_id, category);
CREATE INDEX idx_goals_user_status ON goals(user_id, status);
CREATE INDEX idx_accounts_user ON accounts(user_id);
CREATE INDEX idx_debts_user ON debts(user_id);
CREATE INDEX idx_ai_conversations_user ON ai_conversations(user_id);

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON accounts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON goals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON debts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON ai_conversations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

- [ ] **Step 3: Create down migration**

Create `numia-api/internal/database/migrations/000001_initial_schema.down.sql`:

```sql
DROP TABLE IF EXISTS ai_conversations CASCADE;
DROP TABLE IF EXISTS debts CASCADE;
DROP TABLE IF EXISTS goals CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP FUNCTION IF EXISTS update_updated_at();
```

- [ ] **Step 4: Test database connection locally**

```bash
# Requires a local PostgreSQL or Docker:
docker run -d --name numia-pg -e POSTGRES_USER=numia -e POSTGRES_PASSWORD=numia_dev -e POSTGRES_DB=numia -p 5432:5432 postgres:16-alpine
# Run migrations:
go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
migrate -path internal/database/migrations -database "postgres://numia:numia_dev@localhost:5432/numia?sslmode=disable" up
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: database connection pool and initial migration schema"
```

---

### Task 3: sqlc Setup and Query Files

**Files:**
- Create: `numia-api/sqlc.yaml`
- Create: `numia-api/internal/database/queries/users.sql`
- Create: `numia-api/internal/database/queries/sessions.sql`
- Create: `numia-api/internal/database/queries/accounts.sql`
- Create: `numia-api/internal/database/queries/transactions.sql`
- Create: `numia-api/internal/database/queries/goals.sql`
- Create: `numia-api/internal/database/queries/debts.sql`
- Create: `numia-api/internal/database/queries/ai_conversations.sql`
- Create: `numia-api/internal/database/queries/dashboard.sql`

- [ ] **Step 1: Create sqlc.yaml**

```yaml
version: "2"
sql:
  - engine: "postgresql"
    queries: "internal/database/queries"
    schema: "internal/database/migrations"
    gen:
      go:
        package: "sqlc"
        out: "internal/database/sqlc"
        sql_package: "pgx/v5"
        emit_json_tags: true
        emit_empty_slices: true
```

- [ ] **Step 2: Create users.sql queries**

Create `numia-api/internal/database/queries/users.sql`:

```sql
-- name: CreateUser :one
INSERT INTO users (email, password_hash, full_name)
VALUES ($1, $2, $3)
RETURNING *;

-- name: GetUserByID :one
SELECT * FROM users WHERE id = $1;

-- name: GetUserByEmail :one
SELECT * FROM users WHERE email = $1;

-- name: UpdateUserProfile :one
UPDATE users
SET full_name = COALESCE(sqlc.narg('full_name'), full_name),
    avatar_url = COALESCE(sqlc.narg('avatar_url'), avatar_url)
WHERE id = $1
RETURNING *;

-- name: CompleteOnboarding :one
UPDATE users
SET full_name = $2,
    country = $3,
    birth_date = sqlc.narg('birth_date'),
    occupation = sqlc.narg('occupation'),
    onboarding_done = TRUE
WHERE id = $1
RETURNING *;
```

- [ ] **Step 3: Create sessions.sql queries**

Create `numia-api/internal/database/queries/sessions.sql`:

```sql
-- name: CreateSession :one
INSERT INTO sessions (user_id, refresh_token, user_agent, ip_address, expires_at)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: GetSessionByRefreshToken :one
SELECT * FROM sessions WHERE refresh_token = $1 AND expires_at > now();

-- name: DeleteSession :exec
DELETE FROM sessions WHERE refresh_token = $1;

-- name: DeleteUserSessions :exec
DELETE FROM sessions WHERE user_id = $1;

-- name: DeleteExpiredSessions :exec
DELETE FROM sessions WHERE expires_at <= now();
```

- [ ] **Step 4: Create accounts.sql queries**

Create `numia-api/internal/database/queries/accounts.sql`:

```sql
-- name: ListAccountsByUser :many
SELECT * FROM accounts
WHERE user_id = $1 AND is_active = TRUE
ORDER BY created_at;

-- name: GetAccountByID :one
SELECT * FROM accounts WHERE id = $1 AND user_id = $2;

-- name: CreateAccount :one
INSERT INTO accounts (user_id, name, type, currency, balance, credit_limit)
VALUES ($1, $2, $3, $4, $5, sqlc.narg('credit_limit'))
RETURNING *;

-- name: UpdateAccount :one
UPDATE accounts
SET name = COALESCE(sqlc.narg('name'), name),
    balance = COALESCE(sqlc.narg('balance'), balance),
    is_active = COALESCE(sqlc.narg('is_active'), is_active)
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeleteAccount :exec
DELETE FROM accounts WHERE id = $1 AND user_id = $2;
```

- [ ] **Step 5: Create transactions.sql queries**

Create `numia-api/internal/database/queries/transactions.sql`:

```sql
-- name: ListTransactions :many
SELECT * FROM transactions
WHERE user_id = $1
  AND (sqlc.narg('category')::TEXT IS NULL OR category = sqlc.narg('category'))
ORDER BY value_date DESC
LIMIT $2 OFFSET $3;

-- name: GetTransactionByID :one
SELECT * FROM transactions WHERE id = $1 AND user_id = $2;

-- name: CreateTransaction :one
INSERT INTO transactions (
    user_id, account_id, amount, currency, description,
    merchant_name, category, subcategory, value_date, is_manual, notes
) VALUES ($1, sqlc.narg('account_id'), $2, $3, sqlc.narg('description'),
    sqlc.narg('merchant_name'), sqlc.narg('category'), sqlc.narg('subcategory'),
    $4, $5, sqlc.narg('notes'))
RETURNING *;

-- name: UpdateTransaction :one
UPDATE transactions
SET amount = COALESCE(sqlc.narg('amount'), amount),
    description = COALESCE(sqlc.narg('description'), description),
    category = COALESCE(sqlc.narg('category'), category),
    notes = COALESCE(sqlc.narg('notes'), notes)
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeleteTransaction :exec
DELETE FROM transactions WHERE id = $1 AND user_id = $2;

-- name: GetMonthlySummary :one
SELECT
    COALESCE(SUM(amount) FILTER (WHERE amount > 0), 0)::NUMERIC AS income,
    COALESCE(SUM(ABS(amount)) FILTER (WHERE amount < 0), 0)::NUMERIC AS expenses,
    COALESCE(SUM(amount), 0)::NUMERIC AS net,
    COUNT(*)::BIGINT AS tx_count
FROM transactions
WHERE user_id = $1
  AND value_date >= DATE_TRUNC('month', $2::DATE)
  AND value_date < DATE_TRUNC('month', $2::DATE) + INTERVAL '1 month';

-- name: GetCategoryBreakdown :many
SELECT
    COALESCE(category, 'Sin categoría') AS category,
    COALESCE(SUM(ABS(amount)), 0)::NUMERIC AS total,
    COUNT(*)::BIGINT AS tx_count
FROM transactions
WHERE user_id = $1
  AND amount < 0
  AND value_date >= DATE_TRUNC('month', $2::DATE)
  AND value_date < DATE_TRUNC('month', $2::DATE) + INTERVAL '1 month'
GROUP BY category
ORDER BY total DESC;
```

- [ ] **Step 6: Create goals.sql queries**

Create `numia-api/internal/database/queries/goals.sql`:

```sql
-- name: ListGoals :many
SELECT * FROM goals
WHERE user_id = $1
  AND (sqlc.narg('status')::TEXT IS NULL OR status = sqlc.narg('status'))
ORDER BY priority, created_at DESC;

-- name: GetGoalByID :one
SELECT * FROM goals WHERE id = $1 AND user_id = $2;

-- name: CreateGoal :one
INSERT INTO goals (
    user_id, type, name, target_amount, monthly_contribution,
    target_date, priority, emoji, notes
) VALUES ($1, $2, $3, $4, sqlc.narg('monthly_contribution'),
    sqlc.narg('target_date'), $5, sqlc.narg('emoji'), sqlc.narg('notes'))
RETURNING *;

-- name: UpdateGoal :one
UPDATE goals
SET name = COALESCE(sqlc.narg('name'), name),
    target_amount = COALESCE(sqlc.narg('target_amount'), target_amount),
    current_amount = COALESCE(sqlc.narg('current_amount'), current_amount),
    monthly_contribution = COALESCE(sqlc.narg('monthly_contribution'), monthly_contribution),
    status = COALESCE(sqlc.narg('status'), status),
    emoji = COALESCE(sqlc.narg('emoji'), emoji),
    notes = COALESCE(sqlc.narg('notes'), notes)
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: AddContribution :one
UPDATE goals
SET current_amount = current_amount + $3
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeleteGoal :exec
DELETE FROM goals WHERE id = $1 AND user_id = $2;
```

- [ ] **Step 7: Create debts.sql queries**

Create `numia-api/internal/database/queries/debts.sql`:

```sql
-- name: ListDebts :many
SELECT * FROM debts
WHERE user_id = $1
  AND (sqlc.narg('active_only')::BOOLEAN IS NULL OR is_active = sqlc.narg('active_only'))
ORDER BY created_at DESC;

-- name: GetDebtByID :one
SELECT * FROM debts WHERE id = $1 AND user_id = $2;

-- name: CreateDebt :one
INSERT INTO debts (
    user_id, type, name, institution, total_amount,
    original_amount, monthly_payment, interest_rate, notes
) VALUES ($1, $2, $3, sqlc.narg('institution'), $4,
    sqlc.narg('original_amount'), sqlc.narg('monthly_payment'),
    sqlc.narg('interest_rate'), sqlc.narg('notes'))
RETURNING *;

-- name: UpdateDebt :one
UPDATE debts
SET name = COALESCE(sqlc.narg('name'), name),
    total_amount = COALESCE(sqlc.narg('total_amount'), total_amount),
    monthly_payment = COALESCE(sqlc.narg('monthly_payment'), monthly_payment),
    interest_rate = COALESCE(sqlc.narg('interest_rate'), interest_rate),
    is_active = COALESCE(sqlc.narg('is_active'), is_active),
    notes = COALESCE(sqlc.narg('notes'), notes)
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeleteDebt :exec
DELETE FROM debts WHERE id = $1 AND user_id = $2;
```

- [ ] **Step 8: Create ai_conversations.sql queries**

Create `numia-api/internal/database/queries/ai_conversations.sql`:

```sql
-- name: ListConversations :many
SELECT id, user_id, title, message_count, created_at, updated_at
FROM ai_conversations
WHERE user_id = $1
ORDER BY updated_at DESC
LIMIT $2;

-- name: GetConversation :one
SELECT * FROM ai_conversations WHERE id = $1 AND user_id = $2;

-- name: CreateConversation :one
INSERT INTO ai_conversations (user_id, title)
VALUES ($1, sqlc.narg('title'))
RETURNING *;

-- name: UpdateConversationMessages :one
UPDATE ai_conversations
SET messages = $3,
    message_count = $4,
    title = COALESCE(sqlc.narg('title'), title)
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeleteConversation :exec
DELETE FROM ai_conversations WHERE id = $1 AND user_id = $2;
```

- [ ] **Step 9: Create dashboard.sql queries**

Create `numia-api/internal/database/queries/dashboard.sql`:

```sql
-- name: GetTotalAssets :one
SELECT COALESCE(SUM(balance), 0)::NUMERIC AS total_assets
FROM accounts
WHERE user_id = $1 AND is_active = TRUE;

-- name: GetTotalDebt :one
SELECT COALESCE(SUM(total_amount), 0)::NUMERIC AS total_debt
FROM debts
WHERE user_id = $1 AND is_active = TRUE;

-- name: GetActiveGoalsSummary :many
SELECT id, name, target_amount, current_amount, emoji
FROM goals
WHERE user_id = $1 AND status = 'active'
ORDER BY priority;

-- name: GetActiveDebtsSummary :many
SELECT id, name, total_amount, monthly_payment
FROM debts
WHERE user_id = $1 AND is_active = TRUE;

-- name: GetRecentTransactions :many
SELECT * FROM transactions
WHERE user_id = $1
ORDER BY value_date DESC
LIMIT $2;
```

- [ ] **Step 10: Generate sqlc code**

```bash
go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest
cd ~/Desktop/numia-api && sqlc generate
```

Expected: Creates files in `internal/database/sqlc/` (models.go, querier.go, db.go, *.sql.go)

- [ ] **Step 11: Commit**

```bash
git add -A && git commit -m "feat: sqlc queries and generated code for all tables"
```

---

### Task 4: Error Response Helper and Middleware

**Files:**
- Create: `numia-api/internal/middleware/errors.go`
- Create: `numia-api/internal/middleware/auth.go`
- Create: `numia-api/internal/middleware/cors.go`

- [ ] **Step 1: Create error response helper**

Create `numia-api/internal/middleware/errors.go`:

```go
package middleware

import "github.com/gin-gonic/gin"

type ErrorResponse struct {
	Error ErrorBody `json:"error"`
}

type ErrorBody struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func RespondError(c *gin.Context, status int, code string, message string) {
	c.JSON(status, ErrorResponse{
		Error: ErrorBody{Code: code, Message: message},
	})
}
```

- [ ] **Step 2: Create JWT auth middleware**

Create `numia-api/internal/middleware/auth.go`:

```go
package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

const UserIDKey = "user_id"

func AuthRequired(jwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if header == "" {
			RespondError(c, http.StatusUnauthorized, "UNAUTHORIZED", "Token requerido")
			c.Abort()
			return
		}

		parts := strings.SplitN(header, " ", 2)
		if len(parts) != 2 || parts[0] != "Bearer" {
			RespondError(c, http.StatusUnauthorized, "UNAUTHORIZED", "Formato de token inválido")
			c.Abort()
			return
		}

		token, err := jwt.Parse(parts[1], func(t *jwt.Token) (interface{}, error) {
			if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, jwt.ErrSignatureInvalid
			}
			return []byte(jwtSecret), nil
		})

		if err != nil || !token.Valid {
			RespondError(c, http.StatusUnauthorized, "UNAUTHORIZED", "Token inválido o expirado")
			c.Abort()
			return
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			RespondError(c, http.StatusUnauthorized, "UNAUTHORIZED", "Claims inválidos")
			c.Abort()
			return
		}

		userIDStr, ok := claims["user_id"].(string)
		if !ok {
			RespondError(c, http.StatusUnauthorized, "UNAUTHORIZED", "user_id no encontrado en token")
			c.Abort()
			return
		}

		userID, err := uuid.Parse(userIDStr)
		if err != nil {
			RespondError(c, http.StatusUnauthorized, "UNAUTHORIZED", "user_id inválido")
			c.Abort()
			return
		}

		c.Set(UserIDKey, userID)
		c.Next()
	}
}

func GetUserID(c *gin.Context) uuid.UUID {
	id, _ := c.Get(UserIDKey)
	return id.(uuid.UUID)
}
```

- [ ] **Step 3: Create CORS middleware**

Create `numia-api/internal/middleware/cors.go`:

```go
package middleware

import "github.com/gin-gonic/gin"

func CORS() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Authorization,Content-Type")
		c.Header("Access-Control-Max-Age", "86400")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	}
}
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: error helper, JWT auth middleware, and CORS"
```

---

### Task 5: Auth Feature (Register, Login, Refresh, Logout)

**Files:**
- Create: `numia-api/internal/auth/model.go`
- Create: `numia-api/internal/auth/service.go`
- Create: `numia-api/internal/auth/handler.go`
- Modify: `numia-api/cmd/api/main.go` (register routes)

- [ ] **Step 1: Create auth models**

Create `numia-api/internal/auth/model.go`:

```go
package auth

import "time"

type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
	FullName string `json:"full_name" binding:"required,min=2"`
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type RefreshRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

type LogoutRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

type AuthResponse struct {
	AccessToken  string   `json:"access_token"`
	RefreshToken string   `json:"refresh_token"`
	User         UserJSON `json:"user"`
}

type TokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

type UserJSON struct {
	ID             string     `json:"id"`
	Email          string     `json:"email"`
	FullName       string     `json:"full_name"`
	Country        string     `json:"country"`
	BirthDate      *string    `json:"birth_date"`
	Occupation     *string    `json:"occupation"`
	OnboardingDone bool       `json:"onboarding_done"`
	Plan           string     `json:"plan"`
	AvatarURL      *string    `json:"avatar_url"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
}
```

- [ ] **Step 2: Create auth service**

Create `numia-api/internal/auth/service.go`:

```go
package auth

import (
	"context"
	"errors"
	"time"

	"numia-api/internal/database/sqlc"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrInvalidCredentials = errors.New("correo o contraseña incorrectos")
	ErrEmailTaken         = errors.New("ya existe una cuenta con ese correo")
	ErrSessionExpired     = errors.New("sesión expirada")
)

type Service struct {
	queries   *sqlc.Queries
	jwtSecret string
}

func NewService(q *sqlc.Queries, jwtSecret string) *Service {
	return &Service{queries: q, jwtSecret: jwtSecret}
}

func (s *Service) Register(ctx context.Context, req RegisterRequest, userAgent, ip string) (*AuthResponse, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	user, err := s.queries.CreateUser(ctx, sqlc.CreateUserParams{
		Email:        req.Email,
		PasswordHash: string(hash),
		FullName:     req.FullName,
	})
	if err != nil {
		if isDuplicateKey(err) {
			return nil, ErrEmailTaken
		}
		return nil, err
	}

	return s.createAuthResponse(ctx, user, userAgent, ip)
}

func (s *Service) Login(ctx context.Context, req LoginRequest, userAgent, ip string) (*AuthResponse, error) {
	user, err := s.queries.GetUserByEmail(ctx, req.Email)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrInvalidCredentials
		}
		return nil, err
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, ErrInvalidCredentials
	}

	return s.createAuthResponse(ctx, user, userAgent, ip)
}

func (s *Service) Refresh(ctx context.Context, refreshToken, userAgent, ip string) (*TokenResponse, error) {
	session, err := s.queries.GetSessionByRefreshToken(ctx, refreshToken)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrSessionExpired
		}
		return nil, err
	}

	// Delete old session
	_ = s.queries.DeleteSession(ctx, refreshToken)

	// Create new session
	newRefresh := uuid.New().String()
	_, err = s.queries.CreateSession(ctx, sqlc.CreateSessionParams{
		UserID:       session.UserID,
		RefreshToken: newRefresh,
		UserAgent:    pgtype.Text{String: userAgent, Valid: userAgent != ""},
		IpAddress:    pgtype.Text{String: ip, Valid: ip != ""},
		ExpiresAt:    pgtype.Timestamptz{Time: time.Now().Add(30 * 24 * time.Hour), Valid: true},
	})
	if err != nil {
		return nil, err
	}

	accessToken, err := s.generateAccessToken(session.UserID)
	if err != nil {
		return nil, err
	}

	return &TokenResponse{AccessToken: accessToken, RefreshToken: newRefresh}, nil
}

func (s *Service) Logout(ctx context.Context, refreshToken string) error {
	return s.queries.DeleteSession(ctx, refreshToken)
}

func (s *Service) createAuthResponse(ctx context.Context, user sqlc.User, userAgent, ip string) (*AuthResponse, error) {
	accessToken, err := s.generateAccessToken(user.ID)
	if err != nil {
		return nil, err
	}

	refreshToken := uuid.New().String()
	_, err = s.queries.CreateSession(ctx, sqlc.CreateSessionParams{
		UserID:       user.ID,
		RefreshToken: refreshToken,
		UserAgent:    pgtype.Text{String: userAgent, Valid: userAgent != ""},
		IpAddress:    pgtype.Text{String: ip, Valid: ip != ""},
		ExpiresAt:    pgtype.Timestamptz{Time: time.Now().Add(30 * 24 * time.Hour), Valid: true},
	})
	if err != nil {
		return nil, err
	}

	return &AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		User:         toUserJSON(user),
	}, nil
}

func (s *Service) generateAccessToken(userID pgtype.UUID) (string, error) {
	uid := uuid.UUID(userID.Bytes)
	claims := jwt.MapClaims{
		"user_id": uid.String(),
		"iat":     time.Now().Unix(),
		"exp":     time.Now().Add(15 * time.Minute).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(s.jwtSecret))
}

func toUserJSON(u sqlc.User) UserJSON {
	uid := uuid.UUID(u.ID.Bytes)
	uj := UserJSON{
		ID:             uid.String(),
		Email:          u.Email,
		FullName:       u.FullName,
		Country:        u.Country,
		OnboardingDone: u.OnboardingDone,
		Plan:           u.Plan,
		CreatedAt:      u.CreatedAt.Time,
		UpdatedAt:      u.UpdatedAt.Time,
	}
	if u.BirthDate.Valid {
		s := u.BirthDate.Time.Format("2006-01-02")
		uj.BirthDate = &s
	}
	if u.Occupation.Valid {
		uj.Occupation = &u.Occupation.String
	}
	if u.AvatarUrl.Valid {
		uj.AvatarURL = &u.AvatarUrl.String
	}
	return uj
}

func isDuplicateKey(err error) bool {
	return err != nil && (errors.As(err, new(*pgx.PgError)) || containsDuplicate(err.Error()))
}

func containsDuplicate(s string) bool {
	return len(s) > 0 && (contains(s, "duplicate key") || contains(s, "unique constraint"))
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && searchString(s, substr)
}

func searchString(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
```

- [ ] **Step 3: Create auth handler**

Create `numia-api/internal/auth/handler.go`:

```go
package auth

import (
	"errors"
	"net/http"

	"numia-api/internal/middleware"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	service *Service
}

func NewHandler(s *Service) *Handler {
	return &Handler{service: s}
}

func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	auth := rg.Group("/auth")
	auth.POST("/register", h.register)
	auth.POST("/login", h.login)
	auth.POST("/refresh", h.refresh)
	auth.POST("/logout", h.logout)
}

func (h *Handler) register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", "Datos inválidos: email, password (min 6) y full_name requeridos")
		return
	}

	res, err := h.service.Register(c.Request.Context(), req, c.GetHeader("User-Agent"), c.ClientIP())
	if err != nil {
		if errors.Is(err, ErrEmailTaken) {
			middleware.RespondError(c, http.StatusConflict, "EMAIL_TAKEN", err.Error())
			return
		}
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "Error al crear cuenta")
		return
	}

	c.JSON(http.StatusCreated, res)
}

func (h *Handler) login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", "Email y password requeridos")
		return
	}

	res, err := h.service.Login(c.Request.Context(), req, c.GetHeader("User-Agent"), c.ClientIP())
	if err != nil {
		if errors.Is(err, ErrInvalidCredentials) {
			middleware.RespondError(c, http.StatusUnauthorized, "INVALID_CREDENTIALS", err.Error())
			return
		}
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "Error al iniciar sesión")
		return
	}

	c.JSON(http.StatusOK, res)
}

func (h *Handler) refresh(c *gin.Context) {
	var req RefreshRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", "refresh_token requerido")
		return
	}

	res, err := h.service.Refresh(c.Request.Context(), req.RefreshToken, c.GetHeader("User-Agent"), c.ClientIP())
	if err != nil {
		if errors.Is(err, ErrSessionExpired) {
			middleware.RespondError(c, http.StatusUnauthorized, "SESSION_EXPIRED", err.Error())
			return
		}
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "Error al renovar sesión")
		return
	}

	c.JSON(http.StatusOK, res)
}

func (h *Handler) logout(c *gin.Context) {
	var req LogoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", "refresh_token requerido")
		return
	}

	_ = h.service.Logout(c.Request.Context(), req.RefreshToken)
	c.Status(http.StatusNoContent)
}
```

- [ ] **Step 4: Wire auth routes into main.go**

Update `numia-api/cmd/api/main.go` to register auth routes. Replace the router setup section:

```go
package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"numia-api/internal/auth"
	"numia-api/internal/config"
	"numia-api/internal/database"
	"numia-api/internal/database/sqlc"
	"numia-api/internal/middleware"

	"github.com/gin-gonic/gin"
)

func main() {
	cfg := config.Load()

	if cfg.GinMode == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	db, err := database.Connect(cfg.DBURL)
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}
	defer db.Close()

	queries := sqlc.New(db.Pool)

	r := gin.Default()
	r.Use(middleware.CORS())

	// Health
	r.GET("/api/v1/health", func(c *gin.Context) {
		if err := db.Ping(c.Request.Context()); err != nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"status": "error", "db": "disconnected"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"status": "ok", "db": "connected"})
	})

	api := r.Group("/api/v1")

	// Auth (public)
	authService := auth.NewService(queries, cfg.JWTSecret)
	authHandler := auth.NewHandler(authService)
	authHandler.RegisterRoutes(api)

	// Protected routes will be added in subsequent tasks
	_ = api.Group("", middleware.AuthRequired(cfg.JWTSecret))

	srv := &http.Server{Addr: ":" + cfg.Port, Handler: r}

	go func() {
		log.Printf("API listening on :%s", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("shutting down...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("forced shutdown: %v", err)
	}
}
```

- [ ] **Step 5: Verify it compiles**

```bash
cd ~/Desktop/numia-api && go build ./...
```

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: auth feature with register, login, refresh, logout"
```

---

### Task 6: User Feature

**Files:**
- Create: `numia-api/internal/user/handler.go`
- Create: `numia-api/internal/user/service.go`
- Modify: `numia-api/cmd/api/main.go` (register user routes)

- [ ] **Step 1: Create user service**

Create `numia-api/internal/user/service.go`:

```go
package user

import (
	"context"

	"numia-api/internal/auth"
	"numia-api/internal/database/sqlc"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

type Service struct {
	queries *sqlc.Queries
}

func NewService(q *sqlc.Queries) *Service {
	return &Service{queries: q}
}

func (s *Service) GetProfile(ctx context.Context, userID uuid.UUID) (*auth.UserJSON, error) {
	pgID := pgtype.UUID{Bytes: userID, Valid: true}
	user, err := s.queries.GetUserByID(ctx, pgID)
	if err != nil {
		return nil, err
	}
	uj := auth.ToUserJSON(user)
	return &uj, nil
}

func (s *Service) UpdateProfile(ctx context.Context, userID uuid.UUID, fullName, avatarURL *string) (*auth.UserJSON, error) {
	pgID := pgtype.UUID{Bytes: userID, Valid: true}
	params := sqlc.UpdateUserProfileParams{ID: pgID}
	if fullName != nil {
		params.FullName = pgtype.Text{String: *fullName, Valid: true}
	}
	if avatarURL != nil {
		params.AvatarUrl = pgtype.Text{String: *avatarURL, Valid: true}
	}

	user, err := s.queries.UpdateUserProfile(ctx, params)
	if err != nil {
		return nil, err
	}
	uj := auth.ToUserJSON(user)
	return &uj, nil
}

func (s *Service) CompleteOnboarding(ctx context.Context, userID uuid.UUID, req OnboardingRequest) (*auth.UserJSON, error) {
	pgID := pgtype.UUID{Bytes: userID, Valid: true}
	params := sqlc.CompleteOnboardingParams{
		ID:       pgID,
		FullName: req.FullName,
		Country:  req.Country,
	}
	if req.BirthDate != nil {
		params.BirthDate = pgtype.Date{Time: *req.BirthDate, Valid: true}
	}
	if req.Occupation != nil {
		params.Occupation = pgtype.Text{String: *req.Occupation, Valid: true}
	}

	user, err := s.queries.CompleteOnboarding(ctx, params)
	if err != nil {
		return nil, err
	}
	uj := auth.ToUserJSON(user)
	return &uj, nil
}

type OnboardingRequest struct {
	FullName   string     `json:"full_name" binding:"required,min=2"`
	Country    string     `json:"country" binding:"required"`
	BirthDate  *time.Time `json:"birth_date"`
	Occupation *string    `json:"occupation"`
}
```

Note: also need to add `"time"` import and export `ToUserJSON` from auth package (rename `toUserJSON` → `ToUserJSON`).

- [ ] **Step 2: Create user handler**

Create `numia-api/internal/user/handler.go`:

```go
package user

import (
	"net/http"

	"numia-api/internal/middleware"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	service *Service
}

func NewHandler(s *Service) *Handler {
	return &Handler{service: s}
}

func (h *Handler) RegisterRoutes(protected *gin.RouterGroup) {
	users := protected.Group("/users")
	users.GET("/me", h.getProfile)
	users.PUT("/me", h.updateProfile)
	users.POST("/onboarding", h.completeOnboarding)
}

func (h *Handler) getProfile(c *gin.Context) {
	userID := middleware.GetUserID(c)
	user, err := h.service.GetProfile(c.Request.Context(), userID)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "Error al obtener perfil")
		return
	}
	c.JSON(http.StatusOK, user)
}

func (h *Handler) updateProfile(c *gin.Context) {
	var req struct {
		FullName  *string `json:"full_name"`
		AvatarURL *string `json:"avatar_url"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", "Datos inválidos")
		return
	}

	userID := middleware.GetUserID(c)
	user, err := h.service.UpdateProfile(c.Request.Context(), userID, req.FullName, req.AvatarURL)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "Error al actualizar perfil")
		return
	}
	c.JSON(http.StatusOK, user)
}

func (h *Handler) completeOnboarding(c *gin.Context) {
	var req OnboardingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", "full_name (min 2) y country requeridos")
		return
	}

	userID := middleware.GetUserID(c)
	user, err := h.service.CompleteOnboarding(c.Request.Context(), userID, req)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "Error al completar onboarding")
		return
	}
	c.JSON(http.StatusOK, user)
}
```

- [ ] **Step 3: Wire user routes in main.go**

Add to the protected group in `cmd/api/main.go`:

```go
	protected := api.Group("", middleware.AuthRequired(cfg.JWTSecret))

	userService := user.NewService(queries)
	userHandler := user.NewHandler(userService)
	userHandler.RegisterRoutes(protected)
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: user endpoints (profile, update, onboarding)"
```

---

### Task 7: Account Feature

**Files:**
- Create: `numia-api/internal/account/handler.go`
- Create: `numia-api/internal/account/service.go`
- Modify: `numia-api/cmd/api/main.go`

- [ ] **Step 1: Create account service**

Create `numia-api/internal/account/service.go`:

```go
package account

import (
	"context"
	"errors"

	"numia-api/internal/database/sqlc"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

var ErrNotFound = errors.New("cuenta no encontrada")

type Service struct {
	queries *sqlc.Queries
}

func NewService(q *sqlc.Queries) *Service {
	return &Service{queries: q}
}

func (s *Service) List(ctx context.Context, userID uuid.UUID) ([]sqlc.Account, error) {
	pgID := pgtype.UUID{Bytes: userID, Valid: true}
	return s.queries.ListAccountsByUser(ctx, pgID)
}

func (s *Service) Create(ctx context.Context, userID uuid.UUID, req CreateRequest) (sqlc.Account, error) {
	pgID := pgtype.UUID{Bytes: userID, Valid: true}
	currency := req.Currency
	if currency == "" {
		currency = "MXN"
	}
	params := sqlc.CreateAccountParams{
		UserID:   pgID,
		Name:     req.Name,
		Type:     pgtype.Text{String: req.Type, Valid: req.Type != ""},
		Currency: currency,
		Balance:  numericFromFloat(req.Balance),
	}
	if req.CreditLimit != nil {
		params.CreditLimit = numericFromFloatPtr(req.CreditLimit)
	}
	return s.queries.CreateAccount(ctx, params)
}

func (s *Service) Update(ctx context.Context, userID uuid.UUID, accountID uuid.UUID, req UpdateRequest) (sqlc.Account, error) {
	pgUID := pgtype.UUID{Bytes: userID, Valid: true}
	pgAID := pgtype.UUID{Bytes: accountID, Valid: true}
	params := sqlc.UpdateAccountParams{ID: pgAID, UserID: pgUID}
	if req.Name != nil {
		params.Name = pgtype.Text{String: *req.Name, Valid: true}
	}
	if req.Balance != nil {
		params.Balance = numericFromFloatPtr(req.Balance)
	}
	if req.IsActive != nil {
		params.IsActive = pgtype.Bool{Bool: *req.IsActive, Valid: true}
	}

	acc, err := s.queries.UpdateAccount(ctx, params)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return sqlc.Account{}, ErrNotFound
		}
		return sqlc.Account{}, err
	}
	return acc, nil
}

func (s *Service) Delete(ctx context.Context, userID, accountID uuid.UUID) error {
	pgUID := pgtype.UUID{Bytes: userID, Valid: true}
	pgAID := pgtype.UUID{Bytes: accountID, Valid: true}
	return s.queries.DeleteAccount(ctx, sqlc.DeleteAccountParams{ID: pgAID, UserID: pgUID})
}

type CreateRequest struct {
	Name        string   `json:"name" binding:"required"`
	Type        string   `json:"type"`
	Currency    string   `json:"currency"`
	Balance     float64  `json:"balance"`
	CreditLimit *float64 `json:"credit_limit"`
}

type UpdateRequest struct {
	Name     *string  `json:"name"`
	Balance  *float64 `json:"balance"`
	IsActive *bool    `json:"is_active"`
}

func numericFromFloat(f float64) pgtype.Numeric {
	var n pgtype.Numeric
	_ = n.Scan(fmt.Sprintf("%f", f))
	return n
}

func numericFromFloatPtr(f *float64) pgtype.Numeric {
	if f == nil {
		return pgtype.Numeric{}
	}
	return numericFromFloat(*f)
}
```

Note: add `"fmt"` import.

- [ ] **Step 2: Create account handler**

Create `numia-api/internal/account/handler.go`:

```go
package account

import (
	"errors"
	"net/http"

	"numia-api/internal/middleware"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type Handler struct {
	service *Service
}

func NewHandler(s *Service) *Handler {
	return &Handler{service: s}
}

func (h *Handler) RegisterRoutes(protected *gin.RouterGroup) {
	acc := protected.Group("/accounts")
	acc.GET("", h.list)
	acc.POST("", h.create)
	acc.PUT("/:id", h.update)
	acc.DELETE("/:id", h.delete)
}

func (h *Handler) list(c *gin.Context) {
	accounts, err := h.service.List(c.Request.Context(), middleware.GetUserID(c))
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "Error al obtener cuentas")
		return
	}
	c.JSON(http.StatusOK, accounts)
}

func (h *Handler) create(c *gin.Context) {
	var req CreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", "name requerido")
		return
	}
	acc, err := h.service.Create(c.Request.Context(), middleware.GetUserID(c), req)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "Error al crear cuenta")
		return
	}
	c.JSON(http.StatusCreated, acc)
}

func (h *Handler) update(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", "ID inválido")
		return
	}
	var req UpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", "Datos inválidos")
		return
	}
	acc, err := h.service.Update(c.Request.Context(), middleware.GetUserID(c), id, req)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			middleware.RespondError(c, http.StatusNotFound, "NOT_FOUND", err.Error())
			return
		}
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "Error al actualizar cuenta")
		return
	}
	c.JSON(http.StatusOK, acc)
}

func (h *Handler) delete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", "ID inválido")
		return
	}
	_ = h.service.Delete(c.Request.Context(), middleware.GetUserID(c), id)
	c.Status(http.StatusNoContent)
}
```

- [ ] **Step 3: Wire in main.go, verify compile**

Add to protected group:
```go
	accountService := account.NewService(queries)
	accountHandler := account.NewHandler(accountService)
	accountHandler.RegisterRoutes(protected)
```

```bash
cd ~/Desktop/numia-api && go build ./...
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: account CRUD endpoints"
```

---

### Task 8: Transaction Feature

**Files:**
- Create: `numia-api/internal/transaction/handler.go`
- Create: `numia-api/internal/transaction/service.go`
- Modify: `numia-api/cmd/api/main.go`

The pattern is identical to accounts. Service wraps sqlc queries, handler parses requests and calls service.

- [ ] **Step 1: Create transaction service**

Create `numia-api/internal/transaction/service.go` with methods: `List`, `Create`, `Update`, `Delete`, `GetMonthlySummary`, `GetCategoryBreakdown`. Each method converts request params to sqlc params and calls the corresponding query.

Key details:
- `List` accepts optional `category`, `limit` (default 50), `offset` (default 0)
- `GetMonthlySummary` and `GetCategoryBreakdown` accept a `month` string (default current month), parsed as `time.Time` first day of month
- Uses same `numericFromFloat` helper pattern as account service

- [ ] **Step 2: Create transaction handler**

Create `numia-api/internal/transaction/handler.go` with routes:
```
GET    /transactions              → list
POST   /transactions              → create
PUT    /transactions/:id          → update
DELETE /transactions/:id          → delete
GET    /transactions/summary      → monthlySummary
GET    /transactions/categories   → categoryBreakdown
```

Note: register `/transactions/summary` and `/transactions/categories` BEFORE `/:id` to avoid route conflicts.

- [ ] **Step 3: Wire in main.go, verify compile, commit**

```bash
git add -A && git commit -m "feat: transaction CRUD + summary + categories endpoints"
```

---

### Task 9: Goal Feature

**Files:**
- Create: `numia-api/internal/goal/handler.go`
- Create: `numia-api/internal/goal/service.go`
- Modify: `numia-api/cmd/api/main.go`

- [ ] **Step 1: Create goal service**

Methods: `List` (optional status filter), `Create`, `Update`, `AddContribution`, `Delete`.
- `AddContribution` uses the `AddContribution` sqlc query which atomically increments `current_amount`

- [ ] **Step 2: Create goal handler**

Routes:
```
GET    /goals                → list
POST   /goals                → create
PUT    /goals/:id            → update
POST   /goals/:id/contribute → addContribution
DELETE /goals/:id            → delete
```

- [ ] **Step 3: Wire in main.go, verify compile, commit**

```bash
git add -A && git commit -m "feat: goal CRUD + contribute endpoints"
```

---

### Task 10: Debt Feature

**Files:**
- Create: `numia-api/internal/debt/handler.go`
- Create: `numia-api/internal/debt/service.go`
- Modify: `numia-api/cmd/api/main.go`

- [ ] **Step 1: Create debt service**

Methods: `List` (optional `active` filter), `Create`, `Update`, `Delete`.

- [ ] **Step 2: Create debt handler**

Routes:
```
GET    /debts      → list
POST   /debts      → create
PUT    /debts/:id  → update
DELETE /debts/:id  → delete
```

- [ ] **Step 3: Wire in main.go, verify compile, commit**

```bash
git add -A && git commit -m "feat: debt CRUD endpoints"
```

---

### Task 11: Dashboard Feature

**Files:**
- Create: `numia-api/internal/dashboard/handler.go`
- Create: `numia-api/internal/dashboard/service.go`
- Modify: `numia-api/cmd/api/main.go`

- [ ] **Step 1: Create dashboard service**

Create `numia-api/internal/dashboard/service.go`:

```go
package dashboard

import (
	"context"
	"time"

	"numia-api/internal/database/sqlc"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

type Service struct {
	queries *sqlc.Queries
}

func NewService(q *sqlc.Queries) *Service {
	return &Service{queries: q}
}

type Summary struct {
	NetWorth       NetWorth       `json:"net_worth"`
	MonthlySummary MonthlySummary `json:"monthly_summary"`
	ActiveGoals    []GoalSummary  `json:"active_goals"`
	ActiveDebts    []DebtSummary  `json:"active_debts"`
}

type NetWorth struct {
	TotalAssets float64 `json:"total_assets"`
	TotalDebt   float64 `json:"total_debt"`
	NetWorth    float64 `json:"net_worth"`
}

type MonthlySummary struct {
	Income   float64 `json:"income"`
	Expenses float64 `json:"expenses"`
	Net      float64 `json:"net"`
	TxCount  int64   `json:"tx_count"`
}

type GoalSummary struct {
	ID            string  `json:"id"`
	Name          string  `json:"name"`
	TargetAmount  float64 `json:"target_amount"`
	CurrentAmount float64 `json:"current_amount"`
	Emoji         *string `json:"emoji"`
}

type DebtSummary struct {
	ID             string   `json:"id"`
	Name           string   `json:"name"`
	TotalAmount    float64  `json:"total_amount"`
	MonthlyPayment *float64 `json:"monthly_payment"`
}

func (s *Service) GetSummary(ctx context.Context, userID uuid.UUID) (*Summary, error) {
	pgID := pgtype.UUID{Bytes: userID, Valid: true}
	now := time.Now()
	month := pgtype.Date{Time: time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC), Valid: true}

	assets, _ := s.queries.GetTotalAssets(ctx, pgID)
	debt, _ := s.queries.GetTotalDebt(ctx, pgID)
	monthly, _ := s.queries.GetMonthlySummary(ctx, sqlc.GetMonthlySummaryParams{UserID: pgID, ValueDate: month})
	goals, _ := s.queries.GetActiveGoalsSummary(ctx, pgID)
	debts, _ := s.queries.GetActiveDebtsSummary(ctx, pgID)

	assetsF := numericToFloat(assets)
	debtF := numericToFloat(debt)

	summary := &Summary{
		NetWorth: NetWorth{
			TotalAssets: assetsF,
			TotalDebt:   debtF,
			NetWorth:    assetsF - debtF,
		},
		MonthlySummary: MonthlySummary{
			Income:   numericToFloat(monthly.Income),
			Expenses: numericToFloat(monthly.Expenses),
			Net:      numericToFloat(monthly.Net),
			TxCount:  monthly.TxCount,
		},
		ActiveGoals: make([]GoalSummary, 0, len(goals)),
		ActiveDebts: make([]DebtSummary, 0, len(debts)),
	}

	for _, g := range goals {
		gs := GoalSummary{
			ID:            uuid.UUID(g.ID.Bytes).String(),
			Name:          g.Name,
			TargetAmount:  numericToFloat(g.TargetAmount),
			CurrentAmount: numericToFloat(g.CurrentAmount),
		}
		if g.Emoji.Valid {
			gs.Emoji = &g.Emoji.String
		}
		summary.ActiveGoals = append(summary.ActiveGoals, gs)
	}

	for _, d := range debts {
		ds := DebtSummary{
			ID:          uuid.UUID(d.ID.Bytes).String(),
			Name:        d.Name,
			TotalAmount: numericToFloat(d.TotalAmount),
		}
		if d.MonthlyPayment.Valid {
			mp := numericToFloat(d.MonthlyPayment)
			ds.MonthlyPayment = &mp
		}
		summary.ActiveDebts = append(summary.ActiveDebts, ds)
	}

	return summary, nil
}

func numericToFloat(n pgtype.Numeric) float64 {
	f, _ := n.Float64Value()
	return f.Float64
}
```

- [ ] **Step 2: Create dashboard handler**

Create `numia-api/internal/dashboard/handler.go`:

```go
package dashboard

import (
	"net/http"

	"numia-api/internal/middleware"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	service *Service
}

func NewHandler(s *Service) *Handler {
	return &Handler{service: s}
}

func (h *Handler) RegisterRoutes(protected *gin.RouterGroup) {
	protected.GET("/dashboard/summary", h.getSummary)
}

func (h *Handler) getSummary(c *gin.Context) {
	summary, err := h.service.GetSummary(c.Request.Context(), middleware.GetUserID(c))
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "Error al obtener resumen")
		return
	}
	c.JSON(http.StatusOK, summary)
}
```

- [ ] **Step 3: Wire in main.go, verify compile, commit**

```bash
git add -A && git commit -m "feat: dashboard summary endpoint"
```

---

### Task 12: Coach Feature (Groq SSE Streaming)

**Files:**
- Create: `numia-api/internal/coach/model.go`
- Create: `numia-api/internal/coach/groq.go`
- Create: `numia-api/internal/coach/service.go`
- Create: `numia-api/internal/coach/handler.go`
- Modify: `numia-api/cmd/api/main.go`

- [ ] **Step 1: Create coach models**

Create `numia-api/internal/coach/model.go`:

```go
package coach

import "time"

type ChatRequest struct {
	ConversationID *string `json:"conversation_id"`
	Message        string  `json:"message" binding:"required"`
}

type ConversationListItem struct {
	ID           string    `json:"id"`
	Title        *string   `json:"title"`
	MessageCount int32     `json:"message_count"`
	UpdatedAt    time.Time `json:"updated_at"`
}

type MessageJSON struct {
	Role      string    `json:"role"`
	Content   string    `json:"content"`
	Timestamp time.Time `json:"timestamp"`
}
```

- [ ] **Step 2: Create Groq client**

Create `numia-api/internal/coach/groq.go`:

```go
package coach

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
)

const (
	groqURL   = "https://api.groq.com/openai/v1/chat/completions"
	groqModel = "llama-3.3-70b-versatile"
)

type GroqClient struct {
	apiKey string
	client *http.Client
}

func NewGroqClient(apiKey string) *GroqClient {
	return &GroqClient{apiKey: apiKey, client: &http.Client{}}
}

type groqMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

func (g *GroqClient) StreamChat(ctx context.Context, messages []groqMessage, onToken func(string), onDone func(fullResponse string)) error {
	body, _ := json.Marshal(map[string]interface{}{
		"model":       groqModel,
		"messages":    messages,
		"stream":      true,
		"temperature": 0.7,
		"max_tokens":  1024,
	})

	req, err := http.NewRequestWithContext(ctx, "POST", groqURL, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+g.apiKey)

	resp, err := g.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		b, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("groq API error %d: %s", resp.StatusCode, string(b))
	}

	var full strings.Builder
	scanner := bufio.NewScanner(resp.Body)
	for scanner.Scan() {
		line := scanner.Text()
		if !strings.HasPrefix(line, "data: ") {
			continue
		}
		data := strings.TrimPrefix(line, "data: ")
		if data == "[DONE]" {
			break
		}
		var chunk struct {
			Choices []struct {
				Delta struct {
					Content string `json:"content"`
				} `json:"delta"`
			} `json:"choices"`
		}
		if err := json.Unmarshal([]byte(data), &chunk); err != nil {
			continue
		}
		if len(chunk.Choices) > 0 && chunk.Choices[0].Delta.Content != "" {
			token := chunk.Choices[0].Delta.Content
			full.WriteString(token)
			onToken(token)
		}
	}

	onDone(full.String())
	return nil
}
```

- [ ] **Step 3: Create coach service**

Create `numia-api/internal/coach/service.go`:

```go
package coach

import (
	"context"
	"encoding/json"
	"time"

	"numia-api/internal/database/sqlc"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

const systemPrompt = `Eres numia, un coach financiero personal con IA para México. Tu personalidad es amigable, directa y motivadora. Respondes en español mexicano de forma concisa (máx 3 párrafos). Ayudas con: presupuesto, ahorro, deudas, inversiones y metas financieras. Siempre consideras el contexto mexicano (pesos MXN, SAT, AFORE, CETES, etc). Si no tienes datos suficientes, pide información específica. Usa formato limpio, no markdown pesado.`

type Service struct {
	queries *sqlc.Queries
	groq    *GroqClient
}

func NewService(q *sqlc.Queries, groq *GroqClient) *Service {
	return &Service{queries: q, groq: groq}
}

func (s *Service) Chat(ctx context.Context, userID uuid.UUID, req ChatRequest, onToken func(string)) (string, string, error) {
	pgID := pgtype.UUID{Bytes: userID, Valid: true}

	// Get or create conversation
	var convID pgtype.UUID
	var existingMessages []MessageJSON

	if req.ConversationID != nil {
		parsed, err := uuid.Parse(*req.ConversationID)
		if err == nil {
			convID = pgtype.UUID{Bytes: parsed, Valid: true}
			conv, err := s.queries.GetConversation(ctx, sqlc.GetConversationParams{ID: convID, UserID: pgID})
			if err == nil {
				_ = json.Unmarshal(conv.Messages, &existingMessages)
			}
		}
	}

	if !convID.Valid {
		conv, err := s.queries.CreateConversation(ctx, sqlc.CreateConversationParams{UserID: pgID})
		if err != nil {
			return "", "", err
		}
		convID = conv.ID
	}

	// Build financial context
	financialCtx := s.buildFinancialContext(ctx, pgID)

	// Build messages for Groq
	groqMessages := []groqMessage{
		{Role: "system", Content: systemPrompt + "\n\nContexto financiero del usuario:\n" + financialCtx},
	}
	for _, m := range existingMessages {
		groqMessages = append(groqMessages, groqMessage{Role: m.Role, Content: m.Content})
	}
	groqMessages = append(groqMessages, groqMessage{Role: "user", Content: req.Message})

	// Stream
	var fullResponse string
	err := s.groq.StreamChat(ctx, groqMessages, onToken, func(resp string) {
		fullResponse = resp
	})
	if err != nil {
		return uuid.UUID(convID.Bytes).String(), "", err
	}

	// Save messages
	now := time.Now()
	existingMessages = append(existingMessages,
		MessageJSON{Role: "user", Content: req.Message, Timestamp: now},
		MessageJSON{Role: "assistant", Content: fullResponse, Timestamp: now},
	)
	messagesJSON, _ := json.Marshal(existingMessages)

	_, _ = s.queries.UpdateConversationMessages(ctx, sqlc.UpdateConversationMessagesParams{
		ID:           convID,
		UserID:       pgID,
		Messages:     messagesJSON,
		MessageCount: int32(len(existingMessages)),
	})

	return uuid.UUID(convID.Bytes).String(), fullResponse, nil
}

func (s *Service) buildFinancialContext(ctx context.Context, userID pgtype.UUID) string {
	accounts, _ := s.queries.ListAccountsByUser(ctx, userID)
	goals, _ := s.queries.GetActiveGoalsSummary(ctx, userID)
	debts, _ := s.queries.GetActiveDebtsSummary(ctx, userID)
	txs, _ := s.queries.GetRecentTransactions(ctx, sqlc.GetRecentTransactionsParams{UserID: userID, Limit: 10})

	data := map[string]interface{}{
		"accounts":     accounts,
		"goals":        goals,
		"debts":        debts,
		"recent_transactions": txs,
	}
	b, _ := json.Marshal(data)
	return string(b)
}

func (s *Service) ListConversations(ctx context.Context, userID uuid.UUID, limit int32) ([]ConversationListItem, error) {
	pgID := pgtype.UUID{Bytes: userID, Valid: true}
	convs, err := s.queries.ListConversations(ctx, sqlc.ListConversationsParams{UserID: pgID, Limit: limit})
	if err != nil {
		return nil, err
	}
	result := make([]ConversationListItem, 0, len(convs))
	for _, c := range convs {
		item := ConversationListItem{
			ID:           uuid.UUID(c.ID.Bytes).String(),
			MessageCount: c.MessageCount,
			UpdatedAt:    c.UpdatedAt.Time,
		}
		if c.Title.Valid {
			item.Title = &c.Title.String
		}
		result = append(result, item)
	}
	return result, nil
}

func (s *Service) GetConversation(ctx context.Context, userID, convID uuid.UUID) (*sqlc.AiConversation, error) {
	pgUID := pgtype.UUID{Bytes: userID, Valid: true}
	pgCID := pgtype.UUID{Bytes: convID, Valid: true}
	conv, err := s.queries.GetConversation(ctx, sqlc.GetConversationParams{ID: pgCID, UserID: pgUID})
	if err != nil {
		return nil, err
	}
	return &conv, nil
}

func (s *Service) DeleteConversation(ctx context.Context, userID, convID uuid.UUID) error {
	pgUID := pgtype.UUID{Bytes: userID, Valid: true}
	pgCID := pgtype.UUID{Bytes: convID, Valid: true}
	return s.queries.DeleteConversation(ctx, sqlc.DeleteConversationParams{ID: pgCID, UserID: pgUID})
}
```

- [ ] **Step 4: Create coach handler with SSE**

Create `numia-api/internal/coach/handler.go`:

```go
package coach

import (
	"encoding/json"
	"fmt"
	"net/http"

	"numia-api/internal/middleware"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type Handler struct {
	service *Service
}

func NewHandler(s *Service) *Handler {
	return &Handler{service: s}
}

func (h *Handler) RegisterRoutes(protected *gin.RouterGroup) {
	coach := protected.Group("/coach")
	coach.POST("/chat", h.chat)
	coach.GET("/conversations", h.listConversations)
	coach.GET("/conversations/:id", h.getConversation)
	coach.DELETE("/conversations/:id", h.deleteConversation)
}

func (h *Handler) chat(c *gin.Context) {
	var req ChatRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", "message requerido")
		return
	}

	c.Header("Content-Type", "text/event-stream")
	c.Header("Cache-Control", "no-cache")
	c.Header("Connection", "keep-alive")

	userID := middleware.GetUserID(c)
	flusher, _ := c.Writer.(http.Flusher)

	convID, _, err := h.service.Chat(c.Request.Context(), userID, req, func(token string) {
		data, _ := json.Marshal(map[string]string{"token": token})
		fmt.Fprintf(c.Writer, "data: %s\n\n", data)
		if flusher != nil {
			flusher.Flush()
		}
	})

	if err != nil {
		errData, _ := json.Marshal(map[string]string{"error": err.Error()})
		fmt.Fprintf(c.Writer, "data: %s\n\n", errData)
	}

	doneData, _ := json.Marshal(map[string]string{"conversation_id": convID})
	fmt.Fprintf(c.Writer, "data: [DONE] %s\n\n", doneData)
	if flusher != nil {
		flusher.Flush()
	}
}

func (h *Handler) listConversations(c *gin.Context) {
	convs, err := h.service.ListConversations(c.Request.Context(), middleware.GetUserID(c), 20)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "Error al obtener conversaciones")
		return
	}
	c.JSON(http.StatusOK, convs)
}

func (h *Handler) getConversation(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", "ID inválido")
		return
	}
	conv, err := h.service.GetConversation(c.Request.Context(), middleware.GetUserID(c), id)
	if err != nil {
		middleware.RespondError(c, http.StatusNotFound, "NOT_FOUND", "Conversación no encontrada")
		return
	}
	c.JSON(http.StatusOK, conv)
}

func (h *Handler) deleteConversation(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", "ID inválido")
		return
	}
	_ = h.service.DeleteConversation(c.Request.Context(), middleware.GetUserID(c), id)
	c.Status(http.StatusNoContent)
}
```

- [ ] **Step 5: Wire in main.go, verify compile, commit**

```go
	groqClient := coach.NewGroqClient(cfg.GroqAPIKey)
	coachService := coach.NewService(queries, groqClient)
	coachHandler := coach.NewHandler(coachService)
	coachHandler.RegisterRoutes(protected)
```

```bash
git add -A && git commit -m "feat: coach AI with Groq SSE streaming and conversations"
```

---

### Task 13: Docker Setup

**Files:**
- Create: `numia-api/Dockerfile`
- Create: `numia-api/docker-compose.yml`
- Create: `numia-api/Caddyfile`
- Create: `numia-api/.env.example`

- [ ] **Step 1: Create Dockerfile**

Create `numia-api/Dockerfile`:

```dockerfile
FROM golang:1.23-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /api ./cmd/api

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata
COPY --from=builder /api /api
EXPOSE 8080
CMD ["/api"]
```

- [ ] **Step 2: Create docker-compose.yml**

Create `numia-api/docker-compose.yml`:

```yaml
services:
  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "127.0.0.1:5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 5s
      timeout: 3s
      retries: 5

  migrate:
    image: migrate/migrate
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - ./internal/database/migrations:/migrations
    command: [
      "-path", "/migrations",
      "-database", "postgres://${DB_USER}:${DB_PASSWORD}@db:5432/${DB_NAME}?sslmode=disable",
      "up"
    ]

  api:
    build: .
    restart: unless-stopped
    depends_on:
      migrate:
        condition: service_completed_successfully
    environment:
      - DB_URL=postgres://${DB_USER}:${DB_PASSWORD}@db:5432/${DB_NAME}?sslmode=disable
      - JWT_SECRET=${JWT_SECRET}
      - GROQ_API_KEY=${GROQ_API_KEY}
      - GIN_MODE=release
      - PORT=8080
    ports:
      - "127.0.0.1:8080:8080"

  caddy:
    image: caddy:2-alpine
    restart: unless-stopped
    depends_on:
      - api
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data

volumes:
  pgdata:
  caddy_data:
```

- [ ] **Step 3: Create Caddyfile**

Create `numia-api/Caddyfile`:

```
:80 {
    reverse_proxy api:8080
}
```

- [ ] **Step 4: Create .env.example**

Create `numia-api/.env.example`:

```env
DB_USER=numia
DB_PASSWORD=change_me_in_production
DB_NAME=numia
JWT_SECRET=change-me-must-be-at-least-64-characters-long-for-hs256-security
GROQ_API_KEY=gsk_your_groq_api_key_here
```

- [ ] **Step 5: Test full stack locally**

```bash
cd ~/Desktop/numia-api
cp .env.example .env  # Edit with real values
docker compose up --build
# In another terminal:
curl http://localhost/api/v1/health
```

Expected: `{"status":"ok","db":"connected"}`

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: Docker setup with Compose, Caddy, and multi-stage build"
```

---

## Phase 2: Flutter Client Migration

### Task 14: New Core Files (API Client + Token Storage)

**Files:**
- Create: `numia/lib/core/api_client.dart`
- Create: `numia/lib/core/token_storage.dart`
- Modify: `numia/.env`
- Modify: `numia/pubspec.yaml`

- [ ] **Step 1: Update pubspec.yaml — remove supabase, keep dio**

In `numia/pubspec.yaml`, remove `supabase_flutter: ^2.5.0`. Dio is already present.

- [ ] **Step 2: Update .env**

Replace contents of `numia/.env`:

```env
API_BASE_URL=http://YOUR_VPS_IP
```

- [ ] **Step 3: Create token storage**

Create `numia/lib/core/token_storage.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, accessToken);
    await prefs.setString(_refreshKey, refreshToken);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshKey);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }

  Future<bool> hasTokens() async {
    final token = await getAccessToken();
    return token != null;
  }
}
```

- [ ] **Step 4: Create API client with interceptors**

Create `numia/lib/core/api_client.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient(this._tokenStorage) {
    _dio = Dio(BaseOptions(
      baseUrl: dotenv.env['API_BASE_URL'] ?? 'http://localhost',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokenStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await _tryRefresh();
          if (refreshed) {
            // Retry original request
            final opts = error.requestOptions;
            final token = await _tokenStorage.getAccessToken();
            opts.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await _dio.fetch(opts);
              handler.resolve(response);
              return;
            } catch (e) {
              handler.next(error);
              return;
            }
          }
          await _tokenStorage.clearTokens();
        }
        handler.next(error);
      },
    ));
  }

  final TokenStorage _tokenStorage;
  late final Dio _dio;

  Dio get dio => _dio;

  Future<bool> _tryRefresh() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await Dio(BaseOptions(
        baseUrl: dotenv.env['API_BASE_URL'] ?? 'http://localhost',
      )).post('/api/v1/auth/refresh', data: {
        'refresh_token': refreshToken,
      });

      await _tokenStorage.saveTokens(
        response.data['access_token'],
        response.data['refresh_token'],
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
```

- [ ] **Step 5: Commit**

```bash
cd ~/Desktop/numia && git add -A && git commit -m "feat: API client with token storage and refresh interceptor"
```

---

### Task 15: Rewrite Providers and Router

**Files:**
- Delete: `numia/lib/core/supabase_client.dart`
- Delete: `numia/lib/core/groq_client.dart`
- Rewrite: `numia/lib/core/providers.dart`
- Rewrite: `numia/lib/app/router.dart`
- Rewrite: `numia/lib/main.dart`

- [ ] **Step 1: Delete Supabase and Groq client files**

Delete `lib/core/supabase_client.dart` and `lib/core/groq_client.dart`.

- [ ] **Step 2: Rewrite providers.dart**

Replace `numia/lib/core/providers.dart` with version that uses ApiClient instead of Supabase. Key changes:
- `apiClientProvider` replaces `supabaseProvider`
- `tokenStorageProvider` new
- `authStateProvider` based on token presence (StateProvider<bool>)
- All repository providers receive `ApiClient` instead of `SupabaseClient`
- Data providers use Dio-based repositories

- [ ] **Step 3: Rewrite router.dart**

Replace auth guards: check `tokenStorage.hasTokens()` instead of `Supabase.instance.client.auth.currentSession`. Remove `skipAuth` flag (or keep for demo mode).

- [ ] **Step 4: Rewrite main.dart**

Remove `initSupabase()`, keep `dotenv.load()`. The `ApiClient` initializes lazily via providers.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: rewrite providers and router for custom API backend"
```

---

### Task 16: Rewrite Auth Screens

**Files:**
- Rewrite: `numia/lib/features/auth/presentation/login_screen.dart`
- Rewrite: `numia/lib/features/auth/presentation/register_screen.dart`

- [ ] **Step 1: Update login_screen.dart**

Replace `supabase.auth.signInWithPassword(...)` with:
```dart
final res = await ref.read(apiClientProvider).dio.post('/api/v1/auth/login', data: {
  'email': _emailCtrl.text.trim(),
  'password': _passCtrl.text,
});
await ref.read(tokenStorageProvider).saveTokens(
  res.data['access_token'],
  res.data['refresh_token'],
);
ref.read(authStateProvider.notifier).state = true;
```

Remove `import '../../../core/supabase_client.dart'`.

- [ ] **Step 2: Update register_screen.dart**

Replace `supabase.auth.signUp(...)` with:
```dart
final res = await ref.read(apiClientProvider).dio.post('/api/v1/auth/register', data: {
  'email': _emailCtrl.text.trim(),
  'password': _passCtrl.text,
  'full_name': _emailCtrl.text.split('@').first, // or a name field
});
await ref.read(tokenStorageProvider).saveTokens(
  res.data['access_token'],
  res.data['refresh_token'],
);
```

Since our API auto-logs-in on register (no email confirmation), navigate directly to `/` instead of showing confirmation screen.

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: rewrite auth screens for custom API"
```

---

### Task 17: Rewrite All Repositories

**Files:**
- Rewrite: `numia/lib/features/auth/data/user_repository.dart`
- Rewrite: `numia/lib/features/dashboard/data/dashboard_repository.dart`
- Rewrite: `numia/lib/features/transactions/data/transaction_repository.dart`
- Rewrite: `numia/lib/features/goals/data/goal_repository.dart`
- Rewrite: `numia/lib/features/coach/data/conversation_repository.dart`

- [ ] **Step 1: Rewrite user_repository.dart**

Change constructor to accept `ApiClient` instead of `SupabaseClient`. Replace all Supabase calls with Dio:
```dart
class UserRepository {
  UserRepository(this._api);
  final ApiClient _api;

  Future<UserProfile?> getProfile() async {
    final res = await _api.dio.get('/api/v1/users/me');
    return UserProfile.fromJson(res.data);
  }

  Future<void> updateProfile({String? fullName, String? avatarUrl}) async {
    await _api.dio.put('/api/v1/users/me', data: {
      if (fullName != null) 'full_name': fullName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    });
  }

  Future<void> completeOnboarding({
    required String fullName,
    String country = 'MX',
    DateTime? birthDate,
    String? occupation,
  }) async {
    await _api.dio.post('/api/v1/users/onboarding', data: {
      'full_name': fullName,
      'country': country,
      if (birthDate != null) 'birth_date': birthDate.toIso8601String().split('T').first,
      if (occupation != null) 'occupation': occupation,
    });
  }
}
```

- [ ] **Step 2: Rewrite dashboard_repository.dart**

Same pattern — `_api.dio.get('/api/v1/dashboard/summary')`, `_api.dio.get('/api/v1/accounts')`, etc.

- [ ] **Step 3: Rewrite transaction_repository.dart**

Same pattern — all Supabase `.from('transactions')` calls become `_api.dio.get/post/put/delete('/api/v1/transactions')`.

- [ ] **Step 4: Rewrite goal_repository.dart**

Same pattern. `addContribution` becomes `_api.dio.post('/api/v1/goals/$goalId/contribute', data: {'amount': amount})`.

- [ ] **Step 5: Rewrite conversation_repository.dart**

Same pattern. Remove `getFinancialContext()` (now handled server-side).

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: rewrite all repositories from Supabase to Dio"
```

---

### Task 18: Rewrite Coach Screen

**Files:**
- Modify: `numia/lib/features/coach/presentation/coach_screen.dart`

- [ ] **Step 1: Replace Groq streaming with API SSE**

Replace the `_send()` method. Instead of calling `GroqClient.instance.chatStream(...)`, make a POST to `/api/v1/coach/chat` with `ResponseType.stream` and parse SSE events:

```dart
final response = await ref.read(apiClientProvider).dio.post(
  '/api/v1/coach/chat',
  data: {'conversation_id': _conversationId, 'message': text},
  options: Options(responseType: ResponseType.stream),
);

final stream = (response.data as ResponseBody).stream;
await for (final chunk in stream) {
  final lines = utf8.decode(chunk).split('\n');
  for (final line in lines) {
    if (!line.startsWith('data: ')) continue;
    final data = line.substring(6);
    if (data.startsWith('[DONE]')) { /* extract conversation_id */ break; }
    final json = jsonDecode(data);
    if (json['token'] != null) {
      setState(() { /* append token to current message */ });
    }
  }
}
```

Remove import of `groq_client.dart`.

- [ ] **Step 2: Commit**

```bash
git add -A && git commit -m "feat: coach screen uses backend SSE instead of direct Groq"
```

---

### Task 19: Rewrite Profile Screen and Onboarding Notifier

**Files:**
- Modify: `numia/lib/features/profile/presentation/profile_screen.dart`
- Modify: `numia/lib/features/onboarding/presentation/onboarding_notifier.dart`

- [ ] **Step 1: Update profile_screen.dart logout**

Replace:
```dart
await supabase.auth.signOut();
```
With:
```dart
final refreshToken = await ref.read(tokenStorageProvider).getRefreshToken();
if (refreshToken != null) {
  try {
    await ref.read(apiClientProvider).dio.post('/api/v1/auth/logout', data: {
      'refresh_token': refreshToken,
    });
  } catch (_) {}
}
await ref.read(tokenStorageProvider).clearTokens();
ref.read(authStateProvider.notifier).state = false;
```

Remove `import '../../../core/supabase_client.dart'`.

- [ ] **Step 2: Update onboarding_notifier.dart**

No changes needed beyond what providers.dart already handles — the `userRepositoryProvider` now returns a Dio-based repository. Just verify it still calls `_ref.read(userRepositoryProvider).completeOnboarding(...)` which now hits the API.

- [ ] **Step 3: Verify Flutter compiles**

```bash
cd ~/Desktop/numia && flutter analyze
```

Fix any remaining import errors or type mismatches.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: migrate profile logout and verify full Flutter compilation"
```

---

### Task 20: Cleanup and Final Verification

- [ ] **Step 1: Search for any remaining Supabase references**

```bash
grep -r "supabase" lib/ --include="*.dart" -l
```

Expected: no results. If any remain, remove/replace them.

- [ ] **Step 2: Verify Go backend compiles and starts**

```bash
cd ~/Desktop/numia-api && go build ./... && docker compose up --build -d
curl http://localhost/api/v1/health
```

- [ ] **Step 3: Test auth flow end-to-end**

```bash
# Register
curl -X POST http://localhost/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123","full_name":"Test User"}'

# Login
curl -X POST http://localhost/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123"}'

# Use access_token from login response for protected endpoints
curl http://localhost/api/v1/users/me \
  -H "Authorization: Bearer ACCESS_TOKEN_HERE"

curl http://localhost/api/v1/dashboard/summary \
  -H "Authorization: Bearer ACCESS_TOKEN_HERE"
```

- [ ] **Step 4: Run Flutter app and test against backend**

```bash
cd ~/Desktop/numia && flutter run
```

Verify: register → onboarding → dashboard → coach chat → profile logout → login again.

- [ ] **Step 5: Final commit**

```bash
git add -A && git commit -m "chore: cleanup remaining Supabase references, migration complete"
```
