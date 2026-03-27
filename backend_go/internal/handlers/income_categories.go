package handlers

import (
	"household-go/internal/database"
	"household-go/internal/models"
	"household-go/internal/utils"

	"github.com/gin-gonic/gin"
)

// IncomeCategoriesHandler mirrors ExpenseCategoriesHandler for income categories.
type IncomeCategoriesHandler struct{}

func NewIncomeCategoriesHandler() *IncomeCategoriesHandler {
	return &IncomeCategoriesHandler{}
}

func (h *IncomeCategoriesHandler) AdminList(c *gin.Context) {
	var categories []models.IncomeCategory
	database.DB.Order("sort_order ASC").Find(&categories)
	utils.OK(c, gin.H{"success": true, "categories": categories})
}

func (h *IncomeCategoriesHandler) AdminCreate(c *gin.Context) {
	var body struct {
		Name        string  `json:"name"        binding:"required"`
		NameHe      *string `json:"nameHe"`
		Icon        *string `json:"icon"`
		Color       *string `json:"color"`
		SortOrder   int     `json:"sortOrder"`
		HouseholdID uint    `json:"householdId" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Name and householdId are required")
		return
	}
	cat := models.IncomeCategory{
		Name:        body.Name,
		NameHe:      body.NameHe,
		Icon:        body.Icon,
		Color:       body.Color,
		SortOrder:   body.SortOrder,
		HouseholdID: body.HouseholdID,
	}
	database.DB.Create(&cat)
	utils.Created(c, gin.H{"success": true, "category": cat})
}

func (h *IncomeCategoriesHandler) AdminUpdate(c *gin.Context) {
	id := c.Param("id")
	var cat models.IncomeCategory
	if err := database.DB.First(&cat, id).Error; err != nil {
		utils.NotFound(c, "Category not found")
		return
	}
	var body struct {
		Name      *string `json:"name"`
		NameHe    *string `json:"nameHe"`
		Icon      *string `json:"icon"`
		Color     *string `json:"color"`
		SortOrder *int    `json:"sortOrder"`
	}
	c.ShouldBindJSON(&body)
	updates := map[string]interface{}{}
	if body.Name != nil      { updates["name"] = *body.Name }
	if body.NameHe != nil    { updates["name_he"] = body.NameHe }
	if body.Icon != nil      { updates["icon"] = body.Icon }
	if body.Color != nil     { updates["color"] = body.Color }
	if body.SortOrder != nil { updates["sort_order"] = *body.SortOrder }
	if len(updates) > 0 {
		database.DB.Model(&cat).Updates(updates)
	}
	utils.OK(c, gin.H{"success": true, "category": cat})
}

func (h *IncomeCategoriesHandler) AdminDelete(c *gin.Context) {
	id := c.Param("id")
	var cat models.IncomeCategory
	if err := database.DB.First(&cat, id).Error; err != nil {
		utils.NotFound(c, "Category not found")
		return
	}
	database.DB.Delete(&cat)
	utils.OK(c, gin.H{"success": true})
}

func (h *IncomeCategoriesHandler) AppList(c *gin.Context) {
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
	var categories []models.IncomeCategory
	database.DB.Where("household_id = ?", householdID).Order("sort_order ASC").Find(&categories)
	utils.OK(c, gin.H{"success": true, "categories": categories})
}

func (h *IncomeCategoriesHandler) AppCreate(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)
	var body struct {
		Name        string  `json:"name"        binding:"required"`
		NameHe      *string `json:"nameHe"`
		Icon        *string `json:"icon"`
		Color       *string `json:"color"`
		HouseholdID uint    `json:"householdId" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Name and householdId are required")
		return
	}
	if err := verifyMembership(formatUint(body.HouseholdID), appUser.ID); err != nil {
		utils.Forbidden(c, "Not a member of this household")
		return
	}
	cat := models.IncomeCategory{
		Name:        body.Name,
		NameHe:      body.NameHe,
		Icon:        body.Icon,
		Color:       body.Color,
		HouseholdID: body.HouseholdID,
	}
	database.DB.Create(&cat)
	utils.Created(c, gin.H{"success": true, "category": cat})
}
