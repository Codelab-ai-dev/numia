package debt

import (
	"net/http"

	"numia-api/internal/middleware"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Handler wires HTTP routes to the debt Service.
type Handler struct {
	s *Service
}

// NewHandler creates a new debt Handler.
func NewHandler(s *Service) *Handler {
	return &Handler{s: s}
}

// RegisterRoutes mounts debt endpoints on the given RouterGroup.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	g := rg.Group("/debts")
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
	debts, err := h.s.List(c.Request.Context(), userID, activeOnly)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to list debts")
		return
	}
	c.JSON(http.StatusOK, debts)
}

func (h *Handler) create(c *gin.Context) {
	var req CreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	d, err := h.s.Create(c.Request.Context(), userID, req)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to create debt")
		return
	}
	c.JSON(http.StatusCreated, d)
}

func (h *Handler) update(c *gin.Context) {
	debtID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "INVALID_ID", "invalid debt id")
		return
	}
	var req UpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	d, err := h.s.Update(c.Request.Context(), userID, debtID, req)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to update debt")
		return
	}
	c.JSON(http.StatusOK, d)
}

func (h *Handler) delete(c *gin.Context) {
	debtID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "INVALID_ID", "invalid debt id")
		return
	}
	userID := middleware.GetUserID(c)
	if err := h.s.Delete(c.Request.Context(), userID, debtID); err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to delete debt")
		return
	}
	c.Status(http.StatusNoContent)
}
