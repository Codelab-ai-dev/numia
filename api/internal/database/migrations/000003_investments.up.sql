-- 000003_investments.up.sql

-- Investments (user-scoped portfolio holdings)
CREATE TABLE investments (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            TEXT        NOT NULL,
    institution     TEXT,
    type            TEXT        NOT NULL,
    amount_invested NUMERIC     NOT NULL,
    current_value   NUMERIC     NOT NULL,
    notes           TEXT,
    is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_investments_user ON investments(user_id);

CREATE TRIGGER trg_investments_updated_at
    BEFORE UPDATE ON investments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
