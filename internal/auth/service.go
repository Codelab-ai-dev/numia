package auth

import (
	"context"
	"errors"
	"strings"
	"time"

	"numia-api/internal/database/sqlc"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"golang.org/x/crypto/bcrypt"
)

// Sentinel errors

var (
	ErrEmailTaken         = errors.New("email already taken")
	ErrInvalidCredentials = errors.New("invalid email or password")
	ErrSessionExpired     = errors.New("session expired or not found")
)

// Service holds the dependencies for auth operations.
type Service struct {
	q         *sqlc.Queries
	jwtSecret string
}

// NewService constructs an auth Service.
func NewService(q *sqlc.Queries, jwtSecret string) *Service {
	return &Service{q: q, jwtSecret: jwtSecret}
}

// Register creates a new user, starts a session and returns tokens + user info.
func (s *Service) Register(ctx context.Context, req RegisterRequest, userAgent, ip string) (AuthResponse, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return AuthResponse{}, err
	}

	user, err := s.q.CreateUser(ctx, sqlc.CreateUserParams{
		Email:        req.Email,
		PasswordHash: string(hash),
		FullName:     req.FullName,
	})
	if err != nil {
		if isDuplicateKeyError(err) {
			return AuthResponse{}, ErrEmailTaken
		}
		return AuthResponse{}, err
	}

	accessToken, err := s.generateAccessToken(user.ID)
	if err != nil {
		return AuthResponse{}, err
	}

	refreshToken, err := s.createSession(ctx, user.ID, userAgent, ip)
	if err != nil {
		return AuthResponse{}, err
	}

	return AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		User:         ToUserJSON(user),
	}, nil
}

// Login authenticates a user and returns tokens + user info.
func (s *Service) Login(ctx context.Context, req LoginRequest, userAgent, ip string) (AuthResponse, error) {
	user, err := s.q.GetUserByEmail(ctx, req.Email)
	if err != nil {
		return AuthResponse{}, ErrInvalidCredentials
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return AuthResponse{}, ErrInvalidCredentials
	}

	accessToken, err := s.generateAccessToken(user.ID)
	if err != nil {
		return AuthResponse{}, err
	}

	refreshToken, err := s.createSession(ctx, user.ID, userAgent, ip)
	if err != nil {
		return AuthResponse{}, err
	}

	return AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		User:         ToUserJSON(user),
	}, nil
}

// Refresh rotates the refresh token: deletes the old session, creates a new one,
// and issues a fresh access token.
func (s *Service) Refresh(ctx context.Context, refreshToken, userAgent, ip string) (TokenResponse, error) {
	session, err := s.q.GetSessionByRefreshToken(ctx, refreshToken)
	if err != nil {
		return TokenResponse{}, ErrSessionExpired
	}

	// Delete old session (token rotation)
	if err := s.q.DeleteSession(ctx, session.RefreshToken); err != nil {
		return TokenResponse{}, err
	}

	accessToken, err := s.generateAccessToken(session.UserID)
	if err != nil {
		return TokenResponse{}, err
	}

	newRefreshToken, err := s.createSession(ctx, session.UserID, userAgent, ip)
	if err != nil {
		return TokenResponse{}, err
	}

	return TokenResponse{
		AccessToken:  accessToken,
		RefreshToken: newRefreshToken,
	}, nil
}

// Logout deletes the session identified by the given refresh token.
func (s *Service) Logout(ctx context.Context, refreshToken string) error {
	return s.q.DeleteSession(ctx, refreshToken)
}

// --- helpers ---

func (s *Service) generateAccessToken(userID pgtype.UUID) (string, error) {
	// Convert pgtype.UUID bytes to standard UUID string via google/uuid
	id, err := uuid.FromBytes(userID.Bytes[:])
	if err != nil {
		return "", err
	}

	now := time.Now()
	claims := jwt.MapClaims{
		"user_id": id.String(),
		"iat":     now.Unix(),
		"exp":     now.Add(15 * time.Minute).Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(s.jwtSecret))
}

func (s *Service) createSession(ctx context.Context, userID pgtype.UUID, userAgent, ip string) (string, error) {
	refreshToken := uuid.New().String()
	expiresAt := pgtype.Timestamptz{
		Time:  time.Now().Add(30 * 24 * time.Hour),
		Valid: true,
	}

	_, err := s.q.CreateSession(ctx, sqlc.CreateSessionParams{
		UserID:       userID,
		RefreshToken: refreshToken,
		UserAgent:    pgtype.Text{String: userAgent, Valid: userAgent != ""},
		IpAddress:    pgtype.Text{String: ip, Valid: ip != ""},
		ExpiresAt:    expiresAt,
	})
	if err != nil {
		return "", err
	}
	return refreshToken, nil
}

func isDuplicateKeyError(err error) bool {
	msg := err.Error()
	return strings.Contains(msg, "duplicate key") || strings.Contains(msg, "unique constraint")
}
