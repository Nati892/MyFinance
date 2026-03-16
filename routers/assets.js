const Router = require('@koa/router');
const assetsController = require('../controllers/assets');
const { authenticateApp } = require('../middleware/appAuth');

const router = new Router();

router.get('/app/assets', authenticateApp, assetsController.list);
router.post('/app/assets', authenticateApp, assetsController.create);
router.put('/app/assets/reorder', authenticateApp, assetsController.reorder);
router.put('/app/assets/:id', authenticateApp, assetsController.update);
router.delete('/app/assets/:id', authenticateApp, assetsController.delete);

module.exports = router;
