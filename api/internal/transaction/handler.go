package transaction

import (
	"net/http"
	"strconv"
	"time"

	"numia-api/internal/middleware"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Handler wires HTTP routes to the transaction Service.
type Handler struct {
	s *Service
}

// NewHandler creates a new transaction Handler.
func NewHandler(s *Service) *Handler {
	return &Handler{s: s}
}

// RegisterRoutes mounts transaction endpoints on the given RouterGroup.
// Summary and categories routes are registered before /:id to avoid route conflicts.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	g := rg.Group("/transactions")
	g.GET("/summary", h.summary)
	g.GET("/categories", h.categories)
	g.GET("", h.list)
	g.POST("", h.create)
	g.PUT("/:id", h.update)
	g.DELETE("/:id", h.delete)
}

func parseMonth(monthStr string) (time.Time, error) {
	if monthStr == "" {
		now := time.Now()
		return time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC), nil
	}
	t, err := time.Parse("2006-01", monthStr)
	if err != nil {
		return time.Time{}, err
	}
	return time.Date(t.Year(), t.Month(), 1, 0, 0, 0, 0, time.UTC), nil
}

func (h *Handler) list(c *gin.Context) {
	userID := middleware.GetUserID(c)

	var category *string
	if cat := c.Query("category"); cat != "" {
		category = &cat
	}

	limit := int32(50)
	if l := c.Query("limit"); l != "" {
		if n, err := strconv.Atoi(l); err == nil && n > 0 {
			limit = int32(n)
		}
	}
	offset := int32(0)
	if o := c.Query("offset"); o != "" {
		if n, err := strconv.Atoi(o); err == nil && n >= 0 {
			offset = int32(n)
		}
	}

	txs, err := h.s.List(c.Request.Context(), userID, category, limit, offset)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to list transactions")
		return
	}
	c.JSON(http.StatusOK, txs)
}

func (h *Handler) create(c *gin.Context) {
	var req CreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	tx, err := h.s.Create(c.Request.Context(), userID, req)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
		return
	}
	c.JSON(http.StatusCreated, tx)
}

func (h *Handler) update(c *gin.Context) {
	txID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "INVALID_ID", "invalid transaction id")
		return
	}
	var req UpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	tx, err := h.s.Update(c.Request.Context(), userID, txID, req)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to update transaction")
		return
	}
	c.JSON(http.StatusOK, tx)
}

func (h *Handler) delete(c *gin.Context) {
	txID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "INVALID_ID", "invalid transaction id")
		return
	}
	userID := middleware.GetUserID(c)
	if err := h.s.Delete(c.Request.Context(), userID, txID); err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to delete transaction")
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) summary(c *gin.Context) {
	userID := middleware.GetUserID(c)
	month, err := parseMonth(c.Query("month"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "INVALID_MONTH", "expected format: YYYY-MM")
		return
	}
	result, err := h.s.GetMonthlySummary(c.Request.Context(), userID, month)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to get summary")
		return
	}
	c.JSON(http.StatusOK, result)
}

func (h *Handler) categories(c *gin.Context) {
	userID := middleware.GetUserID(c)
	month, err := parseMonth(c.Query("month"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "INVALID_MONTH", "expected format: YYYY-MM")
		return
	}
	result, err := h.s.GetCategoryBreakdown(c.Request.Context(), userID, month)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to get category breakdown")
		return
	}
	c.JSON(http.StatusOK, result)
}
