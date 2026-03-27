package handlers

import (
	"household-go/internal/database"
	"household-go/internal/models"
	"household-go/internal/utils"
	"log"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// HouseholdsHandler handles household CRUD and member management.
type HouseholdsHandler struct{}

func NewHouseholdsHandler() *HouseholdsHandler { return &HouseholdsHandler{} }

// List returns paginated households with member counts.
// GET /api/households?page=1&limit=20
func (h *HouseholdsHandler) List(c *gin.Context) {
	page := max(parseInt(c.DefaultQuery("page", "1")), 1)
	limit := parseInt(c.DefaultQuery("limit", "20"))
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	offset := (page - 1) * limit

	var total int64
	var households []models.Household

	// Count and query in parallel — two separate DB calls.
	// GORM doesn't have a findAndCountAll() like Sequelize; you do it manually.
	database.DB.Model(&models.Household{}).Count(&total)
	database.DB.
		Preload("Members", func(db *gorm.DB) *gorm.DB {
			// Preload nested associations: Members → AppUser
			return db.Preload("AppUser", func(db *gorm.DB) *gorm.DB {
				return db.Select("id, username")
			})
		}).
		Order("created_at DESC").
		Limit(limit).
		Offset(offset).
		Find(&households)

	pages := int((total + int64(limit) - 1) / int64(limit)) // ceiling division

	utils.OK(c, gin.H{
		"success":    true,
		"households": households,
		"pagination": gin.H{
			"total": total,
			"page":  page,
			"limit": limit,
			"pages": pages,
		},
	})
}

// Get returns a single household with full member list and categories.
// GET /api/households/:id
func (h *HouseholdsHandler) Get(c *gin.Context) {
	id := c.Param("id")

	var household models.Household
	err := database.DB.
		Preload("Members", func(db *gorm.DB) *gorm.DB {
			return db.Preload("AppUser", func(db *gorm.DB) *gorm.DB {
				return db.Select("id, username, is_active, last_login, created_at")
			})
		}).
		Preload("ExpenseCategories").
		Preload("IncomeCategories").
		First(&household, id).Error

	if err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.NotFound(c, "Household not found")
		} else {
			utils.InternalError(c, "Failed to get household")
		}
		return
	}

	utils.OK(c, gin.H{"success": true, "household": household})
}

// Create creates a new household.
// POST /api/households
func (h *HouseholdsHandler) Create(c *gin.Context) {
	var body struct {
		Name        string  `json:"name"        binding:"required"`
		Description *string `json:"description"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Name is required")
		return
	}

	household := models.Household{Name: body.Name, Description: body.Description}
	if err := database.DB.Create(&household).Error; err != nil {
		log.Printf("Create household error: %v", err)
		utils.InternalError(c, "Failed to create household")
		return
	}

	utils.Created(c, gin.H{"success": true, "household": household})
}

// Update changes a household's name and/or description.
// PUT /api/households/:id
func (h *HouseholdsHandler) Update(c *gin.Context) {
	id := c.Param("id")

	var household models.Household
	if err := database.DB.First(&household, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.NotFound(c, "Household not found")
		} else {
			utils.InternalError(c, "Failed to update household")
		}
		return
	}

	var body struct {
		Name        *string `json:"name"`
		Description *string `json:"description"`
	}
	c.ShouldBindJSON(&body)

	updates := map[string]interface{}{}
	if body.Name != nil        { updates["name"] = *body.Name }
	if body.Description != nil { updates["description"] = body.Description }

	if len(updates) > 0 {
		database.DB.Model(&household).Updates(updates)
	}

	utils.OK(c, gin.H{"success": true, "household": household})
}

// Delete removes a household.
// DELETE /api/households/:id
func (h *HouseholdsHandler) Delete(c *gin.Context) {
	id := c.Param("id")

	var household models.Household
	if err := database.DB.First(&household, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.NotFound(c, "Household not found")
		} else {
			utils.InternalError(c, "Failed to delete household")
		}
		return
	}

	database.DB.Delete(&household)
	utils.OK(c, gin.H{"success": true})
}

// AddMember adds an AppUser to a household.
// POST /api/households/:id/members
func (h *HouseholdsHandler) AddMember(c *gin.Context) {
	id := c.Param("id")

	var body struct {
		AppUserID uint   `json:"appUserId" binding:"required"`
		Role      string `json:"role"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "appUserId is required")
		return
	}

	var household models.Household
	if err := database.DB.First(&household, id).Error; err != nil {
		utils.NotFound(c, "Household not found")
		return
	}

	var appUser models.AppUser
	if err := database.DB.First(&appUser, body.AppUserID).Error; err != nil {
		utils.NotFound(c, "App user not found")
		return
	}

	// Check for existing membership
	var existing models.HouseholdMember
	if database.DB.Where("household_id = ? AND app_user_id = ?", id, body.AppUserID).First(&existing).Error == nil {
		utils.Conflict(c, "User is already a member of this household")
		return
	}

	role := body.Role
	if role == "" {
		role = "member"
	}

	member := models.HouseholdMember{
		HouseholdID: household.ID,
		AppUserID:   body.AppUserID,
		Role:        role,
	}
	database.DB.Create(&member)

	var members []models.HouseholdMember
	database.DB.Where("household_id = ?", id).
		Preload("AppUser", func(db *gorm.DB) *gorm.DB {
			return db.Select("id, username, is_active")
		}).Find(&members)

	utils.Created(c, gin.H{"success": true, "members": members})
}

// RemoveMember removes an AppUser from a household.
// DELETE /api/households/:id/members/:appUserId
func (h *HouseholdsHandler) RemoveMember(c *gin.Context) {
	id := c.Param("id")
	appUserID := c.Param("appUserId")

	var member models.HouseholdMember
	if err := database.DB.Where("household_id = ? AND app_user_id = ?", id, appUserID).
		First(&member).Error; err != nil {
		utils.NotFound(c, "Household member not found")
		return
	}

	database.DB.Delete(&member)
	utils.OK(c, gin.H{"success": true})
}

// UpdateMemberRole changes a member's role in a household.
// PUT /api/households/:id/members/:appUserId
func (h *HouseholdsHandler) UpdateMemberRole(c *gin.Context) {
	id := c.Param("id")
	appUserID := c.Param("appUserId")

	var body struct {
		Role string `json:"role" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Role is required")
		return
	}

	var member models.HouseholdMember
	if err := database.DB.Where("household_id = ? AND app_user_id = ?", id, appUserID).
		First(&member).Error; err != nil {
		utils.NotFound(c, "Household member not found")
		return
	}

	database.DB.Model(&member).Update("role", body.Role)

	database.DB.Where("household_id = ? AND app_user_id = ?", id, appUserID).
		Preload("AppUser", func(db *gorm.DB) *gorm.DB {
			return db.Select("id, username, is_active")
		}).First(&member)

	utils.OK(c, gin.H{"success": true, "member": member})
}

// max returns the larger of two ints — Go 1.21+ has built-in max(), but we define
// it here for clarity. In Go 1.21+, you can remove this and use the builtin.
func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
