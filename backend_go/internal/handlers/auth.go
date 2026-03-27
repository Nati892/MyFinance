// Package handlers contains one file per domain, each exporting handler functions.
// Handler functions receive a *gin.Context and produce an HTTP response.
// This replaces your controllers/*.js files.
//
// KEY CONCEPT — Functions vs Methods:
// In Node you used `class AuthController { async signIn(ctx) {...} }`.
// In Go, we use plain functions. If handlers need shared state (like config),
// we wrap them in a struct with methods — but plain functions work fine when
// the state is injected via closure (as we do here with `cfg`).
package handlers

import (
	"household-go/internal/config"
	"household-go/internal/database"
	"household-go/internal/models"
	"household-go/internal/utils"
	"log"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// AuthHandler groups all admin auth handlers and holds the config it needs.
// This is Go's alternative to a class with instance variables.
type AuthHandler struct {
	cfg *config.Config
}

// NewAuthHandler is a constructor function — the Go convention for "new instance".
// Constructors are just functions that return a pointer to a struct.
func NewAuthHandler(cfg *config.Config) *AuthHandler {
	return &AuthHandler{cfg: cfg}
}

// SignUp creates a new admin user.
// POST /api/auth/signup
func (h *AuthHandler) SignUp(c *gin.Context) {
	// ShouldBindJSON deserializes the request body into the struct.
	// It respects the `json:"..."` tags. Returns an error if the body is malformed.
	// This replaces `ctx.request.body` in Koa.
	var body struct {
		Username string `json:"username" binding:"required"`
		Email    string `json:"email"    binding:"required"`
		Password string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Username, email, and password are required")
		return
	}

	if len(body.Password) < 6 {
		utils.BadRequest(c, "Password must be at least 6 characters long")
		return
	}

	// Check for duplicate username OR email with a single query.
	// GORM's Or() condition mirrors Sequelize's Op.or.
	var existing models.User
	result := database.DB.Where("username = ? OR email = ?", body.Username, body.Email).First(&existing)
	if result.Error == nil {
		// A record was found — determine which field conflicted
		if existing.Username == body.Username {
			utils.Conflict(c, "Username already exists")
		} else {
			utils.Conflict(c, "Email already exists")
		}
		return
	}
	if result.Error != gorm.ErrRecordNotFound {
		log.Printf("SignUp DB error: %v", result.Error)
		utils.InternalError(c, "Failed to create user")
		return
	}

	// bcrypt.GenerateFromPassword is the Go equivalent of bcryptjs.hash().
	// The cost parameter corresponds to your bcrypt.saltRounds config.
	hashed, err := bcrypt.GenerateFromPassword([]byte(body.Password), h.cfg.Bcrypt.SaltRounds)
	if err != nil {
		utils.InternalError(c, "Failed to create user")
		return
	}

	user := models.User{
		Username: body.Username,
		Email:    body.Email,
		Password: string(hashed),
		IsActive: true,
	}

	// GORM Create() inserts the record and populates the ID and timestamps.
	// Equivalent to Sequelize's Model.create({...}).
	if err := database.DB.Create(&user).Error; err != nil {
		utils.InternalError(c, "Failed to create user")
		return
	}

	token, err := utils.GenerateToken(user.ID, user.Username, h.cfg.JWT.Secret, h.cfg.JWT.ExpiresIn)
	if err != nil {
		utils.InternalError(c, "Failed to create user")
		return
	}

	// gin.H is map[string]any — the idiomatic way to build an inline JSON object.
	utils.Created(c, gin.H{"success": true, "token": token, "user": user})
}

// SignIn authenticates an admin user by username or email.
// POST /api/auth/signin
func (h *AuthHandler) SignIn(c *gin.Context) {
	var body struct {
		Username string `json:"username" binding:"required"`
		Password string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Username and password are required")
		return
	}

	// Find by username OR email (same as your auth.js signIn)
	var user models.User
	result := database.DB.Where("username = ? OR email = ?", body.Username, body.Username).First(&user)
	if result.Error == gorm.ErrRecordNotFound {
		utils.Unauthorized(c, "Invalid credentials")
		return
	}
	if result.Error != nil {
		utils.InternalError(c, "Failed to sign in")
		return
	}

	if !user.IsActive {
		utils.Unauthorized(c, "Account is deactivated")
		return
	}

	// bcrypt.CompareHashAndPassword is the Go equivalent of bcryptjs.compare().
	// Returns nil if the password matches, bcrypt.ErrMismatchedHashAndPassword otherwise.
	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(body.Password)); err != nil {
		utils.Unauthorized(c, "Invalid credentials")
		return
	}

	// Update lastLogin — GORM's Save/Updates on a pointer field
	now := database.DB.Model(&user).Update("last_login", gorm.Expr("NOW()"))
	if now.Error != nil {
		log.Printf("Failed to update lastLogin: %v", now.Error)
		// Non-fatal — proceed with login
	}

	token, err := utils.GenerateToken(user.ID, user.Username, h.cfg.JWT.Secret, h.cfg.JWT.ExpiresIn)
	if err != nil {
		utils.InternalError(c, "Failed to sign in")
		return
	}

	utils.OK(c, gin.H{"success": true, "token": token, "user": user})
}

// GetProfile returns the authenticated admin user's profile.
// GET /api/auth/profile
func (h *AuthHandler) GetProfile(c *gin.Context) {
	// c.MustGet() panics if the key is not set — safe to use after Authenticate middleware.
	// The type assertion `.(type)` extracts the concrete type from the interface{} value.
	user := c.MustGet("authUser").(*models.User)
	utils.OK(c, gin.H{"success": true, "user": user})
}

// UpdateProfile changes the admin user's username and/or email.
// PUT /api/auth/profile
func (h *AuthHandler) UpdateProfile(c *gin.Context) {
	user := c.MustGet("authUser").(*models.User)

	var body struct {
		Username string `json:"username"`
		Email    string `json:"email"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Invalid request body")
		return
	}

	// Check for conflicts with other users
	if (body.Username != "" && body.Username != user.Username) ||
		(body.Email != "" && body.Email != user.Email) {

		var existing models.User
		query := database.DB.Where("id != ?", user.ID)
		if body.Username != "" && body.Username != user.Username {
			query = query.Where("username = ?", body.Username)
		} else if body.Email != "" && body.Email != user.Email {
			query = query.Where("email = ?", body.Email)
		}

		if query.First(&existing).Error == nil {
			if existing.Username == body.Username {
				utils.Conflict(c, "Username already exists")
			} else {
				utils.Conflict(c, "Email already exists")
			}
			return
		}
	}

	// GORM Updates() with a struct only updates non-zero fields.
	// Use a map to update specific fields regardless of zero value.
	updates := map[string]interface{}{}
	if body.Username != "" {
		updates["username"] = body.Username
	}
	if body.Email != "" {
		updates["email"] = body.Email
	}
	if len(updates) > 0 {
		database.DB.Model(user).Updates(updates)
	}

	utils.OK(c, gin.H{"success": true, "user": user})
}

// ChangePassword updates the admin user's password after verifying the current one.
// PUT /api/auth/password
func (h *AuthHandler) ChangePassword(c *gin.Context) {
	user := c.MustGet("authUser").(*models.User)

	var body struct {
		CurrentPassword string `json:"currentPassword" binding:"required"`
		NewPassword     string `json:"newPassword"     binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Current password and new password are required")
		return
	}

	if len(body.NewPassword) < 6 {
		utils.BadRequest(c, "New password must be at least 6 characters long")
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(body.CurrentPassword)); err != nil {
		utils.Unauthorized(c, "Current password is incorrect")
		return
	}

	hashed, err := bcrypt.GenerateFromPassword([]byte(body.NewPassword), h.cfg.Bcrypt.SaltRounds)
	if err != nil {
		utils.InternalError(c, "Failed to change password")
		return
	}

	database.DB.Model(user).Update("password", string(hashed))
	utils.OK(c, gin.H{"success": true, "message": "Password changed successfully"})
}

// RefreshToken issues a new JWT for an already-authenticated admin user.
// POST /api/auth/refresh
func (h *AuthHandler) RefreshToken(c *gin.Context) {
	user := c.MustGet("authUser").(*models.User)

	token, err := utils.GenerateToken(user.ID, user.Username, h.cfg.JWT.Secret, h.cfg.JWT.ExpiresIn)
	if err != nil {
		utils.InternalError(c, "Failed to refresh token")
		return
	}

	utils.OK(c, gin.H{"success": true, "token": token})
}
