package investment

import (
	"net/http"

	"numia-api/internal/middleware"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Handler wires HTTP routes to the investment Service.
type Handler struct {
	s *Service
}

// NewHandler creates a new investment Handler.
func NewHandler(s *Service) *Handler {
	return &Handler{s: s}
}

// RegisterRoutes mounts investment endpoints on the given RouterGroup.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	g := rg.Group("/investments")
	g.GET("", h.list)
	g.POST("", h.create)
	g.PUT("/:id", h.update)
	g.DELETE("/:id", h.delete)
}

func (h *Handler) list(c *gin.Context) {
	userID := middleware.GetUserID(c)
	var activeOnly *bool
	if a := c.Query("active_only"); a != "" {
		v := a == "true"
		activeOnly = &v
	}
	items, err := h.s.List(c.Request.Context(), userID, activeOnly)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to list investments")
		return
	}
	c.JSON(http.StatusOK, items)
}

func (h *Handler) create(c *gin.Context) {
	var req CreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	inv, err := h.s.Create(c.Request.Context(), userID, req)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to create investment")
		return
	}
	c.JSON(http.StatusCreated, inv)
}

func (h *Handler) update(c *gin.Context) {
	investmentID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "INVALID_ID", "invalid investment id")
		return
	}
	var req UpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	inv, err := h.s.Update(c.Request.Context(), userID, investmentID, req)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to update investment")
		return
	}
	c.JSON(http.StatusOK, inv)
}

func (h *Handler) delete(c *gin.Context) {
	investmentID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "INVALID_ID", "invalid investment id")
		return
	}
	userID := middleware.GetUserID(c)
	if err := h.s.Delete(c.Request.Context(), userID, investmentID); err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to delete investment")
		return
	}
	c.Status(http.StatusNoContent)
}
