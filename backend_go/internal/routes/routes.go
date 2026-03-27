// Package routes wires all handlers to their URL paths.
// This replaces your router.js + individual routers/*.js files.
//
// Gin routing concepts:
//   router.GET("/path", handler)    — equivalent to koaRouter.get()
//   router.Group("/prefix")        — creates a sub-router with a URL prefix
//   group.Use(middleware)          — applies middleware to all routes in the group
//
// Gin evaluates routes in registration order. More specific routes should be
// registered BEFORE wildcard/parameter routes to avoid ambiguity.
// e.g. register "/reorder" before "/:id" — both match the same prefix segment.
package routes

import (
	"household-go/internal/config"
	"household-go/internal/handlers"
	"household-go/internal/middleware"

	"github.com/gin-gonic/gin"
)

// Setup registers all application routes on the given router.
// Takes the config to pass JWTSecret into middleware.
func Setup(r *gin.Engine, cfg *config.Config) {
	authCfg := middleware.AuthConfig{JWTSecret: cfg.JWT.Secret}

	// Instantiate all handlers — dependency injection in Go:
	// handlers receive their dependencies (config, DB — via package var) at construction.
	authH       := handlers.NewAuthHandler(cfg)
	appAuthH    := handlers.NewAppAuthHandler(cfg)
	appUsersH   := handlers.NewAppUsersHandler(cfg)
	expensesH   := handlers.NewExpensesHandler()
	incomesH    := handlers.NewIncomesHandler()
	expCatH     := handlers.NewExpenseCategoriesHandler()
	incCatH     := handlers.NewIncomeCategoriesHandler()
	householdsH := handlers.NewHouseholdsHandler()
	notesH      := handlers.NewNotesHandler()
	assetsH     := handlers.NewAssetsHandler()
	budgetsH    := handlers.NewBudgetsHandler()
	logsH       := handlers.NewLogsHandler()
	settingsH   := handlers.NewSettingsHandler()

	// Health check — unauthenticated
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	// ─── API group — all routes prefixed with /api ─────────────────────────────
	api := r.Group("/api")

	// ── Admin Auth (no middleware — public routes) ──────────────────────────────
	auth := api.Group("/auth")
	{
		auth.POST("/signup", authH.SignUp)
		auth.POST("/signin", authH.SignIn)
		// Protected admin auth routes — require admin JWT
		authProtected := auth.Group("")
		authProtected.Use(middleware.Authenticate(authCfg))
		{
			authProtected.GET("/profile", authH.GetProfile)
			authProtected.PUT("/profile", authH.UpdateProfile)
			authProtected.PUT("/password", authH.ChangePassword)
			authProtected.POST("/refresh", authH.RefreshToken)
		}
	}

	// ── App Auth ───────────────────────────────────────────────────────────────
	appAuth := api.Group("/app/auth")
	{
		// Public app auth routes
		appAuth.POST("/signin", appAuthH.SignIn)
		appAuth.POST("/refresh", appAuthH.RefreshToken) // refresh is public (uses refresh token, not JWT)

		// Protected app auth routes
		appAuthProtected := appAuth.Group("")
		appAuthProtected.Use(middleware.AuthenticateApp(authCfg))
		{
			appAuthProtected.POST("/signout", appAuthH.SignOut)
			appAuthProtected.GET("/profile", appAuthH.GetProfile)
		}
	}

	// ── Admin-only routes — all require admin JWT ───────────────────────────────
	admin := api.Group("")
	admin.Use(middleware.Authenticate(authCfg))
	{
		// Households (admin manages all households)
		hh := admin.Group("/households")
		{
			hh.GET("", householdsH.List)
			hh.GET("/:id", householdsH.Get)
			hh.POST("", householdsH.Create)
			hh.PUT("/:id", householdsH.Update)
			hh.DELETE("/:id", householdsH.Delete)
			hh.POST("/:id/members", householdsH.AddMember)
			hh.DELETE("/:id/members/:appUserId", householdsH.RemoveMember)
			hh.PUT("/:id/members/:appUserId", householdsH.UpdateMemberRole)
		}

		// App User management (admin only)
		au := admin.Group("/app-users")
		{
			au.GET("", appUsersH.List)
			au.GET("/:id", appUsersH.Get)
			au.POST("", appUsersH.Create)
			au.PUT("/:id", appUsersH.Update)
			au.PUT("/:id/password", appUsersH.ResetPassword)
			au.DELETE("/:id", appUsersH.Delete)
		}

		// Admin expense categories
		aec := admin.Group("/admin/expense-categories")
		{
			aec.GET("", expCatH.AdminList)
			aec.POST("", expCatH.AdminCreate)
			// IMPORTANT: register /reorder BEFORE /:id — Gin matches routes in order.
			// If /:id were first, "reorder" would be captured as the id parameter.
			aec.PUT("/reorder", expCatH.AdminReorder)
			aec.PUT("/:id", expCatH.AdminUpdate)
			aec.DELETE("/:id", expCatH.AdminDelete)
		}

		// Admin income categories
		aic := admin.Group("/admin/income-categories")
		{
			aic.GET("", incCatH.AdminList)
			aic.POST("", incCatH.AdminCreate)
			aic.PUT("/:id", incCatH.AdminUpdate)
			aic.DELETE("/:id", incCatH.AdminDelete)
		}

		// Logs
		lg := admin.Group("/logs")
		{
			lg.GET("", logsH.List)
			lg.GET("/:id", logsH.Get)
			lg.POST("", logsH.Create)
			lg.POST("/batch", logsH.BatchCreate)
			lg.PUT("/:id", logsH.Update)
			lg.DELETE("/:id", logsH.Delete)
		}

		// Settings
		st := admin.Group("/settings")
		{
			st.GET("", settingsH.List)
			st.GET("/config", settingsH.GetConfig)
			st.GET("/:id", settingsH.Get)
			st.POST("", settingsH.Create)
			st.POST("/bulk-update", settingsH.BulkUpdate)
			st.PUT("/:id", settingsH.Update)
			st.DELETE("/:id", settingsH.Delete)
		}
	}

	// ── App routes — all require app user JWT ───────────────────────────────────
	app := api.Group("/app")
	app.Use(middleware.AuthenticateApp(authCfg))
	{
		// Expenses
		exp := app.Group("/expenses")
		{
			exp.GET("", expensesH.List)
			exp.POST("", expensesH.Create)
			exp.PUT("/:id", expensesH.Update)
			exp.DELETE("/:id", expensesH.Delete)
		}

		// Incomes
		inc := app.Group("/incomes")
		{
			inc.GET("", incomesH.List)
			inc.POST("", incomesH.Create)
			inc.PUT("/:id", incomesH.Update)
			inc.DELETE("/:id", incomesH.Delete)
		}

		// App Expense Categories
		aec := app.Group("/expense-categories")
		{
			aec.GET("/favorites", expCatH.AppGetFavorites) // Before /:id
			aec.GET("", expCatH.AppList)
			aec.POST("", expCatH.AppCreate)
			aec.PUT("/:id/budget", expCatH.AppSetBudget)
		}

		// App Income Categories
		aic := app.Group("/income-categories")
		{
			aic.GET("", incCatH.AppList)
			aic.POST("", incCatH.AppCreate)
		}

		// Budget
		bud := app.Group("/budget")
		{
			bud.GET("/month", budgetsH.GetMonthBudget)
			bud.PUT("/base", budgetsH.SetBaseBudget)
			bud.PUT("/override", budgetsH.SetOverride)
			bud.GET("/by-week", budgetsH.GetSpendingByWeek)
			bud.GET("/by-month", budgetsH.GetSpendingByMonth)
		}

		// Notes
		nt := app.Group("/notes")
		{
			nt.GET("", notesH.List)
			nt.POST("", notesH.Create)
			nt.PUT("/:id", notesH.Update)
			nt.DELETE("/:id", notesH.Delete)
		}

		// Assets
		ast := app.Group("/assets")
		{
			ast.GET("", assetsH.List)
			ast.POST("", assetsH.Create)
			ast.PUT("/reorder", assetsH.Reorder) // Before /:id
			ast.PUT("/:id", assetsH.Update)
			ast.DELETE("/:id", assetsH.Delete)
		}
	}

	// Settings config is also accessible without admin auth (frontend needs it on load)
	api.GET("/settings/config", settingsH.GetConfig)
}
