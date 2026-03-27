package handlers

import (
	"household-go/internal/database"
	"household-go/internal/models"
	"household-go/internal/utils"
	"log"

	"github.com/gin-gonic/gin"
)

// BudgetsHandler handles budget queries and overrides.
type BudgetsHandler struct{}

func NewBudgetsHandler() *BudgetsHandler { return &BudgetsHandler{} }

// GetMonthBudget returns all expense categories with spending vs budget for a calendar month.
// GET /api/app/budget/month?householdId=X&year=Y&month=M
func (h *BudgetsHandler) GetMonthBudget(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)

	householdID := c.Query("householdId")
	year := c.Query("year")
	month := c.Query("month")

	if householdID == "" || year == "" || month == "" {
		utils.BadRequest(c, "householdId, year, and month are required")
		return
	}

	if err := verifyMembership(householdID, appUser.ID); err != nil {
		utils.Forbidden(c, "Not a member of this household")
		return
	}

	yearInt := parseInt(year)
	monthInt := parseInt(month)

	// Calendar month boundaries: first day to last day of the month.
	// time.Date handles month overflow — time.Date(2024, 13, 1,...) = 2025-01-01.
	// monthStart = first second of the month
	// monthEnd   = last second of the month (day 0 of next month = last day of this month)

	// We use raw SQL for the SUM aggregation — more efficient than N+1 Go loops.
	// GORM's Raw() lets you write raw SQL while still getting typed scan results.
	type budgetRow struct {
		CategoryID uint    `gorm:"column:id"`
		Spent      float64 `gorm:"column:spent"`
	}

	// First, load all categories for this household
	var categories []models.ExpenseCategory
	if err := database.DB.Where("household_id = ?", householdID).
		Order("sort_order ASC").Find(&categories).Error; err != nil {
		utils.InternalError(c, "Failed to retrieve month budget")
		return
	}

	// Load budget overrides for this month
	var overrides []models.CategoryBudgetOverride
	database.DB.Where("household_id = ? AND year = ? AND month = ?", householdID, yearInt, monthInt).
		Find(&overrides)

	// Build override map: categoryID → override record
	// Maps in Go are reference types initialized with make() or a literal.
	overrideMap := make(map[uint]models.CategoryBudgetOverride)
	for _, o := range overrides {
		overrideMap[o.ExpenseCategoryID] = o
	}

	// Aggregate spending per category in a single query instead of N queries.
	// This is the key optimization vs the original Node code which does one query per category.
	// GORM's Raw() returns a *gorm.DB; Scan() executes it and fills the slice.
	var spendRows []budgetRow
	database.DB.Raw(`
		SELECT expense_category_id AS id, COALESCE(SUM(amount), 0) AS spent
		FROM expenses
		WHERE household_id = ?
		  AND date_time >= DATE(CONCAT(?, '-', ?, '-01'))
		  AND date_time < DATE(CONCAT(?, '-', ?+1, '-01'))
		GROUP BY expense_category_id
	`, householdID, year, month, year, month).Scan(&spendRows)

	spendMap := make(map[uint]float64)
	for _, row := range spendRows {
		spendMap[row.CategoryID] = row.Spent
	}

	// Build the response slice
	type categoryResult struct {
		ID              uint     `json:"id"`
		Name            string   `json:"name"`
		NameHe          *string  `json:"nameHe"`
		Icon            *string  `json:"icon"`
		Color           *string  `json:"color"`
		BaseBudget      *float64 `json:"baseBudget"`
		Override        *float64 `json:"override"`
		EffectiveBudget *float64 `json:"effectiveBudget"`
		Spent           float64  `json:"spent"`
		Result          *float64 `json:"result"`
	}

	result := make([]categoryResult, 0, len(categories))
	for _, cat := range categories {
		spent := spendMap[cat.ID]
		override, hasOverride := overrideMap[cat.ID]

		var overrideAmount *float64
		if hasOverride {
			a := override.Amount
			overrideAmount = &a
		}

		var effectiveBudget *float64
		if overrideAmount != nil {
			effectiveBudget = overrideAmount
		} else {
			effectiveBudget = cat.MonthlyBudget
		}

		var budgetResult *float64
		if effectiveBudget != nil {
			r := spent - *effectiveBudget
			budgetResult = &r
		}

		result = append(result, categoryResult{
			ID:              cat.ID,
			Name:            cat.Name,
			NameHe:          cat.NameHe,
			Icon:            cat.Icon,
			Color:           cat.Color,
			BaseBudget:      cat.MonthlyBudget,
			Override:        overrideAmount,
			EffectiveBudget: effectiveBudget,
			Spent:           spent,
			Result:          budgetResult,
		})
	}

	utils.OK(c, gin.H{"success": true, "categories": result})
}

// SetBaseBudget sets the default monthly budget on an expense category.
// PUT /api/app/budget/base
func (h *BudgetsHandler) SetBaseBudget(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)

	var body struct {
		ExpenseCategoryID uint     `json:"expenseCategoryId" binding:"required"`
		HouseholdID       uint     `json:"householdId"       binding:"required"`
		Amount            *float64 `json:"amount"` // pointer: allows sending 0 or null
	}
	if err := c.ShouldBindJSON(&body); err != nil || body.Amount == nil {
		utils.BadRequest(c, "expenseCategoryId, householdId, and amount are required")
		return
	}

	if err := verifyMembership(formatUint(body.HouseholdID), appUser.ID); err != nil {
		utils.Forbidden(c, "Not a member of this household")
		return
	}

	var category models.ExpenseCategory
	if err := database.DB.Where("id = ? AND household_id = ?", body.ExpenseCategoryID, body.HouseholdID).
		First(&category).Error; err != nil {
		utils.NotFound(c, "Category not found")
		return
	}

	var newBudget *float64
	if *body.Amount >= 0 {
		newBudget = body.Amount
	} // nil if negative — clears the budget

	database.DB.Model(&category).Update("monthly_budget", newBudget)
	utils.OK(c, gin.H{"success": true})
}

// SetOverride upserts a CategoryBudgetOverride for a specific year/month.
// PUT /api/app/budget/override
func (h *BudgetsHandler) SetOverride(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)

	var body struct {
		ExpenseCategoryID uint    `json:"expenseCategoryId" binding:"required"`
		HouseholdID       uint    `json:"householdId"       binding:"required"`
		Year              int     `json:"year"              binding:"required"`
		Month             int     `json:"month"             binding:"required"`
		Amount            float64 `json:"amount"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "expenseCategoryId, householdId, year, month, and amount are required")
		return
	}

	if err := verifyMembership(formatUint(body.HouseholdID), appUser.ID); err != nil {
		utils.Forbidden(c, "Not a member of this household")
		return
	}

	// GORM's Save() does an upsert when the primary key is 0 (new record).
	// But for a composite-key upsert we use FirstOrCreate + Update.
	// Equivalent to Sequelize's upsert({ expenseCategoryId, householdId, year, month, amount }).
	var override models.CategoryBudgetOverride
	result := database.DB.Where(models.CategoryBudgetOverride{
		ExpenseCategoryID: body.ExpenseCategoryID,
		HouseholdID:       body.HouseholdID,
		Year:              body.Year,
		Month:             body.Month,
	}).FirstOrCreate(&override)

	if result.Error != nil {
		log.Printf("SetOverride error: %v", result.Error)
		utils.InternalError(c, "Failed to set budget override")
		return
	}

	database.DB.Model(&override).Update("amount", body.Amount)
	override.Amount = body.Amount

	utils.OK(c, gin.H{"success": true, "override": override})
}

// GetSpendingByWeek groups expenses by ISO week within a calendar month.
// GET /api/app/budget/by-week?householdId=X&year=Y&month=M
func (h *BudgetsHandler) GetSpendingByWeek(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)

	householdID := c.Query("householdId")
	year := c.Query("year")
	month := c.Query("month")
	categoryID := c.Query("expenseCategoryId")

	if householdID == "" || year == "" || month == "" {
		utils.BadRequest(c, "householdId, year, and month are required")
		return
	}

	if err := verifyMembership(householdID, appUser.ID); err != nil {
		utils.Forbidden(c, "Not a member of this household")
		return
	}

	type weekRow struct {
		ISOWeek int     `gorm:"column:iso_week"`
		Total   float64 `gorm:"column:total"`
	}

	query := `
		SELECT WEEK(date_time, 3) AS iso_week, SUM(amount) AS total
		FROM expenses
		WHERE household_id = ?
		  AND date_time >= DATE(CONCAT(?, '-', ?, '-01'))
		  AND date_time < DATE(CONCAT(?, '-', ?+1, '-01'))`

	args := []interface{}{householdID, year, month, year, month}

	if categoryID != "" {
		query += " AND expense_category_id = ?"
		args = append(args, categoryID)
	}

	query += " GROUP BY WEEK(date_time, 3) ORDER BY iso_week ASC"

	var rows []weekRow
	if err := database.DB.Raw(query, args...).Scan(&rows).Error; err != nil {
		utils.InternalError(c, "Failed to retrieve spending by week")
		return
	}

	type weekResult struct {
		WeekLabel string  `json:"weekLabel"`
		Total     float64 `json:"total"`
	}
	weeks := make([]weekResult, len(rows))
	for i, row := range rows {
		weeks[i] = weekResult{
			WeekLabel: "W" + formatInt(i+1),
			Total:     row.Total,
		}
	}

	utils.OK(c, gin.H{"success": true, "weeks": weeks})
}

// GetSpendingByMonth groups expenses by calendar month within a year range.
// GET /api/app/budget/by-month?householdId=X&year=Y&startMonth=S&endMonth=E
func (h *BudgetsHandler) GetSpendingByMonth(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)

	householdID := c.Query("householdId")
	year := c.Query("year")
	startMonth := c.Query("startMonth")
	endMonth := c.Query("endMonth")
	categoryID := c.Query("expenseCategoryId")

	if householdID == "" || year == "" || startMonth == "" || endMonth == "" {
		utils.BadRequest(c, "householdId, year, startMonth, and endMonth are required")
		return
	}

	if err := verifyMembership(householdID, appUser.ID); err != nil {
		utils.Forbidden(c, "Not a member of this household")
		return
	}

	type monthRow struct {
		Yr    int     `gorm:"column:yr"`
		Mo    int     `gorm:"column:mo"`
		Total float64 `gorm:"column:total"`
	}

	query := `
		SELECT YEAR(date_time) AS yr, MONTH(date_time) AS mo, SUM(amount) AS total
		FROM expenses
		WHERE household_id = ?
		  AND date_time >= DATE(CONCAT(?, '-', ?, '-01'))
		  AND date_time < DATE(CONCAT(?, '-', ?+1, '-01'))`

	args := []interface{}{householdID, year, startMonth, year, endMonth}

	if categoryID != "" {
		query += " AND expense_category_id = ?"
		args = append(args, categoryID)
	}

	query += " GROUP BY YEAR(date_time), MONTH(date_time) ORDER BY yr ASC, mo ASC"

	var rows []monthRow
	if err := database.DB.Raw(query, args...).Scan(&rows).Error; err != nil {
		utils.InternalError(c, "Failed to retrieve spending by month")
		return
	}

	monthNames := [12]string{"Jan", "Feb", "Mar", "Apr", "May", "Jun",
		"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}

	type monthResult struct {
		Label string  `json:"label"`
		Total float64 `json:"total"`
	}
	months := make([]monthResult, len(rows))
	for i, row := range rows {
		months[i] = monthResult{
			Label: monthNames[row.Mo-1] + " " + formatInt(row.Yr),
			Total: row.Total,
		}
	}

	utils.OK(c, gin.H{"success": true, "months": months})
}

// verifyMembership checks that appUserID is a member of the given household.
// Returns an error if not a member (or on DB error).
func verifyMembership(householdID string, appUserID uint) error {
	var m models.HouseholdMember
	return database.DB.Where("household_id = ? AND app_user_id = ?", householdID, appUserID).
		First(&m).Error
}

// formatUint converts uint to string without importing strconv in this file.
func formatUint(n uint) string {
	return formatInt(int(n))
}

// formatInt converts int to string (simple, no import needed for this use case).
func formatInt(n int) string {
	if n == 0 {
		return "0"
	}
	buf := [20]byte{}
	pos := len(buf)
	neg := n < 0
	if neg {
		n = -n
	}
	for n > 0 {
		pos--
		buf[pos] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		pos--
		buf[pos] = '-'
	}
	return string(buf[pos:])
}
