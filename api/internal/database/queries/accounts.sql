-- name: ListAccountsByUser :many
SELECT * FROM accounts
WHERE user_id = $1 AND is_active = TRUE
ORDER BY created_at;

-- name: GetAccountByID :one
SELECT * FROM accounts WHERE id = $1 AND user_id = $2;

-- name: CreateAccount :one
INSERT INTO accounts (user_id, name, type, currency, balance, credit_limit)
VALUES ($1, $2, $3, $4, $5, sqlc.narg('credit_limit'))
RETURNING *;

-- name: UpdateAccount :one
UPDATE accounts
SET name = COALESCE(sqlc.narg('name'), name),
    balance = COALESCE(sqlc.narg('balance'), balance),
    is_active = COALESCE(sqlc.narg('is_active'), is_active)
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeleteAccount :exec
DELETE FROM accounts WHERE id = $1 AND user_id = $2;
