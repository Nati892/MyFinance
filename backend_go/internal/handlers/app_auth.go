package handlers

import (
	"crypto/rand"
	"encoding/hex"
	"household-go/internal/config"
	"household-go/internal/database"
	"household-go/internal/models"
	"household-go/internal/utils"
	"log"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// AppAuthHandler handles sign-in, token refresh, sign-out, and profile for AppUsers.
type AppAuthHandler struct {
	cfg *config.Config
}

func NewAppAuthHandler(cfg *config.Config) *AppAuthHandler {
	return &AppAuthHandler{cfg: cfg}
}

// SignIn authenticates an AppUser, returns access + refresh tokens, and household memberships.
// POST /api/app/auth/signin
func (h *AppAuthHandler) SignIn(c *gin.Context) {
	var body struct {
		Username string `json:"username" binding:"required"`
		Password string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Username and password are required")
		return
	}

	var appUser models.AppUser
	if err := database.DB.Where("username = ?", body.Username).First(&appUser).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			utils.Unauthorized(c, "Invalid credentials")
		} else {
			utils.InternalError(c, "Failed to sign in")
		}
		return
	}

	if !appUser.IsActive {
		utils.Unauthorized(c, "Account is deactivated")
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(appUser.Password), []byte(body.Password)); err != nil {
		utils.Unauthorized(c, "Invalid credentials")
		return
	}

	// Update last login timestamp
	database.DB.Model(&appUser).Update("last_login", time.Now())

	// Generate short-lived access token (1 hour)
	accessToken, err := utils.GenerateAppToken(appUser.ID, appUser.Username, h.cfg.JWT.Secret)
	if err != nil {
		utils.InternalError(c, "Failed to sign in")
		return
	}

	// Generate refresh token: 64 random bytes encoded as hex = 128-char string.
	// crypto/rand is cryptographically secure (unlike math/rand which is NOT).
	// This is the Go equivalent of Node's `crypto.randomBytes(64).toString('hex')`.
	rawToken, err := generateSecureToken(64)
	if err != nil {
		utils.InternalError(c, "Failed to sign in")
		return
	}

	// Hash the refresh token before storing — never store raw tokens in the DB.
	// If the DB is leaked, hashed tokens are useless to an attacker.
	hashedToken, err := bcrypt.GenerateFromPassword([]byte(rawToken), h.cfg.Bcrypt.SaltRounds)
	if err != nil {
		utils.InternalError(c, "Failed to sign in")
		return
	}

	expiresAt := time.Now().AddDate(0, 0, 7) // 7 days
	tokenRecord := models.AppUserToken{
		AppUserID: appUser.ID,
		Token:     string(hashedToken),
		ExpiresAt: expiresAt,
	}
	if err := database.DB.Create(&tokenRecord).Error; err != nil {
		utils.InternalError(c, "Failed to sign in")
		return
	}

	// Load household memberships — equivalent to the Sequelize include in appAuth.js
	var memberships []models.HouseholdMember
	database.DB.Where("app_user_id = ?", appUser.ID).
		Preload("Household").
		Find(&memberships)

	// Build the households slice for the response
	type householdSummary struct {
		HouseholdID   uint   `json:"householdId"`
		HouseholdName string `json:"householdName"`
		Role          string `json:"role"`
	}
	households := make([]householdSummary, 0, len(memberships))
	for _, m := range memberships {
		households = append(households, householdSummary{
			HouseholdID:   m.HouseholdID,
			HouseholdName: m.Household.Name,
			Role:          m.Role,
		})
	}

	utils.OK(c, gin.H{
		"success":      true,
		"accessToken":  accessToken,
		"refreshToken": rawToken, // Send the RAW token to client; we stored the hash
		"expiresIn":    3600,
		"user":         appUser,
		"households":   households,
	})
}

// RefreshToken rotates the refresh token: validates old one, issues new access + refresh pair.
// POST /api/app/auth/refresh
func (h *AppAuthHandler) RefreshToken(c *gin.Context) {
	var body struct {
		RefreshToken string `json:"refreshToken" binding:"required"`
		UserID       uint   `json:"userId"       binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Refresh token and userId are required")
		return
	}

	// Load all non-expired tokens for this user, then bcrypt-compare each one.
	// We can't query by the raw token because we only stored the hash.
	// This is O(n) in the number of active sessions — acceptable for household scale.
	var tokens []models.AppUserToken
	database.DB.Where("app_user_id = ? AND expires_at > ?", body.UserID, time.Now()).Find(&tokens)

	if len(tokens) == 0 {
		utils.Unauthorized(c, "Invalid or expired refresh token")
		return
	}

	var matched *models.AppUserToken
	for i := range tokens {
		if err := bcrypt.CompareHashAndPassword([]byte(tokens[i].Token), []byte(body.RefreshToken)); err == nil {
			matched = &tokens[i]
			break
		}
	}

	if matched == nil {
		utils.Unauthorized(c, "Invalid or expired refresh token")
		return
	}

	var appUser models.AppUser
	if err := database.DB.First(&appUser, body.UserID).Error; err != nil || !appUser.IsActive {
		utils.Unauthorized(c, "User not found or deactivated")
		return
	}

	// Rotate: delete the old token record (prevents replay attacks)
	database.DB.Delete(matched)

	// Issue new access token
	accessToken, err := utils.GenerateAppToken(appUser.ID, appUser.Username, h.cfg.JWT.Secret)
	if err != nil {
		utils.InternalError(c, "Failed to refresh token")
		return
	}

	// Issue new refresh token
	rawToken, err := generateSecureToken(64)
	if err != nil {
		utils.InternalError(c, "Failed to refresh token")
		return
	}
	hashedToken, err := bcrypt.GenerateFromPassword([]byte(rawToken), h.cfg.Bcrypt.SaltRounds)
	if err != nil {
		utils.InternalError(c, "Failed to refresh token")
		return
	}

	database.DB.Create(&models.AppUserToken{
		AppUserID: appUser.ID,
		Token:     string(hashedToken),
		ExpiresAt: time.Now().AddDate(0, 0, 7),
	})

	database.DB.Model(&appUser).Update("last_login", time.Now())

	utils.OK(c, gin.H{
		"success":      true,
		"accessToken":  accessToken,
		"refreshToken": rawToken,
		"expiresIn":    3600,
	})
}

// SignOut invalidates the refresh token for the AppUser.
// POST /api/app/auth/signout
func (h *AppAuthHandler) SignOut(c *gin.Context) {
	var body struct {
		RefreshToken string `json:"refreshToken" binding:"required"`
		UserID       uint   `json:"userId"       binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.BadRequest(c, "Refresh token and userId are required")
		return
	}

	var tokens []models.AppUserToken
	database.DB.Where("app_user_id = ?", body.UserID).Find(&tokens)

	for i := range tokens {
		if err := bcrypt.CompareHashAndPassword([]byte(tokens[i].Token), []byte(body.RefreshToken)); err == nil {
			database.DB.Delete(&tokens[i])
			break
		}
	}

	utils.OK(c, gin.H{"success": true})
}

// GetProfile returns the AppUser's profile and their household memberships.
// GET /api/app/auth/profile
func (h *AppAuthHandler) GetProfile(c *gin.Context) {
	appUser := c.MustGet("appUser").(*models.AppUser)

	var memberships []models.HouseholdMember
	database.DB.Where("app_user_id = ?", appUser.ID).Preload("Household").Find(&memberships)

	type householdSummary struct {
		HouseholdID   uint   `json:"householdId"`
		HouseholdName string `json:"householdName"`
		Role          string `json:"role"`
	}
	households := make([]householdSummary, 0, len(memberships))
	for _, m := range memberships {
		households = append(households, householdSummary{
			HouseholdID:   m.HouseholdID,
			HouseholdName: m.Household.Name,
			Role:          m.Role,
		})
	}

	utils.OK(c, gin.H{"success": true, "user": appUser, "households": households})
}

// generateSecureToken creates a cryptographically random hex string of byteLen*2 chars.
// crypto/rand.Read fills the buffer with random bytes from the OS entropy source.
func generateSecureToken(byteLen int) (string, error) {
	buf := make([]byte, byteLen)
	if _, err := rand.Read(buf); err != nil {
		log.Printf("crypto/rand.Read failed: %v", err)
		return "", err
	}
	return hex.EncodeToString(buf), nil
}
