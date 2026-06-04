package config

import (
	"os"
	"github.com/joho/godotenv"
)

type Config struct {
	DBURL      string
	JWTSecret  string
	GroqAPIKey string
	Port       string
	GinMode    string
}

func Load() *Config {
	_ = godotenv.Load()
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	return &Config{
		DBURL:      os.Getenv("DB_URL"),
		JWTSecret:  os.Getenv("JWT_SECRET"),
		GroqAPIKey: os.Getenv("GROQ_API_KEY"),
		Port:       port,
		GinMode:    os.Getenv("GIN_MODE"),
	}
}
