const Router = require('@koa/router');
const authRoutes = require('./routers/auth');
const logRoutes = require('./routers/log');
const settingsRoutes = require('./routers/settings');
const appAuthRoutes = require('./routers/appAuth');
const appUsersRoutes = require('./routers/appUsers');
const householdsRoutes = require('./routers/households');
const categoriesRoutes = require('./routers/categories');
const transactionsRoutes = require('./routers/transactions');
const notesRoutes = require('./routers/notes');

const router = new Router();

// Admin API routes
router.use('/api', authRoutes.routes());
router.use('/api', logRoutes.routes());
router.use('/api', settingsRoutes.routes());
router.use('/api', appUsersRoutes.routes());
router.use('/api', householdsRoutes.routes());
router.use('/api', categoriesRoutes.routes());

// App API routes
router.use('/api', appAuthRoutes.routes());
router.use('/api', transactionsRoutes.routes());
router.use('/api', notesRoutes.routes());

// Health check
router.get('/health', (ctx) => {
  ctx.body = { status: 'ok', timestamp: new Date() };
});

module.exports = router;