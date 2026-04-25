require('dotenv').config();
const env = process.env.ENV || 'development';
console.log(`Loading configuration for environment: ${env}`);

try {
  global.cfg = require(`./conf/${env}.js`);
} catch (error) {
  console.error(`Failed to load config for environment "${env}"`);
  console.error(`Falling back to example config. Create /conf/${env}.js to use ${env} environment.`);
  global.cfg = require('./conf/example.js');
}

const http = require('http');
const Koa = require('koa');
const bodyParser = require('koa-bodyparser');

const router = require('./router');
const db = require('./models');
const logger = require('./utils/logger');
const { seedAdmin } = require('./utils/seed');
const serve = require('koa-static');
const path = require('path');
const send = require('koa-send');
const socketUtil = require('./utils/socket');
const { startCron } = require('./utils/cron');
const { runMigrations } = require('./utils/runMigrations');

const app = new Koa();
const config = global.cfg;

// Initialize global logger - The Force awakens! 🌟
global.log = logger;



// Middleware — permissive CORS for development
app.use(async (ctx, next) => {
  ctx.set('Access-Control-Allow-Origin', ctx.get('Origin') || '*');
  ctx.set('Access-Control-Allow-Credentials', 'true');
  ctx.set('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,PATCH,OPTIONS');
  ctx.set('Access-Control-Allow-Headers', 'Content-Type,Authorization,Accept,X-Requested-With,Origin');
  ctx.set('Access-Control-Expose-Headers', 'Content-Length,Date,X-Request-Id');
  ctx.set('Access-Control-Max-Age', '86400');
  if (ctx.method === 'OPTIONS') {
    ctx.status = 204;
    return;
  }
  await next();
});
app.use(bodyParser({ jsonLimit: '10mb', formLimit: '10mb', textLimit: '10mb' }));
app.use(logger.requestLogger()); // Add request logging


app.use(serve(path.join(__dirname, 'public/front')));
app.use(serve(path.join(__dirname, 'public/apk'), { index: false }));

// Flutter web is built with --base-href /app/, so asset requests arrive as /app/flutter.js etc.
// Strip the /app prefix before delegating to koa-static.
const flutterServe = serve(path.join(__dirname, 'public/flutter'));
app.use(async (ctx, next) => {
  if (ctx.path.startsWith('/app')) {
    const original = ctx.path;
    ctx.path = ctx.path.slice(4) || '/';
    await flutterServe(ctx, async () => {});
    ctx.path = original;
    if (ctx.body) return;
  }
  await next();
});

app.use(async (ctx, next) => {
  if (ctx.path.startsWith('/api') || ctx.path.startsWith('/apk/')) {
    await next();
  } else if (ctx.method === 'GET' && !ctx.body) {
    if (ctx.path.startsWith('/app')) {
      await send(ctx, 'index.html', { root: path.join(__dirname, 'public/flutter') });
    } else {
      await send(ctx, 'index.html', { root: path.join(__dirname, 'public/front') });
    }
  }
});

// Routes
app.use(router.routes());
app.use(router.allowedMethods());

// Error handling
app.on('error', (err, ctx) => {
  console.error('Server error:', err);
  // Log server errors
  global.log.log('err', 'SERVER_ERROR', 'Unhandled server error', err, {
    path: ctx.path,
    method: ctx.method
  });
});

// Database connection and server start
async function startServer() {
  try {
    // First: Database connection (no logging yet!)
    await db.sequelize.authenticate();
    console.log('Database connection established successfully.');

    // Second: Run pending migrations (ALTER TABLE etc. that sync won't do)
    await runMigrations(db.sequelize);

    // Third: Sync models (creates new tables, no-ops on existing)
    await db.sequelize.sync({ force: false });
    console.log('Database synced successfully.');

    // Third: Seed default admin user if none exists
    await seedAdmin(db.User);

    // Fourth: NOW initialize the logger for database writes
    await global.log.initialize();
    global.log.log('info', 'SERVER_START', 'Logger initialized and ready');

    // Fourth: Start server with Socket.IO
    const httpServer = http.createServer(app.callback());
    socketUtil.init(httpServer);

    httpServer.listen(config.port, config.baseAddress, () => {
      console.log(`Server running on ${config.baseAddress}:${config.port}`);
      global.log.log('info', 'SERVER_START', `Server listening on ${config.baseAddress}:${config.port}`);
      startCron();
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    // Don't use global.log here - might not be initialized!
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  global.log.info('SERVER_SHUTDOWN', 'Received SIGTERM signal');
  global.log.stopSizeMonitoring();
  process.exit(0);
});

startServer();