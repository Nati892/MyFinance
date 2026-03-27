package handlers

import (
	"household-go/internal/database"
	"household-go/internal/models"
	"household-go/internal/utils"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// SettingsHandler manages key-value server settings.
type SettingsHandler struct{}

func NewSettingsHandler() *SettingsHandler { return &SettingsHandler{} }

// List returns all settings.
// GET /api/settings
func (h *SettingsHandler) List(c *gin.Context) {
	var settings []models.Setting
	database.DB.Order("key ASC").Find(&settings)
	utils.OK(c, gin.H{"success": true, "settings": settings})
}

// GetConfig returns only settings with sendWithConfig = true (for frontend config).
// GET /api/settings/config
func (h *SettingsHandler) GetConfig(c *gin.Context) {
	var settings []models.Setting
	database.DB.Where("send_with_config = ?", true).Find(&settings)

	// Build a flat key→value map (what the frontend expects)
	configMap := make(map[string]interface{})
	for _, s := range settings {
		if s.Value != nil {
			configMap[s.Key] = *s.Value
		} else {
			configMap[s.Key] = nil
		}
	}

	utils.OK(c, gin.H{"success": true, "config": configMap})
}

// Get returns a single setting.
// GET /api/settings/:id
func (h *SettingsHandler) Get(c *gin.Context) {
	var setting models.Setting
	if err := database.DB.First(&setting, c.Param("id")).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.NotFound(c, "Setting not found")
		} else {
			utils.InternalError(c, "Failed to get setting")
		}
		return
	}
	utils.OK(c, gin.H{"success": true, "setting": setting})
}

// Create creates a new setting.
// POST /api/settings
func (h *SettingsHandler) Create(c *gin.Context) {
	var body struct {
		Key            string  `json:"key"            binding:"required"`
		Value          *string `json:"value"`
		Description    *string `json:"description"`
		CoreSetting    bool    `json:"core_setting"`
		SendWithConfig bool    `json:"sendWithConfig"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Key is required")
		return
	}

	setting := models.Setting{
		Key:            body.Key,
		Value:          body.Value,
		Description:    body.Description,
		CoreSetting:    body.CoreSetting,
		SendWithConfig: body.SendWithConfig,
	}
	if err := database.DB.Create(&setting).Error; err != nil {
		utils.InternalError(c, "Failed to create setting")
		return
	}
	utils.Created(c, gin.H{"success": true, "setting": setting})
}

// Update modifies a setting's value and metadata.
// PUT /api/settings/:id
func (h *SettingsHandler) Update(c *gin.Context) {
	var setting models.Setting
	if err := database.DB.First(&setting, c.Param("id")).Error; err != nil {
		utils.NotFound(c, "Setting not found")
		return
	}

	var body struct {
		Value          *string `json:"value"`
		Description    *string `json:"description"`
		SendWithConfig *bool   `json:"sendWithConfig"`
	}
	c.ShouldBindJSON(&body)

	updates := map[string]interface{}{}
	if body.Value != nil          { updates["value"] = body.Value }
	if body.Description != nil    { updates["description"] = body.Description }
	if body.SendWithConfig != nil { updates["send_with_config"] = *body.SendWithConfig }
	if len(updates) > 0 {
		database.DB.Model(&setting).Updates(updates)
	}
	utils.OK(c, gin.H{"success": true, "setting": setting})
}

// Delete removes a setting (only if it's not a core setting).
// DELETE /api/settings/:id
func (h *SettingsHandler) Delete(c *gin.Context) {
	var setting models.Setting
	if err := database.DB.First(&setting, c.Param("id")).Error; err != nil {
		utils.NotFound(c, "Setting not found")
		return
	}
	if setting.CoreSetting {
		utils.Forbidden(c, "Cannot delete a core setting")
		return
	}
	database.DB.Delete(&setting)
	utils.OK(c, gin.H{"success": true})
}

// BulkUpdate updates multiple settings by key.
// POST /api/settings/bulk-update
// Body: [{ key: "theme", value: "dark" }, ...]
func (h *SettingsHandler) BulkUpdate(c *gin.Context) {
	var body []struct {
		Key   string  `json:"key"   binding:"required"`
		Value *string `json:"value"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Array of { key, value } is required")
		return
	}

	err := database.DB.Transaction(func(tx *gorm.DB) error {
		for _, item := range body {
			if err := tx.Model(&models.Setting{}).
				Where("`key` = ?", item.Key).
				Update("value", item.Value).Error; err != nil {
				return err
			}
		}
		return nil
	})

	if err != nil {
		utils.InternalError(c, "Failed to bulk update settings")
		return
	}

	utils.OK(c, gin.H{"success": true})
}
