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
