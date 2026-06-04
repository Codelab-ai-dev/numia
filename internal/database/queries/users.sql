-- name: CreateUser :one
INSERT INTO users (email, password_hash, full_name)
VALUES ($1, $2, $3)
RETURNING *;

-- name: GetUserByID :one
SELECT * FROM users WHERE id = $1;

-- name: GetUserByEmail :one
SELECT * FROM users WHERE email = $1;

-- name: UpdateUserProfile :one
UPDATE users
SET full_name = COALESCE(sqlc.narg('full_name'), full_name),
    avatar_url = COALESCE(sqlc.narg('avatar_url'), avatar_url)
WHERE id = $1
RETURNING *;

-- name: CompleteOnboarding :one
UPDATE users
SET full_name = $2,
    country = $3,
    birth_date = sqlc.narg('birth_date'),
    occupation = sqlc.narg('occupation'),
    onboarding_done = TRUE
WHERE id = $1
RETURNING *;
