package middleware

import (
	"household-go/internal/database"
	"household-go/internal/models"
	"household-go/internal/utils"

	"github.com/gin-gonic/gin"
)

// AuthenticateApp verifies the JWT and attaches the AppUser to the Gin context.
// Equivalent to your middleware/appAuth.js `authenticateApp` function.
//
// Key difference from Authenticate: we check claims.Type == "appUser" to prevent
// admin tokens from being used on app endpoints and vice versa.
func AuthenticateApp(cfg AuthConfig) gin.HandlerFunc {
	return func(c *gin.Context) {
		token := extractBearerToken(c)
		if token == "" {
			utils.Unauthorized(c, "No authorization token provided")
			c.Abort()
			return
		}

		claims, err := utils.ParseToken(token, cfg.JWTSecret)
		if err != nil {
			utils.Unauthorized(c, "Invalid or expired token")
			c.Abort()
			return
		}

		// Token-type guard: ensures app tokens can't access admin routes and vice versa.
		if claims.Type != "appUser" {
			utils.Unauthorized(c, "Invalid token type")
			c.Abort()
			return
		}

		var appUser models.AppUser
		if err := database.DB.First(&appUser, claims.ID).Error; err != nil {
			utils.Unauthorized(c, "User not found")
			c.Abort()
			return
		}

		if !appUser.IsActive {
			utils.Unauthorized(c, "Account is deactivated")
			c.Abort()
			return
		}

		// Store as "appUser" key — different from "authUser" so both can coexist
		// in a request that's been authenticated by both middleware layers (unlikely
		// but consistent with the two-token architecture).
		c.Set("appUser", &appUser)
		c.Next()
	}
}
