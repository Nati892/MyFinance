const Router = require('@koa/router');
const settingsController = require('../controllers/settings');
const { authenticate } = require('../middleware/auth');

const router = new Router();

// Protected settings routes
router.get('/settings', authenticate, settingsController.getSettings);
router.get('/settings/config', authenticate, settingsController.getConfigSettings);
router.get('/settings/:id', authenticate, settingsController.getSetting);
router.post('/settings', authenticate, settingsController.createSetting);
router.put('/settings/:id', authenticate, settingsController.updateSetting);
router.delete('/settings/:id', authenticate, settingsController.deleteSetting);
router.post('/settings/bulk-update', authenticate, settingsController.bulkUpdateSettings);

module.exports = router;