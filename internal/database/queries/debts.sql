-- name: ListDebts :many
SELECT * FROM debts
WHERE user_id = $1
  AND (sqlc.narg('active_only')::BOOLEAN IS NULL OR is_active = sqlc.narg('active_only'))
ORDER BY created_at DESC;

-- name: GetDebtByID :one
SELECT * FROM debts WHERE id = $1 AND user_id = $2;

-- name: CreateDebt :one
INSERT INTO debts (
    user_id, type, name, institution, total_amount,
    original_amount, monthly_payment, interest_rate, notes
) VALUES ($1, $2, $3, sqlc.narg('institution'), $4,
    sqlc.narg('original_amount'), sqlc.narg('monthly_payment'),
    sqlc.narg('interest_rate'), sqlc.narg('notes'))
RETURNING *;

-- name: UpdateDebt :one
UPDATE debts
SET name = COALESCE(sqlc.narg('name'), name),
    total_amount = COALESCE(sqlc.narg('total_amount'), total_amount),
    monthly_payment = COALESCE(sqlc.narg('monthly_payment'), monthly_payment),
    interest_rate = COALESCE(sqlc.narg('interest_rate'), interest_rate),
    is_active = COALESCE(sqlc.narg('is_active'), is_active),
    notes = COALESCE(sqlc.narg('notes'), notes)
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeleteDebt :exec
DELETE FROM debts WHERE id = $1 AND user_id = $2;
