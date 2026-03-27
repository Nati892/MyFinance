package utils

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// JSON response helpers — equivalent to setting `ctx.status` and `ctx.body` in Koa.
//
// In Gin, you respond via the *gin.Context (c) parameter passed to every handler.
// `c.JSON(statusCode, payload)` serializes the payload to JSON and sends the response.
//
// These helpers reduce boilerplate and ensure consistent response shapes.

// OK sends a 200 JSON response with arbitrary data.
// Usage: utils.OK(c, gin.H{"user": user, "token": token})
//
// gin.H is just map[string]any — a shorthand for building JSON objects inline.
func OK(c *gin.Context, data gin.H) {
	c.JSON(http.StatusOK, data)
}

// Created sends a 201 JSON response (resource was created).
func Created(c *gin.Context, data gin.H) {
	c.JSON(http.StatusCreated, data)
}

// BadRequest sends a 400 with an error message string.
func BadRequest(c *gin.Context, msg string) {
	c.JSON(http.StatusBadRequest, gin.H{"error": msg})
}

// Unauthorized sends a 401 with an error message.
func Unauthorized(c *gin.Context, msg string) {
	c.JSON(http.StatusUnauthorized, gin.H{"error": msg})
}

// Forbidden sends a 403 with an error message.
func Forbidden(c *gin.Context, msg string) {
	c.JSON(http.StatusForbidden, gin.H{"error": msg})
}

// NotFound sends a 404 with an error message.
func NotFound(c *gin.Context, msg string) {
	c.JSON(http.StatusNotFound, gin.H{"error": msg})
}

// Conflict sends a 409 with an error message (e.g., duplicate username).
func Conflict(c *gin.Context, msg string) {
	c.JSON(http.StatusConflict, gin.H{"error": msg})
}

// InternalError sends a 500. The `err` is logged but NOT exposed in the response
// (never expose internal error details to clients in production).
func InternalError(c *gin.Context, msg string) {
	c.JSON(http.StatusInternalServerError, gin.H{"error": msg})
}
