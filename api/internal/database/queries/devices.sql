-- name: UpsertDevice :exec
INSERT INTO devices (user_id, fcm_token, platform)
VALUES ($1, $2, $3)
ON CONFLICT (fcm_token) DO UPDATE
SET user_id = EXCLUDED.user_id,
    platform = EXCLUDED.platform;

-- name: DeleteDevice :exec
DELETE FROM devices WHERE fcm_token = $1;

-- name: ListDevicesByUser :many
SELECT * FROM devices WHERE user_id = $1;
