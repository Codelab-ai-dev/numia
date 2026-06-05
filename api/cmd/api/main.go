package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"numia-api/internal/account"
	"numia-api/internal/auth"
	"numia-api/internal/budget"
	"numia-api/internal/coach"
	"numia-api/internal/config"
	"numia-api/internal/dashboard"
	"numia-api/internal/database"
	"numia-api/internal/database/sqlc"
	"numia-api/internal/debt"
	"numia-api/internal/device"
	"numia-api/internal/goal"
	"numia-api/internal/investment"
	"numia-api/internal/middleware"
	"numia-api/internal/transaction"
	"numia-api/internal/user"

	"github.com/gin-gonic/gin"
)

func main() {
	cfg := config.Load()
	if cfg.GinMode == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	db, err := database.Connect(cfg.DBURL)
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}
	defer db.Close()

	r := gin.Default()
	r.Use(middleware.CORS())

	r.GET("/api/v1/health", func(c *gin.Context) {
		if err := db.Ping(c.Request.Context()); err != nil {
			c.JSON(http.StatusServiceUnavailable, gin.H{"status": "error", "db": "disconnected"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"status": "ok", "db": "connected"})
	})

	api := r.Group("/api/v1")

	queries := sqlc.New(db.Pool)

	// Auth (public)
	authService := auth.NewService(queries, cfg.JWTSecret)
	authHandler := auth.NewHandler(authService)
	authHandler.RegisterRoutes(api)

	// Protected group
	protected := api.Group("", middleware.AuthRequired(cfg.JWTSecret))

	// User
	userService := user.NewService(queries)
	userHandler := user.NewHandler(userService)
	userHandler.RegisterRoutes(protected)

	// Accounts
	accountService := account.NewService(queries)
	accountHandler := account.NewHandler(accountService)
	accountHandler.RegisterRoutes(protected)

	// Transactions
	transactionService := transaction.NewService(queries)
	transactionHandler := transaction.NewHandler(transactionService)
	transactionHandler.RegisterRoutes(protected)

	// Goals
	goalService := goal.NewService(queries)
	goalHandler := goal.NewHandler(goalService)
	goalHandler.RegisterRoutes(protected)

	// Debts
	debtService := debt.NewService(queries)
	debtHandler := debt.NewHandler(debtService)
	debtHandler.RegisterRoutes(protected)

	// Investments
	investmentService := investment.NewService(queries)
	investmentHandler := investment.NewHandler(investmentService)
	investmentHandler.RegisterRoutes(protected)

	// Dashboard
	dashboardService := dashboard.NewService(queries)
	dashboardHandler := dashboard.NewHandler(dashboardService)
	dashboardHandler.RegisterRoutes(protected)

	// Coach
	groqClient := coach.NewGroqClient(cfg.GroqAPIKey)
	coachService := coach.NewService(queries, groqClient)
	coachHandler := coach.NewHandler(coachService)
	coachHandler.RegisterRoutes(protected)

	// Budget
	fcmClient := budget.NewFCMClient(cfg.FirebaseCredentialsPath)
	budgetService := budget.NewService(queries, fcmClient)
	budgetHandler := budget.NewHandler(budgetService)
	budgetHandler.RegisterRoutes(protected)

	// Devices
	deviceService := device.NewService(queries)
	deviceHandler := device.NewHandler(deviceService)
	deviceHandler.RegisterRoutes(protected)

	srv := &http.Server{Addr: ":" + cfg.Port, Handler: r}
	go func() {
		log.Printf("API listening on :%s", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("shutting down...")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("forced shutdown: %v", err)
	}
}
