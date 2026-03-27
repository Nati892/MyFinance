package models

import "time"

// AppUser represents a mobile/app-facing user (separate from admin User).
// Sequelize model: AppUser — table: app_users
type AppUser struct {
	ID        uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	Username  string     `gorm:"type:varchar(255);not null;uniqueIndex" json:"username"`
	Password  string     `gorm:"type:varchar(255);not null" json:"-"`
	IsActive  bool       `gorm:"default:true" json:"isActive"`
	LastLogin *time.Time `gorm:"index" json:"lastLogin"`
	CreatedAt time.Time  `json:"createdAt"`
	UpdatedAt time.Time  `json:"updatedAt"`

	// HasMany relationships — GORM uses slice fields to load associations.
	// These are NOT database columns; they're populated only when you use Preload().
	// Equivalent to Sequelize's hasMany(...) associations.
	Tokens           []AppUserToken    `gorm:"foreignKey:AppUserID" json:"-"`
	HouseholdMembers []HouseholdMember `gorm:"foreignKey:AppUserID" json:"-"`
	Expenses         []Expense         `gorm:"foreignKey:AppUserID" json:"-"`
	Incomes          []Income          `gorm:"foreignKey:AppUserID" json:"-"`
	Notes            []Note            `gorm:"foreignKey:AppUserID" json:"-"`
}

func (AppUser) TableName() string { return "app_users" }
