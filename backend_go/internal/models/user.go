// Package models defines every database table as a Go struct with GORM tags.
// This replaces your Sequelize model files in /models/*.js.
//
// KEY CONCEPT — Structs vs Classes:
// Go has no classes. A struct is a value type that groups fields together.
// Methods can be attached to a struct (like class methods), but there's no
// inheritance — you compose behavior by embedding structs.
package models

import "time"

// User represents an admin/back-office user (your Node "User" Sequelize model).
//
// GORM TAG SYNTAX: `gorm:"tag1;tag2"` — semicolon-separated options.
// JSON TAG SYNTAX: `json:"fieldName"` — controls marshaling to/from JSON.
//
// Two tags on one field look like:
//   `gorm:"not null" json:"username"`
//
// The `json:"-"` tag means "never include this field in JSON output" —
// critical for the password hash (you never want to send it to clients).
type User struct {
	// GORM automatically handles ID as primary key when the field is named "ID".
	// `autoIncrement` mirrors Sequelize's `autoIncrement: true`.
	ID        uint      `gorm:"primaryKey;autoIncrement"    json:"id"`
	Username  string    `gorm:"type:varchar(255);not null;uniqueIndex" json:"username"`
	Email     string    `gorm:"type:varchar(255);not null;uniqueIndex" json:"email"`
	// json:"-" ensures the password hash is NEVER sent in API responses.
	Password  string    `gorm:"type:varchar(255);not null"  json:"-"`
	// *bool (pointer to bool) allows NULL in the DB — equivalent to Sequelize's
	// `defaultValue: true` with `allowNull: false` being a pointer here to keep
	// the zero value meaningful. We use a regular bool with default in DB.
	IsActive  bool      `gorm:"default:true"                json:"isActive"`
	// *time.Time — pointer means this column is nullable (can be NULL in DB).
	// A plain time.Time would be stored as the zero value "0001-01-01" instead of NULL.
	LastLogin *time.Time `gorm:"index"                      json:"lastLogin"`
	CreatedAt time.Time  `                                  json:"createdAt"`
	UpdatedAt time.Time  `                                  json:"updatedAt"`
}

// TableName tells GORM what table name to use.
// By default GORM pluralizes the struct name: User → "users". We're explicit here
// so the mapping is obvious when reading the code. Same as Sequelize's `tableName` option.
func (User) TableName() string { return "users" }
