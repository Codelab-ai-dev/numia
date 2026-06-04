-- name: GetBudgetByUserID :one
SELECT * FROM budgets
WHERE user_id = $1 AND is_active = TRUE;

-- name: UpsertBudget :one
INSERT INTO budgets (user_id, global_amount, cycle_start_day)
VALUES ($1, $2, $3)
ON CONFLICT (user_id) DO UPDATE
SET global_amount = EXCLUDED.global_amount,
    cycle_start_day = EXCLUDED.cycle_start_day,
    is_active = TRUE
RETURNING *;

-- name: ListBudgetAllocations :many
SELECT ba.*, bc.name AS category_name, bc.emoji AS category_emoji
FROM budget_allocations ba
JOIN budget_categories bc ON bc.id = ba.category_id
WHERE ba.budget_id = $1
ORDER BY bc.name ASC;

-- name: DeleteAllocationsByBudget :exec
DELETE FROM budget_allocations WHERE budget_id = $1;

-- name: CreateBudgetAllocation :one
INSERT INTO budget_allocations (budget_id, category_id, amount)
VALUES ($1, $2, $3)
RETURNING *;

-- name: GetAllocationByCategoryAndBudget :one
SELECT ba.amount FROM budget_allocations ba
WHERE ba.budget_id = $1 AND ba.category_id = $2;
