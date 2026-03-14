const Router = require('@koa/router');
const appUsersController = require('../controllers/appUsers');
const { authenticate } = require('../middleware/auth');

const router = new Router();

// Admin-protected app user management routes
router.get('/app-users', authenticate, appUsersController.list);
router.get('/app-users/:id', authenticate, appUsersController.get);
router.post('/app-users', authenticate, appUsersController.create);
router.put('/app-users/:id', authenticate, appUsersController.update);
router.put('/app-users/:id/password', authenticate, appUsersController.resetPassword);
router.delete('/app-users/:id', authenticate, appUsersController.delete);

module.exports = router;
