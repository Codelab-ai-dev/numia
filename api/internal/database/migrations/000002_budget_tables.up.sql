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
