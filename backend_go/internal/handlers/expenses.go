package handlers

import (
	"household-go/internal/database"
	"household-go/internal/models"
	"household-go/internal/utils"
	"log"
	"math"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// ExpensesHandler handles all expense CRUD and listing.
type ExpensesHandler struct{}

func NewExpensesHandler() *ExpensesHandler { return &ExpensesHandler{} }

// List returns expenses for a household scoped by the financial calendar.
// GET /api/app/expenses?householdId=X&view=monthly&periodOffset=0
func (h *ExpensesHandler) List(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)

	householdID := c.Query("householdId")
	if householdID == "" {
		utils.BadRequest(c, "householdId is required")
		return
	}

	// Verify membership — identical to the Sequelize HouseholdMember.findOne check
	var membership models.HouseholdMember
	if err := database.DB.Where("household_id = ? AND app_user_id = ?", householdID, appUser.ID).
		First(&membership).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.Forbidden(c, "You are not a member of this household")
		} else {
			utils.InternalError(c, "Failed to fetch expenses")
		}
		return
	}

	view := c.DefaultQuery("view", "monthly")
	periodOffset := parseInt(c.DefaultQuery("periodOffset", "0"))
	dateStr := c.Query("date")
	categoryID := c.Query("categoryId")

	period := utils.GetFinancialPeriod(periodOffset)
	weeks := utils.GetFinancialWeeks(period)

	dateStart := period.Start
	dateEnd := period.End
	var slots interface{} // will hold []HourlySlot or nil

	switch view {
	case "daily":
		if dateStr == "" {
			utils.BadRequest(c, "date is required for daily view")
			return
		}
		t, err := time.Parse(time.RFC3339, dateStr)
		if err != nil {
			// Try date-only format as fallback
			t, err = time.Parse("2006-01-02", dateStr)
			if err != nil {
				utils.BadRequest(c, "date is not a valid ISO date string")
				return
			}
		}
		dateStart = time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.Local)
		dateEnd = time.Date(t.Year(), t.Month(), t.Day(), 23, 59, 59, 0, time.Local)

	case "hourly":
		if dateStr == "" {
			utils.BadRequest(c, "date is required for hourly view")
			return
		}
		t, err := time.Parse(time.RFC3339, dateStr)
		if err != nil {
			t, err = time.Parse("2006-01-02", dateStr)
			if err != nil {
				utils.BadRequest(c, "date is not a valid ISO date string")
				return
			}
		}
		dateStart = time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.Local)
		dateEnd = time.Date(t.Year(), t.Month(), t.Day(), 23, 59, 59, 0, time.Local)
		slots = utils.GetHourlySlots(t)
	}

	// Build the GORM query.
	// Preload() is GORM's equivalent of Sequelize's `include: [{ model: ExpenseCategory }]`.
	// It runs a separate SELECT and joins the results in Go (not a SQL JOIN).
	// For a household-scale app this is fine; for high-traffic use .Joins() instead.
	query := database.DB.
		Where("household_id = ?", householdID).
		Where("date_time BETWEEN ? AND ?", dateStart, dateEnd).
		Preload("ExpenseCategory", func(db *gorm.DB) *gorm.DB {
			return db.Select("id, name, name_he, icon, color")
		}).
		Preload("AppUser", func(db *gorm.DB) *gorm.DB {
			return db.Select("id, username")
		}).
		Order("date_time DESC")

	if categoryID != "" {
		query = query.Where("expense_category_id = ?", categoryID)
	}

	var expenses []models.Expense
	if err := query.Find(&expenses).Error; err != nil {
		log.Printf("Expenses list error: %v", err)
		utils.InternalError(c, "Failed to fetch expenses")
		return
	}

	// Compute total — Go's range loop iterates slices with index, value
	total := 0.0
	for _, e := range expenses {
		total += e.Amount
	}
	// Round to 2 decimal places (avoid floating-point drift)
	total = math.Round(total*100) / 100

	resp := gin.H{
		"success":     true,
		"expenses":    expenses,
		"period":      gin.H{"start": period.Start, "end": period.End, "label": period.Label},
		"totalAmount": total,
	}

	if view == "monthly" || view == "weekly" {
		resp["weeks"] = weeks
	}
	if slots != nil {
		resp["slots"] = slots
	}

	utils.OK(c, resp)
}

// Create adds a new expense.
// POST /api/app/expenses
func (h *ExpensesHandler) Create(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)

	var body struct {
		Amount            float64  `json:"amount"            binding:"required"`
		DateTime          string   `json:"dateTime"          binding:"required"`
		Description       *string  `json:"description"`
		Note              *string  `json:"note"`
		PaymentMethod     *string  `json:"paymentMethod"`
		ExpenseCategoryID uint     `json:"expenseCategoryId" binding:"required"`
		HouseholdID       uint     `json:"householdId"       binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "amount, dateTime, expenseCategoryId, and householdId are required")
		return
	}

	// Membership check
	var membership models.HouseholdMember
	if err := database.DB.Where("household_id = ? AND app_user_id = ?", body.HouseholdID, appUser.ID).
		First(&membership).Error; err != nil {
		utils.Forbidden(c, "You are not a member of this household")
		return
	}

	// Validate category belongs to this household
	var category models.ExpenseCategory
	if err := database.DB.Where("id = ? AND household_id = ?", body.ExpenseCategoryID, body.HouseholdID).
		First(&category).Error; err != nil {
		utils.BadRequest(c, "Invalid expenseCategoryId for this household")
		return
	}

	// Parse dateTime — try RFC3339 first, then date-only
	dt, err := parseDateTime(body.DateTime)
	if err != nil {
		utils.BadRequest(c, "Invalid dateTime format")
		return
	}

	expense := models.Expense{
		Amount:            body.Amount,
		DateTime:          dt,
		Description:       body.Description,
		Note:              body.Note,
		PaymentMethod:     body.PaymentMethod,
		ExpenseCategoryID: body.ExpenseCategoryID,
		AppUserID:         appUser.ID,
		HouseholdID:       body.HouseholdID,
	}

	if err := database.DB.Create(&expense).Error; err != nil {
		log.Printf("Expenses create error: %v", err)
		utils.InternalError(c, "Failed to create expense")
		return
	}

	// Reload with associations — equivalent to Sequelize's findByPk with include
	database.DB.Preload("ExpenseCategory", func(db *gorm.DB) *gorm.DB {
		return db.Select("id, name, name_he, icon, color")
	}).Preload("AppUser", func(db *gorm.DB) *gorm.DB {
		return db.Select("id, username")
	}).First(&expense, expense.ID)

	utils.Created(c, gin.H{"success": true, "expense": expense})
}

// Update modifies an existing expense (only the creator can update).
// PUT /api/app/expenses/:id
func (h *ExpensesHandler) Update(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)
	id := c.Param("id")

	var expense models.Expense
	if err := database.DB.First(&expense, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.NotFound(c, "Expense not found")
		} else {
			utils.InternalError(c, "Failed to update expense")
		}
		return
	}

	if expense.AppUserID != appUser.ID {
		utils.Forbidden(c, "You can only update your own expenses")
		return
	}

	// Use a map so we can do partial updates without overwriting fields with zero values.
	// In Go, a struct update with Updates() skips zero-value fields — problematic if
	// a user legitimately wants to set amount to 0. A map avoids this.
	var body struct {
		Amount            *float64 `json:"amount"`
		DateTime          *string  `json:"dateTime"`
		Description       *string  `json:"description"`
		Note              *string  `json:"note"`
		PaymentMethod     *string  `json:"paymentMethod"`
		ExpenseCategoryID *uint    `json:"expenseCategoryId"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Invalid request body")
		return
	}

	updates := map[string]interface{}{}
	if body.Amount != nil {
		updates["amount"] = *body.Amount
	}
	if body.DateTime != nil {
		dt, err := parseDateTime(*body.DateTime)
		if err != nil {
			utils.BadRequest(c, "Invalid dateTime format")
			return
		}
		updates["date_time"] = dt
	}
	if body.Description != nil {
		updates["description"] = body.Description
	}
	if body.Note != nil {
		updates["note"] = body.Note
	}
	if body.PaymentMethod != nil {
		updates["payment_method"] = body.PaymentMethod
	}
	if body.ExpenseCategoryID != nil {
		// Validate the new category belongs to the same household
		var cat models.ExpenseCategory
		if err := database.DB.Where("id = ? AND household_id = ?", *body.ExpenseCategoryID, expense.HouseholdID).
			First(&cat).Error; err != nil {
			utils.BadRequest(c, "Invalid expenseCategoryId for this household")
			return
		}
		updates["expense_category_id"] = *body.ExpenseCategoryID
	}

	if len(updates) > 0 {
		database.DB.Model(&expense).Updates(updates)
	}

	database.DB.Preload("ExpenseCategory", func(db *gorm.DB) *gorm.DB {
		return db.Select("id, name, name_he, icon, color")
	}).Preload("AppUser", func(db *gorm.DB) *gorm.DB {
		return db.Select("id, username")
	}).First(&expense, expense.ID)

	utils.OK(c, gin.H{"success": true, "expense": expense})
}

// Delete removes an expense (only creator can delete).
// DELETE /api/app/expenses/:id
func (h *ExpensesHandler) Delete(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)
	id := c.Param("id")

	var expense models.Expense
	if err := database.DB.First(&expense, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.NotFound(c, "Expense not found")
		} else {
			utils.InternalError(c, "Failed to delete expense")
		}
		return
	}

	if expense.AppUserID != appUser.ID {
		utils.Forbidden(c, "You can only delete your own expenses")
		return
	}

	database.DB.Delete(&expense)
	utils.OK(c, gin.H{"success": true})
}

// parseInt is a helper to parse a string to int, returning 0 on failure.
// Go has no parseInt() builtin — you use strconv.Atoi() which returns (int, error).
// The underscore _ discards the error (intentional fallback to 0).
func parseInt(s string) int {
	n := 0
	for _, ch := range s {
		if ch < '0' || ch > '9' {
			if ch == '-' && n == 0 {
				n = -1
				continue
			}
			break
		}
		n = n*10 + int(ch-'0')
	}
	return n
}

// parseDateTime tries RFC3339 ("2024-03-15T10:00:00Z") then date-only ("2024-03-15").
func parseDateTime(s string) (time.Time, error) {
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		return t, nil
	}
	return time.Parse("2006-01-02", s)
}
