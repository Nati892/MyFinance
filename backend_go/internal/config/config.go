// Package config centralizes all configuration in one place.
// In Go, we don't use global objects like Node's `global.cfg` — instead we pass
// a config struct around explicitly. This makes dependencies visible and testable.
package config

import (
	"fmt"
	"os"
	"strconv"
)

// Config holds all runtime configuration for the server.
// Struct fields are exported (uppercase) so other packages can read them.
// This is Go's way of doing "public" — no access modifiers keyword, just case.
type Config struct {
	Env         string
	Port        string
	BaseAddress string
	Database    DatabaseConfig
	JWT         JWTConfig
	Bcrypt      BcryptConfig
}

// DatabaseConfig holds MariaDB connection parameters.
type DatabaseConfig struct {
	Host     string
	Port     string
	Name     string
	User     string
	Password string
}

// JWTConfig holds JSON Web Token settings.
type JWTConfig struct {
	Secret    string
	ExpiresIn string // e.g. "1h", "24h"
}

// BcryptConfig holds bcrypt settings.
type BcryptConfig struct {
	SaltRounds int
}

// DSN (Data Source Name) builds the MySQL/MariaDB connection string.
// GORM's MySQL driver uses the same DSN format as database/sql.
// The `?parseTime=True&loc=Local` tells the driver to scan DATETIME columns
// into Go's time.Time (without it you'd get raw []byte).
func (d DatabaseConfig) DSN() string {
	return fmt.Sprintf(
		"%s:%s@tcp(%s:%s)/%s?parseTime=True&loc=Local&charset=utf8mb4",
		d.User, d.Password, d.Host, d.Port, d.Name,
	)
}

// Load reads configuration from environment variables.
// In Go, `os.Getenv` returns "" if unset; we handle defaults manually.
// This replaces your Node conf/development.js + conf/production.js files.
func Load() *Config {
	saltRounds, _ := strconv.Atoi(getEnv("BCRYPT_SALT_ROUNDS", "10"))

	return &Config{
		Env:         getEnv("ENV", "development"),
		Port:        getEnv("PORT", "1234"),
		BaseAddress: getEnv("BASE_ADDRESS", "0.0.0.0"),
		Database: DatabaseConfig{
			Host:     getEnv("DB_HOST", "localhost"),
			Port:     getEnv("DB_PORT", "3306"),
			Name:     getEnv("DB_NAME", "app_db"),
			User:     getEnv("DB_USER", "user"),
			Password: getEnv("DB_PASSWORD", "12345678"),
		},
		JWT: JWTConfig{
			Secret:    getEnv("JWT_SECRET", "change-me-in-production"),
			ExpiresIn: getEnv("JWT_EXPIRES_IN", "1h"),
		},
		Bcrypt: BcryptConfig{
			SaltRounds: saltRounds,
		},
	}
}

// getEnv is a helper that returns a default value if the env var is not set.
// Go doesn't have nullish coalescing (??) — this pattern is idiomatic.
func getEnv(key, defaultVal string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultVal
}
