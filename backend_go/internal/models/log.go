package models

import "time"

// Log is the audit log table — every significant action is recorded here.
// Sequelize model: Log — table: logs
//
// In Go, "log" is also a standard library package name.
// Naming this struct "Log" is fine because the package qualifier resolves ambiguity:
// `models.Log` (our struct) vs `log.Println` (stdlib function).
type Log struct {
	ID         uint    `gorm:"primaryKey;autoIncrement" json:"id"`
	// Level: "debug" | "info" | "warn" | "err"
	Level      string  `gorm:"type:varchar(20);not null;index" json:"level"`
	Action     string  `gorm:"type:varchar(255);not null" json:"action"`
	Source     *string `gorm:"type:varchar(255)" json:"source"`
	// Data is free-form JSON — stored as TEXT in the DB
	Data       *string `gorm:"type:text" json:"data"`
	Path       *string `gorm:"type:varchar(500)" json:"path"`
	Method     *string `gorm:"type:varchar(20)" json:"method"`
	StatusCode *int    `gorm:"type:int" json:"statusCode"`
	// UserID may be null for unauthenticated requests
	UserID     *uint   `gorm:"index" json:"userId"`
	IPAddress  *string `gorm:"type:varchar(100)" json:"ipAddress"`
	ErrorStack *string `gorm:"type:text" json:"errorStack"`
	CreatedAt  time.Time `json:"createdAt"`
	UpdatedAt  time.Time `json:"updatedAt"`
}

func (Log) TableName() string { return "logs" }
