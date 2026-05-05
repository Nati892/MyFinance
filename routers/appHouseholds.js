const Router = require('@koa/router');
const householdsController = require('../controllers/households');
const { authenticateApp } = require('../middleware/appAuth');

const router = new Router();

router.put('/app/households/:id/settings', authenticateApp, householdsController.appUpdateSettings);

module.exports = router;
