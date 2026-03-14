const Router = require('@koa/router');
const householdsController = require('../controllers/households');
const { authenticate } = require('../middleware/auth');

const router = new Router();

// Admin-protected household management routes
router.get('/api/households', authenticate, householdsController.list);
router.get('/api/households/:id', authenticate, householdsController.get);
router.post('/api/households', authenticate, householdsController.create);
router.put('/api/households/:id', authenticate, householdsController.update);
router.delete('/api/households/:id', authenticate, householdsController.delete);
router.post('/api/households/:id/members', authenticate, householdsController.addMember);
router.delete('/api/households/:id/members/:appUserId', authenticate, householdsController.removeMember);
router.put('/api/households/:id/members/:appUserId', authenticate, householdsController.updateMemberRole);

module.exports = router;
