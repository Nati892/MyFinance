const Router = require('@koa/router');
const logController = require('../controllers/log');
const { authenticate } = require('../middleware/auth');

const router = new Router();

// Protected log routes
router.get('/logs', authenticate, logController.getLogs);
router.get('/logs/:id', authenticate, logController.getLog);
router.post('/logs', authenticate, logController.createLog);
router.put('/logs/:id', authenticate, logController.updateLog);
router.delete('/logs/:id', authenticate, logController.deleteLog);

router.post('/logs/batch', logController.createBatchLogs);

module.exports = router;