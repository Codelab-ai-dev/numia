package dashboard

import (
	"net/http"

	"numia-api/internal/middleware"

	"github.com/gin-gonic/gin"
)

// Handler wires HTTP routes to the dashboard Service.
type Handler struct {
	s *Service
}

// NewHandler creates a new dashboard Handler.
func NewHandler(s *Service) *Handler {
	return &Handler{s: s}
}

// RegisterRoutes mounts dashboard endpoints on the given RouterGroup.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	g := rg.Group("/dashboard")
	g.GET("/summary", h.summary)
}

func (h *Handler) summary(c *gin.Context) {
	userID := middleware.GetUserID(c)
	sum, err := h.s.GetSummary(c.Request.Context(), userID)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to get dashboard summary")
		return
	}
	c.JSON(http.StatusOK, sum)
}
