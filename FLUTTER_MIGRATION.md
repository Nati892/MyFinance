# Flutter Migration — Household App

> Migrating the `/app` routes from Angular 19 to a Flutter mobile app.
> Angular admin routes (`/`, `/home`, `/logs`, etc.) remain in Angular — only the user-facing `/app/*` is being ported.

---

## Scope

| Angular Route        | Flutter Screen         | Status      |
|----------------------|------------------------|-------------|
| `/app/login`         | `LoginScreen`          | ⬜ Not started |
| `/app/home`          | `HomeScreen`           | ⬜ Not started |
| `/app/expenses`      | `ExpensesScreen`       | ⬜ Not started |
| `/app/incomes`       | `IncomesScreen`        | ⬜ Not started |
| `/app/budget`        | `BudgetScreen`         | ⬜ Not started |
| `/app/assets`        | `AssetsScreen`         | ⬜ Not started |

**Status legend:** ⬜ Not started · 🔨 In progress · ✅ Built · 🧪 Tested & confirmed

---

## Architecture Decision

**MVVM with Provider + ChangeNotifier** (see `/flutter_app/` for structure).

Three-layer pattern per feature:
```
screens/expenses/
  expenses_screen.dart          # View — pure UI, reads ViewModel state
  expenses_view_model.dart      # ViewModel — ChangeNotifier, state + logic

repositories/
  transaction_repository.dart   # Data — Dio HTTP calls, returns typed models

models/
  expense.dart                  # Data class (fromJson/toJson)
```

---

## API Endpoints Being Ported

### Auth
- `POST /api/app/auth/signin` — login with username/password → access token + refresh token
- `POST /api/app/auth/refresh` — refresh access token
- `GET  /api/app/auth/profile` — get logged-in user profile

### Transactions
- `GET    /api/app/expenses` — list with filters (householdId, view, periodOffset, categoryId)
- `POST   /api/app/expenses` — create expense
- `PUT    /api/app/expenses/:id` — update expense
- `DELETE /api/app/expenses/:id` — delete expense
- `GET    /api/app/incomes` — list incomes (same filters)
- `POST   /api/app/incomes` — create income
- `PUT    /api/app/incomes/:id` — update income
- `DELETE /api/app/incomes/:id` — delete income

### Budget
- `GET /api/app/budget/month` — monthly budget with spending per category
- `PUT /api/app/budget/base` — set base budget
- `PUT /api/app/budget/override` — month-specific override
- `GET /api/app/budget/by-week` — weekly breakdown
- `GET /api/app/budget/by-month` — multi-month comparison

### Assets
- `GET    /api/app/assets` — list assets
- `POST   /api/app/assets` — create asset
- `PUT    /api/app/assets/:id` — update asset
- `DELETE /api/app/assets/:id` — delete asset
- `PUT    /api/app/assets/reorder` — reorder

### Categories
- `GET  /api/app/expense-categories` — list with householdId
- `GET  /api/app/income-categories` — list with householdId
- `POST /api/app/expense-categories` — create
- `POST /api/app/income-categories` — create
- `GET  /api/app/expense-categories/favorites` — favorites

---

## Key Features to Port

- [x] JWT auth with access token + refresh token (auto-refresh when near expiry)
- [x] Household selection state (shared across screens)
- [x] Category sidebar / filtering
- [x] Timeline view (monthly/weekly/daily) with period navigation
- [x] Add/Edit/Delete for expenses, incomes, assets
- [x] Budget overview with per-category spending
- [x] RTL + Hebrew language support (`he` / `en`)
- [ ] Real-time notes via Socket.IO (lower priority)

---

## Flutter Dependencies (planned)

| Package              | Purpose                          |
|----------------------|----------------------------------|
| `provider`           | State management (MVVM glue)     |
| `dio`                | HTTP client (interceptors, auth) |
| `flutter_secure_storage` | Token storage               |
| `go_router`          | Navigation / routing             |
| `intl`               | Date formatting, i18n            |
| `flutter_localizations` | RTL + locale support          |

---

## Progress Log

| Date       | Work Done                              |
|------------|----------------------------------------|
| 2026-03-27 | Project tracking file created. Architecture decided. |
| 2026-03-28 | Flutter project scaffolded (`flutter_app/`). Full layer skeleton: core/network (Dio + interceptors), core/storage (SecureStorage), models (Expense, Income, Asset, Category, AppUser, Household), repositories (auth, transaction, category, budget, asset), services (auth, household, transaction), router (GoRouter), screen stubs for all 6 screens. `flutter analyze` passes clean. |
