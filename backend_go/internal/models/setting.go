package models

import "time"

// Setting is a key-value store for server configuration.
// Sequelize model: Setting — table: settings
type Setting struct {
	ID             uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Key            string    `gorm:"type:varchar(255);not null;uniqueIndex" json:"key"`
	Value          *string   `gorm:"type:text" json:"value"`
	Description    *string   `gorm:"type:text" json:"description"`
	// CoreSetting marks settings that shouldn't be deleted via the API
	CoreSetting    bool      `gorm:"default:false" json:"core_setting"`
	// SendWithConfig marks settings that are sent to the frontend in the /config endpoint
	SendWithConfig bool      `gorm:"default:false" json:"sendWithConfig"`
	CreatedAt      time.Time `json:"createdAt"`
	UpdatedAt      time.Time `json:"updatedAt"`
}

func (Setting) TableName() string { return "settings" }
