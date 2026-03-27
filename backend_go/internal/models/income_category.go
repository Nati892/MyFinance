package models

import "time"

// IncomeCategory represents an income category scoped to a household.
// Sequelize model: IncomeCategory — table: income_categories
type IncomeCategory struct {
	ID          uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Name        string    `gorm:"type:varchar(255);not null" json:"name"`
	NameHe      *string   `gorm:"type:varchar(255)" json:"nameHe"`
	Icon        *string   `gorm:"type:varchar(100)" json:"icon"`
	Color       *string   `gorm:"type:varchar(50)" json:"color"`
	SortOrder   int       `gorm:"default:0" json:"sortOrder"`
	HouseholdID uint      `gorm:"not null;index" json:"householdId"`
	CreatedAt   time.Time `json:"createdAt"`
	UpdatedAt   time.Time `json:"updatedAt"`

	Household Household `gorm:"foreignKey:HouseholdID" json:"-"`
}

func (IncomeCategory) TableName() string { return "income_categories" }
