package handlers

import (
	"household-go/internal/database"
	"household-go/internal/models"
	"household-go/internal/utils"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// NotesHandler handles sticky notes CRUD.
type NotesHandler struct{}

func NewNotesHandler() *NotesHandler { return &NotesHandler{} }

// List returns all notes for a household.
// GET /api/app/notes?householdId=X
func (h *NotesHandler) List(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)
	householdID := c.Query("householdId")
	if householdID == "" {
		utils.BadRequest(c, "householdId is required")
		return
	}
	if err := verifyMembership(householdID, appUser.ID); err != nil {
		utils.Forbidden(c, "Not a member of this household")
		return
	}
	var notes []models.Note
	database.DB.Where("household_id = ?", householdID).
		Order("z_index ASC").
		Find(&notes)
	utils.OK(c, gin.H{"success": true, "notes": notes})
}

// Create creates a new note.
// POST /api/app/notes
func (h *NotesHandler) Create(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)

	var body struct {
		Content       *string  `json:"content"`
		PosX          float64  `json:"posX"`
		PosY          float64  `json:"posY"`
		ZIndex        int      `json:"zIndex"`
		Width         float64  `json:"width"`
		Height        float64  `json:"height"`
		Rotation      float64  `json:"rotation"`
		NoteColor     *string  `json:"noteColor"`
		TextDirection *string  `json:"textDirection"`
		TextSize      *string  `json:"textSize"`
		IsBold        bool     `json:"isBold"`
		IsUnderline   bool     `json:"isUnderline"`
		TextColor     *string  `json:"textColor"`
		HeaderColor   *string  `json:"headerColor"`
		Type          string   `json:"type"`
		HeartColor    *string  `json:"heartColor"`
		HouseholdID   uint     `json:"householdId" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "householdId is required")
		return
	}

	if err := verifyMembership(formatUint(body.HouseholdID), appUser.ID); err != nil {
		utils.Forbidden(c, "Not a member of this household")
		return
	}

	noteType := body.Type
	if noteType == "" {
		noteType = "text"
	}
	width := body.Width
	if width == 0 {
		width = 200
	}
	height := body.Height
	if height == 0 {
		height = 200
	}

	note := models.Note{
		Content:       body.Content,
		PosX:          body.PosX,
		PosY:          body.PosY,
		ZIndex:        body.ZIndex,
		Width:         width,
		Height:        height,
		Rotation:      body.Rotation,
		NoteColor:     body.NoteColor,
		TextDirection: body.TextDirection,
		TextSize:      body.TextSize,
		IsBold:        body.IsBold,
		IsUnderline:   body.IsUnderline,
		TextColor:     body.TextColor,
		HeaderColor:   body.HeaderColor,
		Type:          noteType,
		HeartColor:    body.HeartColor,
		HouseholdID:   body.HouseholdID,
		AppUserID:     appUser.ID,
	}
	database.DB.Create(&note)
	utils.Created(c, gin.H{"success": true, "note": note})
}

// Update modifies a note.
// PUT /api/app/notes/:id
func (h *NotesHandler) Update(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)
	id := c.Param("id")

	var note models.Note
	if err := database.DB.First(&note, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.NotFound(c, "Note not found")
		} else {
			utils.InternalError(c, "Failed to update note")
		}
		return
	}

	if err := verifyMembership(formatUint(note.HouseholdID), appUser.ID); err != nil {
		utils.Forbidden(c, "Not a member of this household")
		return
	}

	// For notes, we accept any combination of fields. Use a generic map from JSON.
	// This is a common pattern for flexible partial-update endpoints.
	var body map[string]interface{}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Invalid request body")
		return
	}

	// GORM Updates() with a map updates only the provided keys.
	// Caution: map keys must be the actual DB column names (snake_case).
	// We remap the camelCase JSON keys to snake_case DB column names.
	updates := remapNoteFields(body)
	if len(updates) > 0 {
		database.DB.Model(&note).Updates(updates)
		// Reload
		database.DB.First(&note, id)
	}

	utils.OK(c, gin.H{"success": true, "note": note})
}

// Delete removes a note.
// DELETE /api/app/notes/:id
func (h *NotesHandler) Delete(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)
	id := c.Param("id")

	var note models.Note
	if err := database.DB.First(&note, id).Error; err != nil {
		utils.NotFound(c, "Note not found")
		return
	}

	if err := verifyMembership(formatUint(note.HouseholdID), appUser.ID); err != nil {
		utils.Forbidden(c, "Not a member of this household")
		return
	}

	database.DB.Delete(&note)
	utils.OK(c, gin.H{"success": true})
}

// remapNoteFields translates camelCase JSON field names to snake_case DB columns.
// This is the Go equivalent of Sequelize's automatic camelCase→snake_case mapping.
func remapNoteFields(body map[string]interface{}) map[string]interface{} {
	fieldMap := map[string]string{
		"content": "content", "posX": "pos_x", "posY": "pos_y",
		"zIndex": "z_index", "width": "width", "height": "height",
		"rotation": "rotation", "noteColor": "note_color",
		"textDirection": "text_direction", "textSize": "text_size",
		"isBold": "is_bold", "isUnderline": "is_underline",
		"textColor": "text_color", "headerColor": "header_color",
		"type": "type", "heartColor": "heart_color",
	}
	out := map[string]interface{}{}
	for k, v := range body {
		if col, ok := fieldMap[k]; ok {
			out[col] = v
		}
	}
	return out
}
