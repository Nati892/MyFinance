const Router = require('@koa/router');
const authRoutes = require('./routers/auth');
const logRoutes = require('./routers/log');
const settingsRoutes = require('./routers/settings');

const router = new Router();

// API routes
router.use('/api', authRoutes.routes());
router.use('/api', logRoutes.routes());
router.use('/api', settingsRoutes.routes());

// Health check
router.get('/health', (ctx) => {
  ctx.body = { status: 'ok', timestamp: new Date() };
});


router.get('/(.*)', async (ctx) => {
  await send(ctx, ctx.path, { root: path.join(__dirname, './public/front') });
});

module.exports = router;