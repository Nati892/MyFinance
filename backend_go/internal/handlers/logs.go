package handlers

import (
	"household-go/internal/database"
	"household-go/internal/models"
	"household-go/internal/utils"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// LogsHandler handles audit log CRUD (admin only).
type LogsHandler struct{}

func NewLogsHandler() *LogsHandler { return &LogsHandler{} }

// List returns logs with pagination and optional filtering.
// GET /api/logs?page=1&limit=50&level=err
func (h *LogsHandler) List(c *gin.Context) {
	page := max(parseInt(c.DefaultQuery("page", "1")), 1)
	limit := parseInt(c.DefaultQuery("limit", "50"))
	if limit <= 0 || limit > 500 { limit = 50 }
	offset := (page - 1) * limit
	level := c.Query("level")

	query := database.DB.Model(&models.Log{})
	if level != "" {
		query = query.Where("level = ?", level)
	}

	var total int64
	query.Count(&total)

	var logs []models.Log
	query.Order("created_at DESC").Limit(limit).Offset(offset).Find(&logs)

	utils.OK(c, gin.H{
		"success": true,
		"logs":    logs,
		"pagination": gin.H{
			"total": total, "page": page, "limit": limit,
			"pages": (int(total) + limit - 1) / limit,
		},
	})
}

// Get returns a single log entry.
// GET /api/logs/:id
func (h *LogsHandler) Get(c *gin.Context) {
	var entry models.Log
	if err := database.DB.First(&entry, c.Param("id")).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.NotFound(c, "Log not found")
		} else {
			utils.InternalError(c, "Failed to get log")
		}
		return
	}
	utils.OK(c, gin.H{"success": true, "log": entry})
}

// Create records a new log entry (can be called from client).
// POST /api/logs
func (h *LogsHandler) Create(c *gin.Context) {
	var body struct {
		Level   string  `json:"level"   binding:"required"`
		Action  string  `json:"action"  binding:"required"`
		Source  *string `json:"source"`
		Data    *string `json:"data"`
		Path    *string `json:"path"`
		Method  *string `json:"method"`
		UserID  *uint   `json:"userId"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Level and action are required")
		return
	}

	entry := models.Log{
		Level:  body.Level,
		Action: body.Action,
		Source: body.Source,
		Data:   body.Data,
		Path:   body.Path,
		Method: body.Method,
		UserID: body.UserID,
	}
	database.DB.Create(&entry)
	utils.Created(c, gin.H{"success": true, "log": entry})
}

// BatchCreate records multiple log entries at once.
// POST /api/logs/batch
func (h *LogsHandler) BatchCreate(c *gin.Context) {
	var entries []models.Log
	if err := c.ShouldBindJSON(&entries); err != nil {
		utils.BadRequest(c, "Array of log objects is required")
		return
	}
	if len(entries) == 0 {
		utils.BadRequest(c, "At least one log entry is required")
		return
	}
	// GORM's Create() accepts a slice — inserts all rows in one batch INSERT.
	// This is much more efficient than N individual INSERT statements.
	database.DB.Create(&entries)
	utils.Created(c, gin.H{"success": true, "count": len(entries)})
}

// Update modifies a log entry.
// PUT /api/logs/:id
func (h *LogsHandler) Update(c *gin.Context) {
	var entry models.Log
	if err := database.DB.First(&entry, c.Param("id")).Error; err != nil {
		utils.NotFound(c, "Log not found")
		return
	}
	var body map[string]interface{}
	c.ShouldBindJSON(&body)
	database.DB.Model(&entry).Updates(body)
	utils.OK(c, gin.H{"success": true, "log": entry})
}

// Delete removes a log entry.
// DELETE /api/logs/:id
func (h *LogsHandler) Delete(c *gin.Context) {
	var entry models.Log
	if err := database.DB.First(&entry, c.Param("id")).Error; err != nil {
		utils.NotFound(c, "Log not found")
		return
	}
	database.DB.Delete(&entry)
	utils.OK(c, gin.H{"success": true})
}
