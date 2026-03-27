package models

import "time"

// CategoryBudgetOverride overrides the base monthly budget for a specific month.
// Sequelize model: CategoryBudgetOverride — table: category_budget_overrides (migration 004)
//
// The logic is: effectiveBudget = override.amount ?? category.monthlyBudget
// This lets you set a one-off budget for a specific month without changing the default.
type CategoryBudgetOverride struct {
	ID                uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	ExpenseCategoryID uint      `gorm:"not null;index" json:"expenseCategoryId"`
	HouseholdID       uint      `gorm:"not null;index" json:"householdId"`
	Year              int       `gorm:"not null" json:"year"`
	Month             int       `gorm:"not null" json:"month"` // 1–12
	Amount            float64   `gorm:"type:decimal(15,2);not null" json:"amount"`
	CreatedAt         time.Time `json:"createdAt"`
	UpdatedAt         time.Time `json:"updatedAt"`

	// Unique constraint: one override per category per month per household.
	// GORM's uniqueIndex syntax: `gorm:"uniqueIndex:idx_override_unique"`
	// You'd apply this on the category+household+year+month combo via a raw migration.
	ExpenseCategory ExpenseCategory `gorm:"foreignKey:ExpenseCategoryID" json:"-"`
	Household       Household       `gorm:"foreignKey:HouseholdID"       json:"-"`
}

func (CategoryBudgetOverride) TableName() string { return "category_budget_overrides" }
