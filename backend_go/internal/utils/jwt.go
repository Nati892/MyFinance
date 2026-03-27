// Package utils contains shared helper functions.
package utils

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Claims is our custom JWT payload struct.
//
// JWT in Go works differently than jsonwebtoken in Node:
// You define a struct that embeds jwt.RegisteredClaims (the standard fields like
// exp, iat, iss) and add your own fields. The library serializes/deserializes this
// struct to/from the JWT payload JSON.
type Claims struct {
	ID       uint   `json:"id"`
	Username string `json:"username"`
	// Type distinguishes admin tokens ("user") from app tokens ("appUser").
	// This mirrors the `type` field your Node code puts in the JWT payload.
	Type string `json:"type,omitempty"`

	// Embedding RegisteredClaims gives us the standard JWT fields for free.
	// Go embedding: promoted fields/methods appear directly on the outer struct.
	jwt.RegisteredClaims
}

// GenerateToken creates a signed JWT for an admin User.
// The duration string uses Go's time.ParseDuration format: "1h", "24h", "30m", etc.
func GenerateToken(id uint, username, secret, expiresIn string) (string, error) {
	duration, err := time.ParseDuration(expiresIn)
	if err != nil {
		// Default to 1 hour if the duration string is invalid
		duration = time.Hour
	}

	claims := Claims{
		ID:       id,
		Username: username,
		// RegisteredClaims.ExpiresAt uses jwt.NewNumericDate() which wraps time.Time
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(duration)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	// jwt.NewWithClaims creates an unsigned token; .SignedString() signs it.
	// HS256 is HMAC-SHA256 — the same algorithm jsonwebtoken uses by default.
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

// GenerateAppToken creates a signed JWT for an AppUser (includes type: "appUser").
func GenerateAppToken(id uint, username, secret string) (string, error) {
	claims := Claims{
		ID:       id,
		Username: username,
		Type:     "appUser",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

// ParseToken validates and parses a JWT string, returning the Claims payload.
// Returns an error if the token is expired, malformed, or has an invalid signature.
func ParseToken(tokenStr, secret string) (*Claims, error) {
	claims := &Claims{}

	// jwt.ParseWithClaims is the Go equivalent of jsonwebtoken.verify().
	// The keyFunc is called to return the signing key — this pattern allows
	// dynamic key selection (e.g., for RS256 with key IDs in the header).
	token, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (interface{}, error) {
		// Always verify the signing METHOD — prevents algorithm-confusion attacks
		// where an attacker changes alg to "none" and removes the signature.
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return []byte(secret), nil
	})

	if err != nil {
		return nil, err
	}
	if !token.Valid {
		return nil, errors.New("invalid token")
	}

	return claims, nil
}
