package models

import "time"

// Note is a rich sticky-note (text, heart, or image type) scoped to a household.
// Sequelize model: Note — table: notes
//
// This model has many optional fields — hence lots of pointer types (*string, *float64, *bool).
// In Go, `*T` (pointer to T) is nullable. The nil value serializes to `null` in JSON.
type Note struct {
	ID          uint    `gorm:"primaryKey;autoIncrement" json:"id"`
	// MEDIUMTEXT column (migration 008) — up to 16MB of content (e.g., base64 images)
	Content     *string `gorm:"type:mediumtext" json:"content"`
	PosX        float64 `gorm:"type:decimal(10,2);default:0" json:"posX"`
	PosY        float64 `gorm:"type:decimal(10,2);default:0" json:"posY"`
	ZIndex      int     `gorm:"default:0" json:"zIndex"`
	Width       float64 `gorm:"type:decimal(10,2);default:200" json:"width"`
	Height      float64 `gorm:"type:decimal(10,2);default:200" json:"height"`
	// Rotation in degrees (migration 009)
	Rotation    float64 `gorm:"type:decimal(10,2);default:0" json:"rotation"`

	// Styling (migration 002)
	NoteColor     *string `gorm:"type:varchar(50)" json:"noteColor"`
	TextDirection *string `gorm:"type:varchar(10)" json:"textDirection"` // "ltr" | "rtl"
	TextSize      *string `gorm:"type:varchar(20)" json:"textSize"`
	IsBold        bool    `gorm:"default:false" json:"isBold"`
	IsUnderline   bool    `gorm:"default:false" json:"isUnderline"`
	TextColor     *string `gorm:"type:varchar(50)" json:"textColor"`
	// Header color (migration 005)
	HeaderColor   *string `gorm:"type:varchar(50)" json:"headerColor"`

	// Sticker type (migration 006): "text" | "heart" | "image"
	Type        string  `gorm:"type:varchar(20);default:'text'" json:"type"`
	HeartColor  *string `gorm:"type:varchar(50)" json:"heartColor"`

	HouseholdID uint `gorm:"not null;index" json:"householdId"`
	AppUserID   uint `gorm:"not null;index" json:"appUserId"`

	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`

	AppUser   AppUser   `gorm:"foreignKey:AppUserID"   json:"-"`
	Household Household `gorm:"foreignKey:HouseholdID" json:"-"`
}

func (Note) TableName() string { return "notes" }
