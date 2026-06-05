-- name: ListInvestments :many
SELECT * FROM investments
WHERE user_id = $1
  AND (sqlc.narg('active_only')::BOOLEAN IS NULL OR is_active = sqlc.narg('active_only'))
ORDER BY created_at DESC;

-- name: GetInvestmentByID :one
SELECT * FROM investments WHERE id = $1 AND user_id = $2;

-- name: CreateInvestment :one
INSERT INTO investments (
    user_id, name, institution, type, amount_invested, current_value, notes
) VALUES ($1, $2, sqlc.narg('institution'), $3, $4, $5, sqlc.narg('notes'))
RETURNING *;

-- name: UpdateInvestment :one
UPDATE investments
SET name = COALESCE(sqlc.narg('name'), name),
    institution = COALESCE(sqlc.narg('institution'), institution),
    type = COALESCE(sqlc.narg('type'), type),
    amount_invested = COALESCE(sqlc.narg('amount_invested'), amount_invested),
    current_value = COALESCE(sqlc.narg('current_value'), current_value),
    is_active = COALESCE(sqlc.narg('is_active'), is_active),
    notes = COALESCE(sqlc.narg('notes'), notes)
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeleteInvestment :exec
DELETE FROM investments WHERE id = $1 AND user_id = $2;
