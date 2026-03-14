const Router               = require('@koa/router');
const expensesController   = require('../controllers/expenses');
const incomesController    = require('../controllers/incomes');
const { authenticateApp }  = require('../middleware/appAuth');

const router = new Router();

// ── Expenses ────────────────────────────────────────────────────────────────
router.get   ('/app/expenses',     authenticateApp, expensesController.list);
router.post  ('/app/expenses',     authenticateApp, expensesController.create);
router.put   ('/app/expenses/:id', authenticateApp, expensesController.update);
router.delete('/app/expenses/:id', authenticateApp, expensesController.delete);

// ── Incomes ──────────────────────────────────────────────────────────────────
router.get   ('/app/incomes',     authenticateApp, incomesController.list);
router.post  ('/app/incomes',     authenticateApp, incomesController.create);
router.put   ('/app/incomes/:id', authenticateApp, incomesController.update);
router.delete('/app/incomes/:id', authenticateApp, incomesController.delete);

module.exports = router;
