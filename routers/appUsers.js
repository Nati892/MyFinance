const Router = require('@koa/router');
const appUsersController = require('../controllers/appUsers');
const { authenticate } = require('../middleware/auth');

const router = new Router();

// Admin-protected app user management routes
router.get('/api/app-users', authenticate, appUsersController.list);
router.get('/api/app-users/:id', authenticate, appUsersController.get);
router.post('/api/app-users', authenticate, appUsersController.create);
router.put('/api/app-users/:id', authenticate, appUsersController.update);
router.put('/api/app-users/:id/password', authenticate, appUsersController.resetPassword);
router.delete('/api/app-users/:id', authenticate, appUsersController.delete);

module.exports = router;
