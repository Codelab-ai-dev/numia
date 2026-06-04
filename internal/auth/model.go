package auth

import (
	"numia-api/internal/database/sqlc"

	"github.com/google/uuid"
)

// Request types

type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=8"`
	FullName string `json:"full_name" binding:"required"`
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type RefreshRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

type LogoutRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

// Response types

type AuthResponse struct {
	AccessToken  string   `json:"access_token"`
	RefreshToken string   `json:"refresh_token"`
	User         UserJSON `json:"user"`
}

type TokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

// UserJSON is a JSON-friendly representation of sqlc.User.
// password_hash is intentionally omitted.
type UserJSON struct {
	ID             string  `json:"id"`
	Email          string  `json:"email"`
	FullName       string  `json:"full_name"`
	Country        string  `json:"country"`
	BirthDate      *string `json:"birth_date"`
	Occupation     *string `json:"occupation"`
	OnboardingDone bool    `json:"onboarding_done"`
	Plan           string  `json:"plan"`
	AvatarUrl      *string `json:"avatar_url"`
	CreatedAt      string  `json:"created_at"`
	UpdatedAt      string  `json:"updated_at"`
}

// ToUserJSON converts a sqlc.User to a JSON-friendly UserJSON.
// It is exported so other packages (e.g. user feature) can reuse it.
func ToUserJSON(u sqlc.User) UserJSON {
	j := UserJSON{
		Email:          u.Email,
		FullName:       u.FullName,
		Country:        u.Country,
		OnboardingDone: u.OnboardingDone,
		Plan:           u.Plan,
	}

	// pgtype.UUID bytes → standard UUID string
	if u.ID.Valid {
		id, err := uuid.FromBytes(u.ID.Bytes[:])
		if err == nil {
			j.ID = id.String()
		}
	}

	// Timestamps
	if u.CreatedAt.Valid {
		j.CreatedAt = u.CreatedAt.Time.UTC().Format("2006-01-02T15:04:05Z")
	}
	if u.UpdatedAt.Valid {
		j.UpdatedAt = u.UpdatedAt.Time.UTC().Format("2006-01-02T15:04:05Z")
	}

	// Nullable date
	if u.BirthDate.Valid {
		s := u.BirthDate.Time.Format("2006-01-02")
		j.BirthDate = &s
	}

	// Nullable text fields
	if u.Occupation.Valid {
		s := u.Occupation.String
		j.Occupation = &s
	}
	if u.AvatarUrl.Valid {
		s := u.AvatarUrl.String
		j.AvatarUrl = &s
	}

	return j
}
