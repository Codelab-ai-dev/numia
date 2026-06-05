package user

import (
	"net/http"

	"numia-api/internal/middleware"

	"github.com/gin-gonic/gin"
)

// Handler wires HTTP routes to the user Service.
type Handler struct {
	s *Service
}

// NewHandler creates a new user Handler.
func NewHandler(s *Service) *Handler {
	return &Handler{s: s}
}

// RegisterRoutes mounts user endpoints on the given RouterGroup.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	g := rg.Group("/users")
	g.GET("/me", h.getProfile)
	g.PUT("/me", h.updateProfile)
	g.POST("/onboarding", h.completeOnboarding)
}

func (h *Handler) getProfile(c *gin.Context) {
	userID := middleware.GetUserID(c)
	profile, err := h.s.GetProfile(c.Request.Context(), userID)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to get profile")
		return
	}
	c.JSON(http.StatusOK, profile)
}

func (h *Handler) updateProfile(c *gin.Context) {
	var req struct {
		FullName  *string `json:"full_name"`
		AvatarURL *string `json:"avatar_url"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	profile, err := h.s.UpdateProfile(c.Request.Context(), userID, req.FullName, req.AvatarURL)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to update profile")
		return
	}
	c.JSON(http.StatusOK, profile)
}

func (h *Handler) completeOnboarding(c *gin.Context) {
	var req OnboardingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	profile, err := h.s.CompleteOnboarding(c.Request.Context(), userID, req)
	if err != nil {
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "failed to complete onboarding")
		return
	}
	c.JSON(http.StatusOK, profile)
}
