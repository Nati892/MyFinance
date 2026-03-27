// Package database manages the GORM database connection and auto-migration.
// This replaces your models/index.js (Sequelize setup) and runMigrations.js.
package database

import (
	"household-go/internal/config"
	"household-go/internal/models"
	"log"
	"os"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// DB is the package-level GORM database instance, shared across the process.
// In Go, package-level variables are initialized once — equivalent to Node's
// module-level `const db = new Sequelize(...)` that gets required everywhere.
var DB *gorm.DB

// Connect opens the database connection and stores it in DB.
// GORM manages a connection pool internally — you never open/close connections
// per-request (the pool handles that, just like Sequelize's pool config).
func Connect(cfg *config.Config) error {
	logLevel := logger.Silent
	if cfg.Env == "development" {
		// In dev, GORM prints every SQL query — like Sequelize's `logging: console.log`
		logLevel = logger.Info
	}

	gormCfg := &gorm.Config{
		Logger: logger.Default.LogMode(logLevel),
		// Prevents GORM from auto-creating FK constraints in AutoMigrate.
		// We handle referential integrity at the application level for flexibility.
		DisableForeignKeyConstraintWhenMigrating: true,
	}

	db, err := gorm.Open(mysql.Open(cfg.Database.DSN()), gormCfg)
	if err != nil {
		// In Go, errors are values returned by functions — no try/catch.
		// The caller decides what to do (log.Fatal, retry, etc.)
		return err
	}

	// Access the underlying *sql.DB to tune the connection pool.
	// GORM wraps database/sql — you can always drop down to the raw driver.
	sqlDB, err := db.DB()
	if err != nil {
		return err
	}
	sqlDB.SetMaxOpenConns(10) // Max concurrent connections to MariaDB
	sqlDB.SetMaxIdleConns(5)  // Connections kept open when idle

	DB = db
	log.Println("Database connection established.")
	return nil
}

// AutoMigrate runs GORM schema migration for all registered models.
// SAFE to run every startup: it only ADDs tables/columns, never drops.
// Equivalent to `sequelize.sync({ force: false })` — the non-destructive sync.
//
// ⚠️ AutoMigrate does NOT rename columns or add DB-level constraints.
// For those you'd write raw SQL (similar to your /migrations/*.js files).
func AutoMigrate() error {
	log.Println("Running database auto-migration...")

	err := DB.AutoMigrate(
		&models.User{},
		&models.AppUser{},
		&models.AppUserToken{},
		&models.Household{},
		&models.HouseholdMember{},
		&models.ExpenseCategory{},
		&models.IncomeCategory{},
		&models.Expense{},
		&models.Income{},
		&models.Note{},
		&models.Asset{},
		&models.CategoryBudgetOverride{},
		&models.Log{},
		&models.Setting{},
	)
	if err != nil {
		return err
	}

	log.Println("Database migration complete.")
	return nil
}

// SeedAdmin creates the default admin user if none exists.
// Equivalent to your utils/seed.js seedAdmin() function.
// The password must already be bcrypt-hashed before passing in.
func SeedAdmin(hashedPassword string) error {
	adminUsername := envOrDefault("ADMIN_USERNAME", "admin")
	adminEmail := envOrDefault("ADMIN_EMAIL", "admin@admin.com")

	var existing models.User
	// GORM First() + error check — equivalent to Sequelize's findOne({ where: ... })
	result := DB.Where("username = ?", adminUsername).First(&existing)

	// gorm.ErrRecordNotFound is the sentinel value for "no rows found".
	// Always check for this specific error; other errors indicate a real DB problem.
	if result.Error == nil {
		log.Printf("Admin user %q already exists, skipping seed.\n", adminUsername)
		return nil
	}
	if result.Error != gorm.ErrRecordNotFound {
		return result.Error
	}

	admin := models.User{
		Username: adminUsername,
		Email:    adminEmail,
		Password: hashedPassword,
		IsActive: true,
	}

	if err := DB.Create(&admin).Error; err != nil {
		return err
	}

	log.Printf("Admin user %q created (email: %s).\n", adminUsername, adminEmail)
	return nil
}

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
