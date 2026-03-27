// Package main is the entry point for the Go server.
// In Go, every executable must have exactly one `main` package with a `main()` function.
// `cmd/server/main.go` is the standard layout for Go projects (golang-standards/project-layout).
//
// The flow mirrors your Node index.js startServer():
//   1. Load config (from env vars / .env)
//   2. Connect to DB
//   3. Run migrations
//   4. Seed admin user
//   5. Start HTTP server
package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"household-go/internal/config"
	"household-go/internal/database"
	"household-go/internal/middleware"
	"household-go/internal/routes"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	// Load .env file if present — godotenv.Load() is a no-op if the file doesn't exist.
	// In Docker/production, env vars are injected directly; .env is for local dev.
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found — using system environment variables.")
	}

	// Load config from environment variables
	cfg := config.Load()
	log.Printf("Starting server in %s mode on %s:%s\n", cfg.Env, cfg.BaseAddress, cfg.Port)

	// ── Step 1: Database connection ────────────────────────────────────────────
	if err := database.Connect(cfg); err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// ── Step 2: Auto-migration (CREATE TABLE IF NOT EXISTS + ADD COLUMN) ───────
	if err := database.AutoMigrate(); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	// ── Step 3: Seed default admin user ───────────────────────────────────────
	adminPassword := os.Getenv("ADMIN_PASSWORD")
	if adminPassword == "" {
		adminPassword = "admin123"
	}
	hashed, err := bcrypt.GenerateFromPassword([]byte(adminPassword), cfg.Bcrypt.SaltRounds)
	if err != nil {
		log.Fatalf("Failed to hash admin password: %v", err)
	}
	if err := database.SeedAdmin(string(hashed)); err != nil {
		log.Printf("Warning: failed to seed admin user: %v", err)
	}

	// ── Step 4: Set up Gin router ──────────────────────────────────────────────
	// gin.SetMode controls logging verbosity and panic behavior.
	// ReleaseMode disables colorized debug output and panics-to-500 recovery messages.
	if cfg.Env == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	// gin.New() creates a blank engine — no middleware pre-loaded.
	// gin.Default() would add Logger and Recovery middleware automatically.
	// We add our own so we have full control.
	r := gin.New()

	// Recovery middleware: catches panics and returns 500 instead of crashing.
	// Always include this in production — equivalent to your Koa error handler.
	r.Use(gin.Recovery())

	// Our custom middleware (order matters — CORS must be first)
	r.Use(middleware.CORS())

	// Wire all routes
	routes.Setup(r, cfg)

	// ── Step 5: Start HTTP server ──────────────────────────────────────────────
	// We use net/http.Server directly instead of r.Run() for graceful shutdown support.
	// r.Run() just calls http.ListenAndServe() with no shutdown hook.
	server := &http.Server{
		Addr:    fmt.Sprintf("%s:%s", cfg.BaseAddress, cfg.Port),
		Handler: r,
		// Production timeouts — prevent slow-client attacks and connection exhaustion.
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 60 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// Run the server in a goroutine so we can listen for OS signals concurrently.
	// A goroutine is a lightweight, cooperatively-scheduled thread. `go func()` starts one.
	// This is equivalent to Node's event loop + async callbacks, but explicit.
	go func() {
		log.Printf("Server listening on %s:%s\n", cfg.BaseAddress, cfg.Port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server failed: %v", err)
		}
	}()

	// ── Graceful shutdown ──────────────────────────────────────────────────────
	// signal.Notify sends OS signals (SIGINT = Ctrl+C, SIGTERM = Docker stop) into a channel.
	// Channels are Go's way of communicating between goroutines — like EventEmitter but typed.
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	// Block until we receive a signal — equivalent to `process.on('SIGTERM', ...)`
	<-quit
	log.Println("Shutting down server...")

	// Give in-flight requests up to 10 seconds to finish before the process exits.
	// context.WithTimeout creates a context with a deadline — a Go idiom for cancellation.
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Printf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited cleanly.")
}
