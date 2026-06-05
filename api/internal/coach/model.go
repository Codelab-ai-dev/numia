package coach

import "time"

// ChatRequest is the payload for starting or continuing a conversation.
type ChatRequest struct {
	ConversationID *string `json:"conversation_id"`
	Message        string  `json:"message" binding:"required"`
}

// ConversationListItem is a summary of a conversation.
type ConversationListItem struct {
	ID           string    `json:"id"`
	Title        *string   `json:"title"`
	MessageCount int32     `json:"message_count"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// MessageJSON represents a single message in a conversation.
type MessageJSON struct {
	Role      string    `json:"role"`
	Content   string    `json:"content"`
	Timestamp time.Time `json:"timestamp"`
}
