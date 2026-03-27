package models

import "time"

// Household is the top-level multi-tenant entity.
// Sequelize model: Household — table: households
type Household struct {
	ID          uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	Name        string     `gorm:"type:varchar(255);not null" json:"name"`
	// *string means nullable VARCHAR — pointer semantics: nil = NULL in DB.
	// In Go, the zero value of string is "" (empty string), which is NOT the same
	// as NULL. Use *string when you need to distinguish between "no value" and "".
	Description *string    `gorm:"type:text" json:"description"`
	CreatedAt   time.Time  `json:"createdAt"`
	UpdatedAt   time.Time  `json:"updatedAt"`

	// HasMany associations (not DB columns — populated by GORM Preload)
	Members          []HouseholdMember        `gorm:"foreignKey:HouseholdID" json:"HouseholdMembers,omitempty"`
	ExpenseCategories []ExpenseCategory        `gorm:"foreignKey:HouseholdID" json:"ExpenseCategories,omitempty"`
	IncomeCategories  []IncomeCategory         `gorm:"foreignKey:HouseholdID" json:"IncomeCategories,omitempty"`
	Expenses          []Expense                `gorm:"foreignKey:HouseholdID" json:"-"`
	Incomes           []Income                 `gorm:"foreignKey:HouseholdID" json:"-"`
	Notes             []Note                   `gorm:"foreignKey:HouseholdID" json:"-"`
	Assets            []Asset                  `gorm:"foreignKey:HouseholdID" json:"-"`
	BudgetOverrides   []CategoryBudgetOverride `gorm:"foreignKey:HouseholdID" json:"-"`
}

func (Household) TableName() string { return "households" }
