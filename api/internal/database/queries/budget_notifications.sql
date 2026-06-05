-- name: CheckNotificationSent :one
SELECT EXISTS(
    SELECT 1 FROM budget_notifications
    WHERE user_id = $1
      AND category_id = $2
      AND cycle_start = $3
      AND threshold = $4
) AS sent;

-- name: InsertNotification :exec
INSERT INTO budget_notifications (user_id, category_id, cycle_start, threshold)
VALUES ($1, $2, $3, $4)
ON CONFLICT (user_id, category_id, cycle_start, threshold) DO NOTHING;
