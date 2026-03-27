package models

import "time"

// ExpenseCategory represents a spending category scoped to a household.
// Sequelize model: ExpenseCategory — table: expense_categories
type ExpenseCategory struct {
	ID          uint     `gorm:"primaryKey;autoIncrement" json:"id"`
	Name        string   `gorm:"type:varchar(255);not null" json:"name"`
	// *string for nullable fields — Hebrew name is optional
	NameHe      *string  `gorm:"type:varchar(255)" json:"nameHe"`
	Icon        *string  `gorm:"type:varchar(100)" json:"icon"`
	Color       *string  `gorm:"type:varchar(50)" json:"color"`
	SortOrder   int      `gorm:"default:0" json:"sortOrder"`
	// *float64 for nullable DECIMAL — nil means "no budget set"
	// This is the base monthly budget; overrides live in CategoryBudgetOverride.
	MonthlyBudget *float64 `gorm:"type:decimal(15,2)" json:"monthlyBudget"`
	HouseholdID   uint     `gorm:"not null;index" json:"householdId"`
	CreatedAt     time.Time `json:"createdAt"`
	UpdatedAt     time.Time `json:"updatedAt"`

	// BelongsTo
	Household Household `gorm:"foreignKey:HouseholdID" json:"-"`
}

func (ExpenseCategory) TableName() string { return "expense_categories" }
