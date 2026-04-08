const Router = require('@koa/router');
const budgetsController = require('../controllers/budgets');
const { authenticateApp } = require('../middleware/appAuth');

const router = new Router();

router.get('/app/budget/month', authenticateApp, budgetsController.getMonthBudget);
router.put('/app/budget/base', authenticateApp, budgetsController.setBaseBudget);
router.put('/app/budget/override', authenticateApp, budgetsController.setOverride);
router.get('/app/budget/by-week', authenticateApp, budgetsController.getSpendingByWeek);
router.get('/app/budget/by-month', authenticateApp, budgetsController.getSpendingByMonth);

// Budget plan items
router.get('/app/budget/plan-items', authenticateApp, budgetsController.getPlanItems);
router.post('/app/budget/plan-items', authenticateApp, budgetsController.createPlanItem);
router.put('/app/budget/plan-items/:id', authenticateApp, budgetsController.updatePlanItem);
router.delete('/app/budget/plan-items/:id', authenticateApp, budgetsController.deletePlanItem);

// Budget month config (start amount)
router.get('/app/budget/month-config', authenticateApp, budgetsController.getMonthConfig);
router.put('/app/budget/month-config', authenticateApp, budgetsController.upsertMonthConfig);

module.exports = router;
