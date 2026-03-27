package models

import (
	"time"

	"gorm.io/datatypes"
)

// HouseholdMember is the join table between Household and AppUser, with extra fields.
// Sequelize model: HouseholdMember — table: household_members
//
// This is a "through" table with payload — beyond a simple many-to-many,
// it carries role, favorites, etc. In GORM, you model this as a regular struct
// (not a join table helper) and use it like any other model.
type HouseholdMember struct {
	ID          uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	HouseholdID uint      `gorm:"not null;index" json:"householdId"`
	AppUserID   uint      `gorm:"not null;index" json:"appUserId"`
	// Role is an ENUM in MariaDB — GORM maps it to a varchar with a check.
	// We validate the value in the handler, not at the DB level, for portability.
	Role        string    `gorm:"type:varchar(50);not null;default:'member'" json:"role"`

	// datatypes.JSON stores a JSON array in the DB.
	// e.g. [1, 3, 7] stored as the string "[1,3,7]" in a JSON/TEXT column.
	// nil means no favorites set yet (NULL in DB).
	FavoriteExpenseCategoryIDs datatypes.JSON `gorm:"type:json" json:"favoriteExpenseCategoryIds"`
	FavoritesLastCalculatedAt  *time.Time     `json:"favoritesLastCalculatedAt"`

	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`

	// BelongsTo associations — loaded with Preload("AppUser") or Preload("Household")
	AppUser   AppUser   `gorm:"foreignKey:AppUserID"   json:"AppUser,omitempty"`
	Household Household `gorm:"foreignKey:HouseholdID" json:"Household,omitempty"`
}

func (HouseholdMember) TableName() string { return "household_members" }
