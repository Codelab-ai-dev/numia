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
