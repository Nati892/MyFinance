package models

import "time"

// Asset tracks household assets (savings, property, investments, etc.).
// Sequelize model: Asset — table: assets (migration 003)
type Asset struct {
	ID          uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Name        string    `gorm:"type:varchar(255);not null" json:"name"`
	Value       float64   `gorm:"type:decimal(15,2);not null" json:"value"`
	// Liquidity: "high" | "medium" | "low"
	Liquidity   *string   `gorm:"type:varchar(20)" json:"liquidity"`
	Description *string   `gorm:"type:text" json:"description"`
	SortOrder   int       `gorm:"default:0" json:"sortOrder"`
	// Date field (migration 010) — the date of the asset valuation
	Date        *time.Time `gorm:"type:date" json:"date"`
	HouseholdID uint      `gorm:"not null;index" json:"householdId"`
	CreatedAt   time.Time  `json:"createdAt"`
	UpdatedAt   time.Time  `json:"updatedAt"`

	Household Household `gorm:"foreignKey:HouseholdID" json:"-"`
}

func (Asset) TableName() string { return "assets" }
