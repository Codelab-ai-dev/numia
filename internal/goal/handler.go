package goal

import (
	"net/http"

	"numia-api/internal/middleware"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Handler wires HTTP routes to the goal Service.
type Handler struct {
	s *Service
}

// NewHandler creates a new goal Handler.
func NewHandler(s *Service) *Handler {
	return &Handler{s: s}
}

// RegisterRoutes mounts goal endpoints on the given RouterGroup.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	g := rg.Group("/goals")
	g.GET("", h.list)
	g.POST("", h.create)
	g.PUT("/:id", h.update)
	g.POST("/:id/contribute", h.contribute)
	g.DELETE("/:id", h.delete)
}

func (h *Handler) list(c *gin.Context) {
	userID := middleware.GetUserID(c)
	var status *string
	if s := c.Query("status"); s != "" {
		status = &s
	}
	goals, err := h.s.List(c.Request.Context(), userID, status)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to list goals")
		return
	}
	c.JSON(http.StatusOK, goals)
}

func (h *Handler) create(c *gin.Context) {
	var req CreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	goal, err := h.s.Create(c.Request.Context(), userID, req)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
		return
	}
	c.JSON(http.StatusCreated, goal)
}

func (h *Handler) update(c *gin.Context) {
	goalID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "INVALID_ID", "invalid goal id")
		return
	}
	var req UpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	goal, err := h.s.Update(c.Request.Context(), userID, goalID, req)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to update goal")
		return
	}
	c.JSON(http.StatusOK, goal)
}

func (h *Handler) contribute(c *gin.Context) {
	goalID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "INVALID_ID", "invalid goal id")
		return
	}
	var req ContributeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	goal, err := h.s.AddContribution(c.Request.Context(), userID, goalID, req.Amount)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to add contribution")
		return
	}
	c.JSON(http.StatusOK, goal)
}

func (h *Handler) delete(c *gin.Context) {
	goalID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "INVALID_ID", "invalid goal id")
		return
	}
	userID := middleware.GetUserID(c)
	if err := h.s.Delete(c.Request.Context(), userID, goalID); err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to delete goal")
		return
	}
	c.Status(http.StatusNoContent)
}
