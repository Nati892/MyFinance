package middleware

import (
	"household-go/internal/database"
	"household-go/internal/models"
	"household-go/internal/utils"
	"strings"

	"github.com/gin-gonic/gin"
)

// AuthConfig carries the JWT secret into middleware without a global variable.
// This is Go's answer to `global.cfg.jwt.secret` — we inject the config.
type AuthConfig struct {
	JWTSecret string
}

// Authenticate verifies the JWT and attaches the admin User to the Gin context.
// Equivalent to your middleware/auth.js `authenticate` function.
//
// Context key convention: "authUser" for admin, "appUser" for app users.
// These are retrieved in handlers with: c.MustGet("authUser").(*models.User)
func Authenticate(cfg AuthConfig) gin.HandlerFunc {
	return func(c *gin.Context) {
		token := extractBearerToken(c)
		if token == "" {
			utils.Unauthorized(c, "No authorization token provided")
			// c.Abort() stops the middleware chain — no further handlers run.
			// This is Koa's equivalent of NOT calling `await next()`.
			c.Abort()
			return
		}

		claims, err := utils.ParseToken(token, cfg.JWTSecret)
		if err != nil {
			utils.Unauthorized(c, "Invalid or expired token")
			c.Abort()
			return
		}

		// Load user from DB on every request to ensure they're still active.
		// This is the same pattern as your middleware/auth.js: User.findByPk(decoded.id).
		// Performance note: for high-traffic APIs you could cache this in Redis,
		// but for household-scale traffic, a DB lookup is perfectly fine.
		var user models.User
		if err := database.DB.First(&user, claims.ID).Error; err != nil {
			utils.Unauthorized(c, "User not found")
			c.Abort()
			return
		}

		if !user.IsActive {
			utils.Unauthorized(c, "Account is deactivated")
			c.Abort()
			return
		}

		// c.Set() stores a value in the request-scoped context.
		// c.MustGet() retrieves it — panics if not set (safe when used after this middleware).
		c.Set("authUser", &user)
		c.Next()
	}
}

// OptionalAuth tries to parse the JWT but doesn't abort if missing/invalid.
// Equivalent to your middleware/auth.js `optionalAuth`.
func OptionalAuth(cfg AuthConfig) gin.HandlerFunc {
	return func(c *gin.Context) {
		token := extractBearerToken(c)
		if token != "" {
			if claims, err := utils.ParseToken(token, cfg.JWTSecret); err == nil {
				var user models.User
				if database.DB.First(&user, claims.ID).Error == nil && user.IsActive {
					c.Set("authUser", &user)
				}
			}
		}
		c.Next()
	}
}

// extractBearerToken pulls the token string from the Authorization header.
// Handles both "Bearer <token>" and bare "<token>" formats.
func extractBearerToken(c *gin.Context) string {
	header := c.GetHeader("Authorization")
	if header == "" {
		return ""
	}
	if strings.HasPrefix(header, "Bearer ") {
		return strings.TrimPrefix(header, "Bearer ")
	}
	return header
}
