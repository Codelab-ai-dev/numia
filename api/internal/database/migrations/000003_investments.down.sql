-- 000003_investments.down.sql

DROP TRIGGER IF EXISTS trg_investments_updated_at ON investments;
DROP TABLE IF EXISTS investments;
