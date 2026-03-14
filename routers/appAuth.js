const Router = require('@koa/router');
const appAuthController = require('../controllers/appAuth');
const { authenticateApp } = require('../middleware/appAuth');

const router = new Router();

// Public routes
router.post('/app/auth/signin', appAuthController.signIn);
router.post('/app/auth/refresh', appAuthController.refreshToken);

// Protected routes
router.post('/app/auth/signout', authenticateApp, appAuthController.signOut);
router.get('/app/auth/profile', authenticateApp, appAuthController.getProfile);

module.exports = router;
