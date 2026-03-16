const Router = require('@koa/router');
const budgetsController = require('../controllers/budgets');
const { authenticateApp } = require('../middleware/appAuth');

const router = new Router();

router.get('/app/budget/month', authenticateApp, budgetsController.getMonthBudget);
router.put('/app/budget/base', authenticateApp, budgetsController.setBaseBudget);
router.put('/app/budget/override', authenticateApp, budgetsController.setOverride);
router.get('/app/budget/by-week', authenticateApp, budgetsController.getSpendingByWeek);
router.get('/app/budget/by-month', authenticateApp, budgetsController.getSpendingByMonth);

module.exports = router;
