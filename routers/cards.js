const Router = require('@koa/router');
const cardsController = require('../controllers/cards');
const { authenticateApp } = require('../middleware/appAuth');
const { authenticate } = require('../middleware/auth');

const router = new Router();

// App routes (mobile app)
router.get('/app/cards', authenticateApp, cardsController.list);
router.post('/app/cards', authenticateApp, cardsController.create);
router.put('/app/cards/:id', authenticateApp, cardsController.update);
router.delete('/app/cards/:id', authenticateApp, cardsController.delete);

// Admin routes (management system)
router.get('/admin/cards', authenticate, cardsController.adminList);
router.post('/admin/cards', authenticate, cardsController.adminCreate);
router.put('/admin/cards/:id', authenticate, cardsController.adminUpdate);
router.delete('/admin/cards/:id', authenticate, cardsController.adminDelete);

module.exports = router;
