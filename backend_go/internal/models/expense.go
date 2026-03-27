package models

import "time"

// Expense represents a single spending transaction.
// Sequelize model: Expense — table: expenses
//
// DECIMAL vs FLOAT in Go:
// Go has no built-in decimal type. For financial data, GORM maps DECIMAL(15,2)
// to float64 in Go. This is acceptable for display/filtering, but if you ever
// need exact arithmetic (e.g., currency reconciliation), use the `shopspring/decimal`
// package. For this app's aggregation/display use case, float64 is fine.
type Expense struct {
	ID          uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Amount      float64   `gorm:"type:decimal(15,2);not null" json:"amount"`
	DateTime    time.Time `gorm:"not null;index" json:"dateTime"`
	Description *string   `gorm:"type:varchar(500)" json:"description"`
	Note        *string   `gorm:"type:text" json:"note"`
	// PaymentMethod: "credit_card" | "debit_card" | "cash" | "bank_transfer"
	PaymentMethod *string `gorm:"type:varchar(50)" json:"paymentMethod"`

	ExpenseCategoryID uint `gorm:"not null;index" json:"expenseCategoryId"`
	AppUserID         uint `gorm:"not null;index" json:"appUserId"`
	HouseholdID       uint `gorm:"not null;index" json:"householdId"`

	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`

	// BelongsTo associations — populated via Preload() in handlers
	ExpenseCategory ExpenseCategory `gorm:"foreignKey:ExpenseCategoryID" json:"ExpenseCategory,omitempty"`
	AppUser         AppUser         `gorm:"foreignKey:AppUserID"         json:"AppUser,omitempty"`
	Household       Household       `gorm:"foreignKey:HouseholdID"       json:"-"`
}

func (Expense) TableName() string { return "expenses" }
