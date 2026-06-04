-- name: ListConversations :many
SELECT id, user_id, title, message_count, created_at, updated_at
FROM ai_conversations
WHERE user_id = $1
ORDER BY updated_at DESC
LIMIT $2;

-- name: GetConversation :one
SELECT * FROM ai_conversations WHERE id = $1 AND user_id = $2;

-- name: CreateConversation :one
INSERT INTO ai_conversations (user_id, title)
VALUES ($1, sqlc.narg('title'))
RETURNING *;

-- name: UpdateConversationMessages :one
UPDATE ai_conversations
SET messages = $3,
    message_count = $4,
    title = COALESCE(sqlc.narg('title'), title)
WHERE id = $1 AND user_id = $2
RETURNING *;

-- name: DeleteConversation :exec
DELETE FROM ai_conversations WHERE id = $1 AND user_id = $2;
