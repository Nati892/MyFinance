package handlers

import (
	"household-go/internal/database"
	"household-go/internal/models"
	"household-go/internal/utils"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// AssetsHandler handles asset CRUD and reordering.
type AssetsHandler struct{}

func NewAssetsHandler() *AssetsHandler { return &AssetsHandler{} }

// List returns all assets for a household.
// GET /api/app/assets?householdId=X
func (h *AssetsHandler) List(c *gin.Context) {
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
	var assets []models.Asset
	database.DB.Where("household_id = ?", householdID).Order("sort_order ASC").Find(&assets)
	utils.OK(c, gin.H{"success": true, "assets": assets})
}

// Create adds a new asset.
// POST /api/app/assets
func (h *AssetsHandler) Create(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)
	var body struct {
		Name        string     `json:"name"        binding:"required"`
		Value       float64    `json:"value"`
		Liquidity   *string    `json:"liquidity"`
		Description *string    `json:"description"`
		SortOrder   int        `json:"sortOrder"`
		Date        *string    `json:"date"`
		HouseholdID uint       `json:"householdId" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Name and householdId are required")
		return
	}
	if err := verifyMembership(formatUint(body.HouseholdID), appUser.ID); err != nil {
		utils.Forbidden(c, "Not a member of this household")
		return
	}

	asset := models.Asset{
		Name:        body.Name,
		Value:       body.Value,
		Liquidity:   body.Liquidity,
		Description: body.Description,
		SortOrder:   body.SortOrder,
		HouseholdID: body.HouseholdID,
	}
	if body.Date != nil {
		t, err := parseDateTime(*body.Date)
		if err == nil {
			asset.Date = &t
		}
	}
	database.DB.Create(&asset)
	utils.Created(c, gin.H{"success": true, "asset": asset})
}

// Update modifies an asset.
// PUT /api/app/assets/:id
func (h *AssetsHandler) Update(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)
	id := c.Param("id")

	var asset models.Asset
	if err := database.DB.First(&asset, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.NotFound(c, "Asset not found")
		} else {
			utils.InternalError(c, "Failed to update asset")
		}
		return
	}
	if err := verifyMembership(formatUint(asset.HouseholdID), appUser.ID); err != nil {
		utils.Forbidden(c, "Not a member of this household")
		return
	}

	var body struct {
		Name        *string  `json:"name"`
		Value       *float64 `json:"value"`
		Liquidity   *string  `json:"liquidity"`
		Description *string  `json:"description"`
		SortOrder   *int     `json:"sortOrder"`
		Date        *string  `json:"date"`
	}
	c.ShouldBindJSON(&body)

	updates := map[string]interface{}{}
	if body.Name != nil        { updates["name"] = *body.Name }
	if body.Value != nil       { updates["value"] = *body.Value }
	if body.Liquidity != nil   { updates["liquidity"] = body.Liquidity }
	if body.Description != nil { updates["description"] = body.Description }
	if body.SortOrder != nil   { updates["sort_order"] = *body.SortOrder }
	if body.Date != nil {
		t, err := parseDateTime(*body.Date)
		if err == nil {
			updates["date"] = t
		}
	}
	if len(updates) > 0 {
		database.DB.Model(&asset).Updates(updates)
	}
	utils.OK(c, gin.H{"success": true, "asset": asset})
}

// Delete removes an asset.
// DELETE /api/app/assets/:id
func (h *AssetsHandler) Delete(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)
	id := c.Param("id")
	var asset models.Asset
	if err := database.DB.First(&asset, id).Error; err != nil {
		utils.NotFound(c, "Asset not found")
		return
	}
	if err := verifyMembership(formatUint(asset.HouseholdID), appUser.ID); err != nil {
		utils.Forbidden(c, "Not a member of this household")
		return
	}
	database.DB.Delete(&asset)
	utils.OK(c, gin.H{"success": true})
}

// Reorder updates sort order for multiple assets in a transaction.
// PUT /api/app/assets/reorder
func (h *AssetsHandler) Reorder(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)
	var body []struct {
		ID          uint `json:"id"`
		SortOrder   int  `json:"sortOrder"`
		HouseholdID uint `json:"householdId"`
	}
	if err := c.ShouldBindJSON(&body); err != nil || len(body) == 0 {
		utils.BadRequest(c, "Array of { id, sortOrder } is required")
		return
	}

	// Verify membership for the first item's household (all should be same household)
	if len(body) > 0 {
		if err := verifyMembership(formatUint(body[0].HouseholdID), appUser.ID); err != nil {
			utils.Forbidden(c, "Not a member of this household")
			return
		}
	}

	err := database.DB.Transaction(func(tx *gorm.DB) error {
		for _, item := range body {
			if err := tx.Model(&models.Asset{}).
				Where("id = ?", item.ID).
				Update("sort_order", item.SortOrder).Error; err != nil {
				return err
			}
		}
		return nil
	})

	if err != nil {
		utils.InternalError(c, "Failed to reorder assets")
		return
	}
	utils.OK(c, gin.H{"success": true})
}
