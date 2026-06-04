package coach

import (
	"encoding/json"
	"fmt"
	"net/http"

	"numia-api/internal/middleware"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Handler wires HTTP routes to the coach Service.
type Handler struct {
	s *Service
}

// NewHandler creates a new coach Handler.
func NewHandler(s *Service) *Handler {
	return &Handler{s: s}
}

// RegisterRoutes mounts coach endpoints on the given RouterGroup.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	g := rg.Group("/coach")
	g.POST("/chat", h.chat)
	g.GET("/conversations", h.listConversations)
	g.GET("/conversations/:id", h.getConversation)
	g.DELETE("/conversations/:id", h.deleteConversation)
}

// tokenEvent is the SSE payload for each streamed token.
type tokenEvent struct {
	Token string `json:"token"`
}

// doneEvent is the SSE payload sent when streaming is complete.
type doneEvent struct {
	ConversationID string `json:"conversation_id"`
	FullResponse   string `json:"full_response"`
}

func (h *Handler) chat(c *gin.Context) {
	var req ChatRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}

	userID := middleware.GetUserID(c)

	// Set SSE headers
	c.Header("Content-Type", "text/event-stream")
	c.Header("Cache-Control", "no-cache")
	c.Header("Connection", "keep-alive")
	c.Header("X-Accel-Buffering", "no")

	flusher, ok := c.Writer.(http.Flusher)
	if !ok {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "streaming not supported")
		return
	}

	onToken := func(token string) {
		evt := tokenEvent{Token: token}
		data, _ := json.Marshal(evt)
		fmt.Fprintf(c.Writer, "data: %s\n\n", data)
		flusher.Flush()
	}

	convID, fullResponse, err := h.s.Chat(c.Request.Context(), userID, req, onToken)
	if err != nil {
		errData, _ := json.Marshal(gin.H{"error": err.Error()})
		fmt.Fprintf(c.Writer, "data: %s\n\n", errData)
		flusher.Flush()
		return
	}

	// Send done event with conversation ID and full response
	done := doneEvent{ConversationID: convID, FullResponse: fullResponse}
	doneData, _ := json.Marshal(done)
	fmt.Fprintf(c.Writer, "data: %s\n\n", doneData)
	fmt.Fprintf(c.Writer, "data: [DONE]\n\n")
	flusher.Flush()
}

func (h *Handler) listConversations(c *gin.Context) {
	userID := middleware.GetUserID(c)
	items, err := h.s.ListConversations(c.Request.Context(), userID, 20)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to list conversations")
		return
	}
	c.JSON(http.StatusOK, items)
}

func (h *Handler) getConversation(c *gin.Context) {
	convID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "INVALID_ID", "invalid conversation id")
		return
	}
	userID := middleware.GetUserID(c)
	messages, err := h.s.GetConversation(c.Request.Context(), userID, convID)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to get conversation")
		return
	}
	c.JSON(http.StatusOK, messages)
}

func (h *Handler) deleteConversation(c *gin.Context) {
	convID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "INVALID_ID", "invalid conversation id")
		return
	}
	userID := middleware.GetUserID(c)
	if err := h.s.DeleteConversation(c.Request.Context(), userID, convID); err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to delete conversation")
		return
	}
	c.Status(http.StatusNoContent)
}
