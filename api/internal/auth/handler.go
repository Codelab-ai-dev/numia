package auth

import (
	"errors"
	"net/http"

	"numia-api/internal/middleware"

	"github.com/gin-gonic/gin"
)

// Handler wires HTTP routes to the auth Service.
type Handler struct {
	s *Service
}

// NewHandler creates a new auth Handler.
func NewHandler(s *Service) *Handler {
	return &Handler{s: s}
}

// RegisterRoutes mounts all auth endpoints under /auth on the given RouterGroup.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	g := rg.Group("/auth")
	g.POST("/register", h.register)
	g.POST("/login", h.login)
	g.POST("/refresh", h.refresh)
	g.POST("/logout", h.logout)
}

func (h *Handler) register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}

	userAgent := c.GetHeader("User-Agent")
	ip := c.ClientIP()

	resp, err := h.s.Register(c.Request.Context(), req, userAgent, ip)
	if err != nil {
		h.respondServiceError(c, err)
		return
	}

	c.JSON(http.StatusCreated, resp)
}

func (h *Handler) login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}

	userAgent := c.GetHeader("User-Agent")
	ip := c.ClientIP()

	resp, err := h.s.Login(c.Request.Context(), req, userAgent, ip)
	if err != nil {
		h.respondServiceError(c, err)
		return
	}

	c.JSON(http.StatusOK, resp)
}

func (h *Handler) refresh(c *gin.Context) {
	var req RefreshRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}

	userAgent := c.GetHeader("User-Agent")
	ip := c.ClientIP()

	resp, err := h.s.Refresh(c.Request.Context(), req.RefreshToken, userAgent, ip)
	if err != nil {
		h.respondServiceError(c, err)
		return
	}

	c.JSON(http.StatusOK, resp)
}

func (h *Handler) logout(c *gin.Context) {
	var req LogoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}

	if err := h.s.Logout(c.Request.Context(), req.RefreshToken); err != nil {
		h.respondServiceError(c, err)
		return
	}

	c.Status(http.StatusNoContent)
}

// respondServiceError maps sentinel errors to appropriate HTTP status codes.
func (h *Handler) respondServiceError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, ErrEmailTaken):
		middleware.RespondError(c, http.StatusConflict, "EMAIL_TAKEN", err.Error())
	case errors.Is(err, ErrInvalidCredentials):
		middleware.RespondError(c, http.StatusUnauthorized, "INVALID_CREDENTIALS", err.Error())
	case errors.Is(err, ErrSessionExpired):
		middleware.RespondError(c, http.StatusUnauthorized, "SESSION_EXPIRED", err.Error())
	default:
		middleware.RespondError(c, http.StatusInternalServerError, "INTERNAL_ERROR", "internal server error")
	}
}
