package budget

import (
	"net/http"
	"time"

	"numia-api/internal/middleware"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Handler wires HTTP routes to the budget Service.
type Handler struct {
	s *Service
}

// NewHandler creates a new budget Handler.
func NewHandler(s *Service) *Handler {
	return &Handler{s: s}
}

// RegisterRoutes mounts budget endpoints on the given RouterGroup.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	g := rg.Group("/budget")

	// Categories
	g.GET("/categories", h.listCategories)
	g.POST("/categories", h.createCategory)
	g.DELETE("/categories/:id", h.deleteCategory)

	// Budget
	g.GET("", h.getBudget)
	g.POST("", h.createOrUpdateBudget)
	g.PUT("/allocations", h.setAllocations)

	// Expenses
	g.GET("/expenses", h.listExpenses)
	g.POST("/expenses", h.createExpense)
	g.PUT("/expenses/:id", h.updateExpense)
	g.DELETE("/expenses/:id", h.deleteExpense)

	// Summary
	g.GET("/summary", h.getSummary)
}

func (h *Handler) listCategories(c *gin.Context) {
	userID := middleware.GetUserID(c)
	cats, err := h.s.ListCategories(c.Request.Context(), userID)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to list categories")
		return
	}
	c.JSON(http.StatusOK, cats)
}

func (h *Handler) createCategory(c *gin.Context) {
	var req CreateCategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	cat, err := h.s.CreateCategory(c.Request.Context(), userID, req)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
		return
	}
	c.JSON(http.StatusCreated, cat)
}

func (h *Handler) deleteCategory(c *gin.Context) {
	catID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "INVALID_ID", "invalid category id")
		return
	}
	userID := middleware.GetUserID(c)
	if err := h.s.DeleteCategory(c.Request.Context(), userID, catID); err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to delete category")
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) getBudget(c *gin.Context) {
	userID := middleware.GetUserID(c)
	resp, err := h.s.GetBudget(c.Request.Context(), userID)
	if err != nil {
		middleware.RespondError(c, http.StatusNotFound, "NOT_FOUND", "budget not found")
		return
	}
	c.JSON(http.StatusOK, resp)
}

func (h *Handler) createOrUpdateBudget(c *gin.Context) {
	var req CreateBudgetRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	resp, err := h.s.CreateOrUpdateBudget(c.Request.Context(), userID, req)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
		return
	}
	c.JSON(http.StatusOK, resp)
}

func (h *Handler) setAllocations(c *gin.Context) {
	var req AllocationsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	resp, err := h.s.SetAllocations(c.Request.Context(), userID, req)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
		return
	}
	c.JSON(http.StatusOK, resp)
}

func (h *Handler) listExpenses(c *gin.Context) {
	userID := middleware.GetUserID(c)

	var start, end time.Time
	if s := c.Query("start"); s != "" {
		if t, err := time.Parse("2006-01-02", s); err == nil {
			start = t
		}
	}
	if e := c.Query("end"); e != "" {
		if t, err := time.Parse("2006-01-02", e); err == nil {
			end = t
		}
	}

	expenses, err := h.s.ListExpenses(c.Request.Context(), userID, start, end)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to list expenses")
		return
	}
	c.JSON(http.StatusOK, expenses)
}

func (h *Handler) createExpense(c *gin.Context) {
	var req CreateExpenseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	expense, err := h.s.CreateExpense(c.Request.Context(), userID, req)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
		return
	}
	c.JSON(http.StatusCreated, expense)
}

func (h *Handler) updateExpense(c *gin.Context) {
	expID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "INVALID_ID", "invalid expense id")
		return
	}
	var req UpdateExpenseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	expense, err := h.s.UpdateExpense(c.Request.Context(), userID, expID, req)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
		return
	}
	c.JSON(http.StatusOK, expense)
}

func (h *Handler) deleteExpense(c *gin.Context) {
	expID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "INVALID_ID", "invalid expense id")
		return
	}
	userID := middleware.GetUserID(c)
	if err := h.s.DeleteExpense(c.Request.Context(), userID, expID); err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to delete expense")
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) getSummary(c *gin.Context) {
	userID := middleware.GetUserID(c)
	resp, err := h.s.GetSummary(c.Request.Context(), userID)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
		return
	}
	c.JSON(http.StatusOK, resp)
}
