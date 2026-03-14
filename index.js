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

const Koa = require('koa');
const bodyParser = require('koa-bodyparser');
const cors = require('@koa/cors');
const router = require('./router');
const db = require('./models');
const logger = require('./utils/logger'); 
const serve = require('koa-static');
const path = require('path');
const send = require('koa-send');

const app = new Koa();
const config = global.cfg;

// Initialize global logger - The Force awakens! 🌟
global.log = logger;



// Middleware
app.use(cors(config.cors));
app.use(bodyParser());
app.use(logger.requestLogger()); // Add request logging


app.use(serve(path.join(__dirname, 'public/front')));

app.use(async (ctx, next) => {
  if (ctx.path.startsWith('/api')) {
    await next();
  } else if (ctx.method === 'GET' && !ctx.body) {
    await send(ctx, 'index.html', { root: path.join(__dirname, 'public/front') });
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

    // Second: Sync models
    await db.sequelize.sync({ force: false });
    console.log('Database synced successfully.');

    // Third: NOW initialize the logger for database writes
    await global.log.initialize();
    global.log.log('info', 'SERVER_START', 'Logger initialized and ready');

    // Fourth: Start server
    app.listen(config.port, config.baseAddress, () => {
      console.log(`Server running on ${config.baseAddress}:${config.port}`);
      global.log.log('info', 'SERVER_START', `Server listening on ${config.baseAddress}:${config.port}`);
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