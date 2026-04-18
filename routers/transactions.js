const Router                      = require('@koa/router');
const expensesController          = require('../controllers/expenses');
const incomesController           = require('../controllers/incomes');
const recurringExpensesController = require('../controllers/recurringExpenses');
const expenseSchedulesController  = require('../controllers/expenseSchedules');
const { authenticateApp }         = require('../middleware/appAuth');

const router = new Router();

// ── Expenses ────────────────────────────────────────────────────────────────
router.get   ('/app/expenses',                          authenticateApp, expensesController.list);
router.post  ('/app/expenses',                          authenticateApp, expensesController.create);
router.put   ('/app/expenses/:id',                      authenticateApp, expensesController.update);
router.put   ('/app/expenses/:id/installment-amount',   authenticateApp, expensesController.updateInstallmentAmount);
router.delete('/app/expenses/:id',                      authenticateApp, expensesController.delete);

// ── Recurring Expenses ───────────────────────────────────────────────────────
router.get   ('/app/recurring-expenses',     authenticateApp, recurringExpensesController.list);
router.post  ('/app/recurring-expenses',     authenticateApp, recurringExpensesController.create);
router.put   ('/app/recurring-expenses/:id', authenticateApp, recurringExpensesController.update);
router.delete('/app/recurring-expenses/:id', authenticateApp, recurringExpensesController.delete);

// ── Expense Schedules ────────────────────────────────────────────────────────
// today-suggestions must be before /:id to avoid route conflict
router.get   ('/app/expense-schedules/today-suggestions', authenticateApp, expenseSchedulesController.todaySuggestions);
router.get   ('/app/expense-schedules',                   authenticateApp, expenseSchedulesController.list);
router.post  ('/app/expense-schedules',                   authenticateApp, expenseSchedulesController.create);
router.put   ('/app/expense-schedules/:id',               authenticateApp, expenseSchedulesController.update);
router.delete('/app/expense-schedules/:id',               authenticateApp, expenseSchedulesController.delete);

// ── Incomes ──────────────────────────────────────────────────────────────────
router.get   ('/app/incomes',     authenticateApp, incomesController.list);
router.post  ('/app/incomes',     authenticateApp, incomesController.create);
router.put   ('/app/incomes/:id', authenticateApp, incomesController.update);
router.delete('/app/incomes/:id', authenticateApp, incomesController.delete);

module.exports = router;
