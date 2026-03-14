const Router = require('@koa/router');
const householdsController = require('../controllers/households');
const { authenticate } = require('../middleware/auth');

const router = new Router();

// Admin-protected household management routes
router.get('/households', authenticate, householdsController.list);
router.get('/households/:id', authenticate, householdsController.get);
router.post('/households', authenticate, householdsController.create);
router.put('/households/:id', authenticate, householdsController.update);
router.delete('/households/:id', authenticate, householdsController.delete);
router.post('/households/:id/members', authenticate, householdsController.addMember);
router.delete('/households/:id/members/:appUserId', authenticate, householdsController.removeMember);
router.put('/households/:id/members/:appUserId', authenticate, householdsController.updateMemberRole);

module.exports = router;
