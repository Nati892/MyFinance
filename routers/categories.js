const Router = require('@koa/router');
const expenseCategoriesController = require('../controllers/expenseCategories');
const incomeCategoriesController = require('../controllers/incomeCategories');
const { authenticate } = require('../middleware/auth');
const { authenticateApp } = require('../middleware/appAuth');

const router = new Router();

// ─── Admin: Expense Categories ────────────────────────────────────────────────
router.get('/admin/expense-categories', authenticate, expenseCategoriesController.adminList);
router.post('/admin/expense-categories', authenticate, expenseCategoriesController.adminCreate);
// /reorder must be registered before /:id so it is matched first
router.put('/admin/expense-categories/reorder', authenticate, expenseCategoriesController.adminReorder);
router.put('/admin/expense-categories/:id', authenticate, expenseCategoriesController.adminUpdate);
router.delete('/admin/expense-categories/:id', authenticate, expenseCategoriesController.adminDelete);

// ─── Admin: Income Categories ─────────────────────────────────────────────────
router.get('/admin/income-categories', authenticate, incomeCategoriesController.adminList);
router.post('/admin/income-categories', authenticate, incomeCategoriesController.adminCreate);
// /reorder must be registered before /:id so it is matched first
router.put('/admin/income-categories/reorder', authenticate, incomeCategoriesController.adminReorder);
router.put('/admin/income-categories/:id', authenticate, incomeCategoriesController.adminUpdate);
router.delete('/admin/income-categories/:id', authenticate, incomeCategoriesController.adminDelete);

// ─── App: Expense Categories ──────────────────────────────────────────────────
router.get('/app/expense-categories', authenticateApp, expenseCategoriesController.appList);
router.put('/app/expense-categories/:id/budget', authenticateApp, expenseCategoriesController.appUpdateBudget);

// ─── App: Income Categories ───────────────────────────────────────────────────
router.get('/app/income-categories', authenticateApp, incomeCategoriesController.appList);

module.exports = router;
