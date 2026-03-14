const Router = require('@koa/router');
const authController = require('../controllers/auth');
const { authenticate } = require('../middleware/auth');

const router = new Router();

// Public routes
router.post('/auth/signup', authController.signUp);
router.post('/auth/signin', authController.signIn);

// Protected routes
router.get('/auth/profile', authenticate, authController.getProfile);
router.put('/auth/profile', authenticate, authController.updateProfile);
router.put('/auth/password', authenticate, authController.changePassword);
router.post('/auth/refresh', authenticate, authController.refreshToken);

module.exports = router;