package handlers

import (
	"household-go/internal/config"
	"household-go/internal/database"
	"household-go/internal/models"
	"household-go/internal/utils"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// AppUsersHandler manages AppUser accounts (admin-only endpoints).
type AppUsersHandler struct {
	cfg *config.Config
}

func NewAppUsersHandler(cfg *config.Config) *AppUsersHandler {
	return &AppUsersHandler{cfg: cfg}
}

// List returns all app users (paginated).
// GET /api/app-users
func (h *AppUsersHandler) List(c *gin.Context) {
	page := max(parseInt(c.DefaultQuery("page", "1")), 1)
	limit := parseInt(c.DefaultQuery("limit", "20"))
	if limit <= 0 { limit = 20 }
	offset := (page - 1) * limit

	var total int64
	var users []models.AppUser
	database.DB.Model(&models.AppUser{}).Count(&total)
	database.DB.Order("created_at DESC").Limit(limit).Offset(offset).Find(&users)

	utils.OK(c, gin.H{
		"success": true,
		"users":   users,
		"pagination": gin.H{
			"total": total, "page": page, "limit": limit,
			"pages": (int(total) + limit - 1) / limit,
		},
	})
}

// Get returns a single app user.
// GET /api/app-users/:id
func (h *AppUsersHandler) Get(c *gin.Context) {
	var user models.AppUser
	if err := database.DB.First(&user, c.Param("id")).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.NotFound(c, "App user not found")
		} else {
			utils.InternalError(c, "Failed to get app user")
		}
		return
	}
	utils.OK(c, gin.H{"success": true, "user": user})
}

// Create creates a new app user.
// POST /api/app-users
func (h *AppUsersHandler) Create(c *gin.Context) {
	var body struct {
		Username string `json:"username" binding:"required"`
		Password string `json:"password" binding:"required"`
		IsActive *bool  `json:"isActive"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Username and password are required")
		return
	}

	var existing models.AppUser
	if database.DB.Where("username = ?", body.Username).First(&existing).Error == nil {
		utils.Conflict(c, "Username already exists")
		return
	}

	hashed, err := bcrypt.GenerateFromPassword([]byte(body.Password), h.cfg.Bcrypt.SaltRounds)
	if err != nil {
		utils.InternalError(c, "Failed to create app user")
		return
	}

	isActive := true
	if body.IsActive != nil {
		isActive = *body.IsActive
	}

	user := models.AppUser{
		Username: body.Username,
		Password: string(hashed),
		IsActive: isActive,
	}
	database.DB.Create(&user)
	utils.Created(c, gin.H{"success": true, "user": user})
}

// Update updates an app user's username and/or active status.
// PUT /api/app-users/:id
func (h *AppUsersHandler) Update(c *gin.Context) {
	var user models.AppUser
	if err := database.DB.First(&user, c.Param("id")).Error; err != nil {
		utils.NotFound(c, "App user not found")
		return
	}

	var body struct {
		Username *string `json:"username"`
		IsActive *bool   `json:"isActive"`
	}
	c.ShouldBindJSON(&body)

	updates := map[string]interface{}{}
	if body.Username != nil { updates["username"] = *body.Username }
	if body.IsActive != nil { updates["is_active"] = *body.IsActive }
	if len(updates) > 0 {
		database.DB.Model(&user).Updates(updates)
	}
	utils.OK(c, gin.H{"success": true, "user": user})
}

// ResetPassword sets a new password for an app user (admin action).
// PUT /api/app-users/:id/password
func (h *AppUsersHandler) ResetPassword(c *gin.Context) {
	var user models.AppUser
	if err := database.DB.First(&user, c.Param("id")).Error; err != nil {
		utils.NotFound(c, "App user not found")
		return
	}

	var body struct {
		Password string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Password is required")
		return
	}

	hashed, err := bcrypt.GenerateFromPassword([]byte(body.Password), h.cfg.Bcrypt.SaltRounds)
	if err != nil {
		utils.InternalError(c, "Failed to reset password")
		return
	}

	database.DB.Model(&user).Update("password", string(hashed))
	utils.OK(c, gin.H{"success": true})
}

// Delete removes an app user.
// DELETE /api/app-users/:id
func (h *AppUsersHandler) Delete(c *gin.Context) {
	var user models.AppUser
	if err := database.DB.First(&user, c.Param("id")).Error; err != nil {
		utils.NotFound(c, "App user not found")
		return
	}
	database.DB.Delete(&user)
	utils.OK(c, gin.H{"success": true})
}
