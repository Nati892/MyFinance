// Package middleware contains Gin middleware functions.
//
// In Gin, middleware is a function of type gin.HandlerFunc:
//   func(c *gin.Context)
//
// Middleware is registered with router.Use() and runs before (or after) handlers.
// Call c.Next() to pass control to the next handler in the chain, then optionally
// do post-processing after Next() returns. This is Gin's equivalent of Koa's
// `await next()` pattern.
package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// CORS returns a Gin middleware that sets permissive CORS headers.
// Mirrors your index.js CORS middleware exactly.
func CORS() gin.HandlerFunc {
	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")
		if origin == "" {
			origin = "*"
		}

		c.Header("Access-Control-Allow-Origin", origin)
		c.Header("Access-Control-Allow-Credentials", "true")
		c.Header("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,PATCH,OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type,Authorization,Accept,X-Requested-With,Origin")
		c.Header("Access-Control-Expose-Headers", "Content-Length,Date,X-Request-Id")
		c.Header("Access-Control-Max-Age", "86400")

		// Handle preflight requests — browsers send OPTIONS before cross-origin POSTs
		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent) // 204
			return
		}

		// c.Next() passes control to the next handler/middleware in the chain.
		// Anything AFTER c.Next() runs on the way back out (like Koa's post-await logic).
		c.Next()
	}
}
