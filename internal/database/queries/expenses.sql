-- name: ListExpensesByCycle :many
SELECT e.*, bc.name AS category_name, bc.emoji AS category_emoji
FROM expenses e
JOIN budget_categories bc ON bc.id = e.category_id
WHERE e.user_id = $1
  AND e.expense_date >= $2
  AND e.expense_date <= $3
ORDER BY e.expense_date DESC, e.created_at DESC;

-- name: CreateExpense :one
INSERT INTO expenses (user_id, category_id, amount, description, subcategory, expense_date)
VALUES ($1, $2, $3, sqlc.narg('description'), sqlc.narg('subcategory'), $4)
RETURNING *;

-- name: UpdateExpense :one
UPDATE expenses
SET category_id = $3,
    amount = $4,
    description = sqlc.narg('description'),
    subcategory = sqlc.narg('subcategory'),
    expense_date = $5,
    updated_at = NOW()
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeleteExpense :exec
DELETE FROM expenses WHERE id = $1 AND user_id = $2;

-- name: SumExpensesByCategoryCycle :many
SELECT category_id, COALESCE(SUM(amount), 0)::NUMERIC(12,2) AS total_spent
FROM expenses
WHERE user_id = $1
  AND expense_date >= $2
  AND expense_date <= $3
GROUP BY category_id;

-- name: SumExpensesByCategoryID :one
SELECT COALESCE(SUM(amount), 0)::NUMERIC(12,2) AS total_spent
FROM expenses
WHERE user_id = $1
  AND category_id = $2
  AND expense_date >= $3
  AND expense_date <= $4;

-- name: SumAllExpensesCycle :one
SELECT COALESCE(SUM(amount), 0)::NUMERIC(12,2) AS total_spent
FROM expenses
WHERE user_id = $1
  AND expense_date >= $2
  AND expense_date <= $3;
