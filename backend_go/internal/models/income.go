package models

import "time"

// Income represents a single income transaction.
// Sequelize model: Income — table: incomes
type Income struct {
	ID          uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Amount      float64   `gorm:"type:decimal(15,2);not null" json:"amount"`
	DateTime    time.Time `gorm:"not null;index" json:"dateTime"`
	Description *string   `gorm:"type:varchar(500)" json:"description"`
	Note        *string   `gorm:"type:text" json:"note"`
	PaymentMethod *string `gorm:"type:varchar(50)" json:"paymentMethod"`

	IncomeCategoryID uint `gorm:"not null;index" json:"incomeCategoryId"`
	AppUserID        uint `gorm:"not null;index" json:"appUserId"`
	HouseholdID      uint `gorm:"not null;index" json:"householdId"`

	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`

	// BelongsTo associations
	IncomeCategory IncomeCategory `gorm:"foreignKey:IncomeCategoryID" json:"IncomeCategory,omitempty"`
	AppUser        AppUser        `gorm:"foreignKey:AppUserID"        json:"AppUser,omitempty"`
	Household      Household      `gorm:"foreignKey:HouseholdID"      json:"-"`
}

func (Income) TableName() string { return "incomes" }
