-- 000001_initial_schema.up.sql

-- Users table
CREATE TABLE users (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    email         TEXT        UNIQUE NOT NULL,
    password_hash TEXT        NOT NULL,
    full_name     TEXT        NOT NULL,
    country       TEXT        NOT NULL DEFAULT 'MX',
    birth_date    DATE,
    occupation    TEXT,
    onboarding_done BOOLEAN   NOT NULL DEFAULT FALSE,
    plan          TEXT        NOT NULL DEFAULT 'free',
    avatar_url    TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Sessions table
CREATE TABLE sessions (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token TEXT        UNIQUE NOT NULL,
    user_agent    TEXT,
    ip_address    TEXT,
    expires_at    TIMESTAMPTZ NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Accounts table
CREATE TABLE accounts (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name         TEXT        NOT NULL,
    type         TEXT,
    currency     TEXT        NOT NULL DEFAULT 'MXN',
    balance      NUMERIC     NOT NULL DEFAULT 0,
    credit_limit NUMERIC,
    is_active    BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Transactions table
CREATE TABLE transactions (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    account_id    UUID        REFERENCES accounts(id) ON DELETE SET NULL,
    amount        NUMERIC     NOT NULL,
    currency      TEXT        NOT NULL DEFAULT 'MXN',
    description   TEXT,
    merchant_name TEXT,
    category      TEXT,
    subcategory   TEXT,
    value_date    DATE        NOT NULL DEFAULT CURRENT_DATE,
    is_manual     BOOLEAN     NOT NULL DEFAULT TRUE,
    notes         TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Goals table
CREATE TABLE goals (
    id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type                 TEXT        NOT NULL,
    name                 TEXT        NOT NULL,
    target_amount        NUMERIC     NOT NULL,
    current_amount       NUMERIC     NOT NULL DEFAULT 0,
    monthly_contribution NUMERIC,
    target_date          DATE,
    priority             SMALLINT    NOT NULL DEFAULT 1,
    status               TEXT        NOT NULL DEFAULT 'active',
    emoji                TEXT,
    notes                TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Debts table
CREATE TABLE debts (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type             TEXT        NOT NULL,
    name             TEXT        NOT NULL,
    institution      TEXT,
    total_amount     NUMERIC     NOT NULL,
    original_amount  NUMERIC,
    monthly_payment  NUMERIC,
    interest_rate    NUMERIC,
    is_active        BOOLEAN     NOT NULL DEFAULT TRUE,
    notes            TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- AI Conversations table
CREATE TABLE ai_conversations (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title            TEXT,
    messages         JSONB       NOT NULL DEFAULT '[]',
    context_snapshot JSONB,
    message_count    INTEGER     NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_sessions_user    ON sessions(user_id);
CREATE INDEX idx_sessions_refresh ON sessions(refresh_token);
CREATE INDEX idx_sessions_expires ON sessions(expires_at);

CREATE INDEX idx_transactions_user_date ON transactions(user_id, value_date DESC);
CREATE INDEX idx_transactions_user_cat  ON transactions(user_id, category);

CREATE INDEX idx_goals_user_status ON goals(user_id, status);

CREATE INDEX idx_accounts_user ON accounts(user_id);
CREATE INDEX idx_debts_user    ON debts(user_id);

CREATE INDEX idx_ai_conversations_user ON ai_conversations(user_id);

-- updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers on tables that have updated_at
CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_accounts_updated_at
    BEFORE UPDATE ON accounts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_goals_updated_at
    BEFORE UPDATE ON goals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_debts_updated_at
    BEFORE UPDATE ON debts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_ai_conversations_updated_at
    BEFORE UPDATE ON ai_conversations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
