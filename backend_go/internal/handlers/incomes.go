package handlers

import (
	"household-go/internal/database"
	"household-go/internal/models"
	"household-go/internal/utils"
	"log"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// IncomesHandler handles income CRUD — mirrors ExpensesHandler structure.
type IncomesHandler struct{}

func NewIncomesHandler() *IncomesHandler { return &IncomesHandler{} }

// List returns incomes for a household, scoped to the current financial period.
// GET /api/app/incomes?householdId=X&view=monthly&periodOffset=0
func (h *IncomesHandler) List(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)

	householdID := c.Query("householdId")
	if householdID == "" {
		utils.BadRequest(c, "householdId is required")
		return
	}

	var membership models.HouseholdMember
	if err := database.DB.Where("household_id = ? AND app_user_id = ?", householdID, appUser.ID).
		First(&membership).Error; err != nil {
		utils.Forbidden(c, "You are not a member of this household")
		return
	}

	periodOffset := parseInt(c.DefaultQuery("periodOffset", "0"))
	period := utils.GetFinancialPeriod(periodOffset)

	var incomes []models.Income
	if err := database.DB.
		Where("household_id = ? AND date_time BETWEEN ? AND ?", householdID, period.Start, period.End).
		Preload("IncomeCategory", func(db *gorm.DB) *gorm.DB {
			return db.Select("id, name, name_he, icon, color")
		}).
		Preload("AppUser", func(db *gorm.DB) *gorm.DB {
			return db.Select("id, username")
		}).
		Order("date_time DESC").
		Find(&incomes).Error; err != nil {
		log.Printf("Incomes list error: %v", err)
		utils.InternalError(c, "Failed to fetch incomes")
		return
	}

	total := 0.0
	for _, i := range incomes {
		total += i.Amount
	}

	utils.OK(c, gin.H{
		"success":     true,
		"incomes":     incomes,
		"period":      gin.H{"start": period.Start, "end": period.End, "label": period.Label},
		"totalAmount": total,
	})
}

// Create adds a new income entry.
// POST /api/app/incomes
func (h *IncomesHandler) Create(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)

	var body struct {
		Amount           float64  `json:"amount"           binding:"required"`
		DateTime         string   `json:"dateTime"         binding:"required"`
		Description      *string  `json:"description"`
		Note             *string  `json:"note"`
		PaymentMethod    *string  `json:"paymentMethod"`
		IncomeCategoryID uint     `json:"incomeCategoryId" binding:"required"`
		HouseholdID      uint     `json:"householdId"      binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "amount, dateTime, incomeCategoryId, and householdId are required")
		return
	}

	var membership models.HouseholdMember
	if err := database.DB.Where("household_id = ? AND app_user_id = ?", body.HouseholdID, appUser.ID).
		First(&membership).Error; err != nil {
		utils.Forbidden(c, "You are not a member of this household")
		return
	}

	var category models.IncomeCategory
	if err := database.DB.Where("id = ? AND household_id = ?", body.IncomeCategoryID, body.HouseholdID).
		First(&category).Error; err != nil {
		utils.BadRequest(c, "Invalid incomeCategoryId for this household")
		return
	}

	dt, err := parseDateTime(body.DateTime)
	if err != nil {
		utils.BadRequest(c, "Invalid dateTime format")
		return
	}

	income := models.Income{
		Amount:           body.Amount,
		DateTime:         dt,
		Description:      body.Description,
		Note:             body.Note,
		PaymentMethod:    body.PaymentMethod,
		IncomeCategoryID: body.IncomeCategoryID,
		AppUserID:        appUser.ID,
		HouseholdID:      body.HouseholdID,
	}

	if err := database.DB.Create(&income).Error; err != nil {
		utils.InternalError(c, "Failed to create income")
		return
	}

	database.DB.Preload("IncomeCategory", func(db *gorm.DB) *gorm.DB {
		return db.Select("id, name, name_he, icon, color")
	}).Preload("AppUser", func(db *gorm.DB) *gorm.DB {
		return db.Select("id, username")
	}).First(&income, income.ID)

	utils.Created(c, gin.H{"success": true, "income": income})
}

// Update modifies an income entry.
// PUT /api/app/incomes/:id
func (h *IncomesHandler) Update(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)
	id := c.Param("id")

	var income models.Income
	if err := database.DB.First(&income, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.NotFound(c, "Income not found")
		} else {
			utils.InternalError(c, "Failed to update income")
		}
		return
	}

	if income.AppUserID != appUser.ID {
		utils.Forbidden(c, "You can only update your own incomes")
		return
	}

	var body struct {
		Amount           *float64 `json:"amount"`
		DateTime         *string  `json:"dateTime"`
		Description      *string  `json:"description"`
		Note             *string  `json:"note"`
		PaymentMethod    *string  `json:"paymentMethod"`
		IncomeCategoryID *uint    `json:"incomeCategoryId"`
	}
	c.ShouldBindJSON(&body)

	updates := map[string]interface{}{}
	if body.Amount != nil           { updates["amount"] = *body.Amount }
	if body.DateTime != nil {
		dt, err := parseDateTime(*body.DateTime)
		if err != nil {
			utils.BadRequest(c, "Invalid dateTime format")
			return
		}
		updates["date_time"] = dt
	}
	if body.Description != nil      { updates["description"] = body.Description }
	if body.Note != nil             { updates["note"] = body.Note }
	if body.PaymentMethod != nil    { updates["payment_method"] = body.PaymentMethod }
	if body.IncomeCategoryID != nil {
		var cat models.IncomeCategory
		if err := database.DB.Where("id = ? AND household_id = ?", *body.IncomeCategoryID, income.HouseholdID).
			First(&cat).Error; err != nil {
			utils.BadRequest(c, "Invalid incomeCategoryId for this household")
			return
		}
		updates["income_category_id"] = *body.IncomeCategoryID
	}

	if len(updates) > 0 {
		database.DB.Model(&income).Updates(updates)
	}

	database.DB.Preload("IncomeCategory", func(db *gorm.DB) *gorm.DB {
		return db.Select("id, name, name_he, icon, color")
	}).Preload("AppUser", func(db *gorm.DB) *gorm.DB {
		return db.Select("id, username")
	}).First(&income, income.ID)

	utils.OK(c, gin.H{"success": true, "income": income})
}

// Delete removes an income entry.
// DELETE /api/app/incomes/:id
func (h *IncomesHandler) Delete(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)
	id := c.Param("id")

	var income models.Income
	if err := database.DB.First(&income, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.NotFound(c, "Income not found")
		} else {
			utils.InternalError(c, "Failed to delete income")
		}
		return
	}

	if income.AppUserID != appUser.ID {
		utils.Forbidden(c, "You can only delete your own incomes")
		return
	}

	database.DB.Delete(&income)
	utils.OK(c, gin.H{"success": true})
}
