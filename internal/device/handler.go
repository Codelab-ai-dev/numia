package device

import (
	"net/http"

	"numia-api/internal/middleware"

	"github.com/gin-gonic/gin"
)

// Handler wires HTTP routes to the device Service.
type Handler struct {
	s *Service
}

// NewHandler creates a new device Handler.
func NewHandler(s *Service) *Handler {
	return &Handler{s: s}
}

// RegisterRoutes mounts device endpoints on the given RouterGroup.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	g := rg.Group("/devices")
	g.POST("", h.register)
	g.DELETE("", h.remove)
}

func (h *Handler) register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	if err := h.s.Register(c.Request.Context(), userID, req); err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) remove(c *gin.Context) {
	var req DeleteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	if err := h.s.Remove(c.Request.Context(), req); err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
		return
	}
	c.Status(http.StatusNoContent)
}
