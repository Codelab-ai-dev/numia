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
