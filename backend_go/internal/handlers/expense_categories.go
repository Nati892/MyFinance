package handlers

import (
	"household-go/internal/database"
	"household-go/internal/models"
	"household-go/internal/utils"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// ExpenseCategoriesHandler manages expense categories (admin + app routes).
type ExpenseCategoriesHandler struct{}

func NewExpenseCategoriesHandler() *ExpenseCategoriesHandler {
	return &ExpenseCategoriesHandler{}
}

// AdminList returns all expense categories (admin view, not scoped to a household).
// GET /api/admin/expense-categories
func (h *ExpenseCategoriesHandler) AdminList(c *gin.Context) {
	var categories []models.ExpenseCategory
	database.DB.Order("sort_order ASC").Find(&categories)
	utils.OK(c, gin.H{"success": true, "categories": categories})
}

// AdminCreate creates a new expense category (admin only).
// POST /api/admin/expense-categories
func (h *ExpenseCategoriesHandler) AdminCreate(c *gin.Context) {
	var body struct {
		Name        string   `json:"name"        binding:"required"`
		NameHe      *string  `json:"nameHe"`
		Icon        *string  `json:"icon"`
		Color       *string  `json:"color"`
		SortOrder   int      `json:"sortOrder"`
		HouseholdID uint     `json:"householdId" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Name and householdId are required")
		return
	}

	cat := models.ExpenseCategory{
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

// AdminUpdate updates an expense category.
// PUT /api/admin/expense-categories/:id
func (h *ExpenseCategoriesHandler) AdminUpdate(c *gin.Context) {
	id := c.Param("id")
	var cat models.ExpenseCategory
	if err := database.DB.First(&cat, id).Error; err != nil {
		utils.NotFound(c, "Category not found")
		return
	}

	var body struct {
		Name      *string  `json:"name"`
		NameHe    *string  `json:"nameHe"`
		Icon      *string  `json:"icon"`
		Color     *string  `json:"color"`
		SortOrder *int     `json:"sortOrder"`
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

// AdminDelete deletes an expense category.
// DELETE /api/admin/expense-categories/:id
func (h *ExpenseCategoriesHandler) AdminDelete(c *gin.Context) {
	id := c.Param("id")
	var cat models.ExpenseCategory
	if err := database.DB.First(&cat, id).Error; err != nil {
		utils.NotFound(c, "Category not found")
		return
	}
	database.DB.Delete(&cat)
	utils.OK(c, gin.H{"success": true})
}

// AdminReorder updates sortOrder for a batch of categories.
// PUT /api/admin/expense-categories/reorder
// Body: [{ id: 1, sortOrder: 0 }, { id: 2, sortOrder: 1 }, ...]
func (h *ExpenseCategoriesHandler) AdminReorder(c *gin.Context) {
	var body []struct {
		ID        uint `json:"id"        binding:"required"`
		SortOrder int  `json:"sortOrder"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Array of { id, sortOrder } is required")
		return
	}

	// Run updates in a transaction — either all succeed or all fail.
	// This is the Go equivalent of a Sequelize transaction.
	// Transaction() takes a function; if it returns an error, the TX is rolled back.
	err := database.DB.Transaction(func(tx *gorm.DB) error {
		for _, item := range body {
			// Update only the sortOrder field for each category
			if err := tx.Model(&models.ExpenseCategory{}).
				Where("id = ?", item.ID).
				Update("sort_order", item.SortOrder).Error; err != nil {
				return err // Returning non-nil triggers rollback
			}
		}
		return nil // nil = commit
	})

	if err != nil {
		utils.InternalError(c, "Failed to reorder categories")
		return
	}

	utils.OK(c, gin.H{"success": true})
}

// AppList returns expense categories for a specific household (app route).
// GET /api/app/expense-categories?householdId=X
func (h *ExpenseCategoriesHandler) AppList(c *gin.Context) {
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

	var categories []models.ExpenseCategory
	database.DB.Where("household_id = ?", householdID).
		Order("sort_order ASC").
		Find(&categories)

	utils.OK(c, gin.H{"success": true, "categories": categories})
}

// AppCreate creates an expense category (app route — within a household).
// POST /api/app/expense-categories
func (h *ExpenseCategoriesHandler) AppCreate(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)

	var body struct {
		Name        string   `json:"name"        binding:"required"`
		NameHe      *string  `json:"nameHe"`
		Icon        *string  `json:"icon"`
		Color       *string  `json:"color"`
		HouseholdID uint     `json:"householdId" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Name and householdId are required")
		return
	}

	if err := verifyMembership(formatUint(body.HouseholdID), appUser.ID); err != nil {
		utils.Forbidden(c, "Not a member of this household")
		return
	}

	cat := models.ExpenseCategory{
		Name:        body.Name,
		NameHe:      body.NameHe,
		Icon:        body.Icon,
		Color:       body.Color,
		HouseholdID: body.HouseholdID,
	}
	database.DB.Create(&cat)
	utils.Created(c, gin.H{"success": true, "category": cat})
}

// AppSetBudget sets the monthly budget on a category (via the budget routes, but kept here for clarity).
// PUT /api/app/expense-categories/:id/budget
func (h *ExpenseCategoriesHandler) AppSetBudget(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)
	id := c.Param("id")

	var cat models.ExpenseCategory
	if err := database.DB.First(&cat, id).Error; err != nil {
		utils.NotFound(c, "Category not found")
		return
	}

	if err := verifyMembership(formatUint(cat.HouseholdID), appUser.ID); err != nil {
		utils.Forbidden(c, "Not a member of this household")
		return
	}

	var body struct {
		MonthlyBudget *float64 `json:"monthlyBudget"`
	}
	c.ShouldBindJSON(&body)

	database.DB.Model(&cat).Update("monthly_budget", body.MonthlyBudget)
	utils.OK(c, gin.H{"success": true, "category": cat})
}

// AppGetFavorites returns the cached favorite categories for the user's membership.
// GET /api/app/expense-categories/favorites?householdId=X
func (h *ExpenseCategoriesHandler) AppGetFavorites(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)
	householdID := c.Query("householdId")

	if householdID == "" {
		utils.BadRequest(c, "householdId is required")
		return
	}

	var member models.HouseholdMember
	if err := database.DB.Where("household_id = ? AND app_user_id = ?", householdID, appUser.ID).
		First(&member).Error; err != nil {
		utils.Forbidden(c, "Not a member of this household")
		return
	}

	utils.OK(c, gin.H{
		"success":                    true,
		"favoriteExpenseCategoryIds": member.FavoriteExpenseCategoryIDs,
		"lastCalculatedAt":           member.FavoritesLastCalculatedAt,
	})
}
