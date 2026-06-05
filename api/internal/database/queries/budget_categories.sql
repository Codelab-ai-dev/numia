-- name: ListBudgetCategories :many
SELECT * FROM budget_categories
WHERE user_id = $1
ORDER BY is_custom ASC, name ASC;

-- name: GetBudgetCategoryByID :one
SELECT * FROM budget_categories
WHERE id = $1 AND user_id = $2;

-- name: CreateBudgetCategory :one
INSERT INTO budget_categories (user_id, name, emoji, is_custom)
VALUES ($1, $2, $3, $4)
RETURNING *;

-- name: SoftDeleteBudgetCategory :exec
UPDATE budget_categories
SET is_active = FALSE
WHERE id = $1 AND user_id = $2 AND is_custom = TRUE;
