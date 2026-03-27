package models

import "time"

// AppUserToken stores hashed refresh tokens for AppUsers.
// Sequelize model: AppUserToken — table: app_user_tokens
//
// The refresh token flow:
//   1. Login → generate random 64-byte hex token, bcrypt-hash it, store hash
//   2. Refresh → compare provided token against stored hash (bcrypt.Compare)
//   3. Rotate  → delete old token record, create new one (prevents replay attacks)
type AppUserToken struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	// The stored value is a bcrypt HASH of the actual refresh token.
	// The client holds the raw token; we never store raw tokens in the DB.
	Token     string    `gorm:"type:varchar(255);not null" json:"-"`
	ExpiresAt time.Time `gorm:"not null;index" json:"expiresAt"`
	// AppUserID is the foreign key column in the DB.
	// GORM convention: field named "AppUserID" → column "app_user_id" → FK to app_users.id
	AppUserID uint      `gorm:"not null;index" json:"appUserId"`
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`

	// BelongsTo — loaded via Preload("AppUser") if needed
	AppUser AppUser `gorm:"foreignKey:AppUserID" json:"-"`
}

func (AppUserToken) TableName() string { return "app_user_tokens" }
