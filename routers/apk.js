const Router = require('@koa/router');
const multer = require('@koa/multer');
const apkController = require('../controllers/apk');
const { managerAuth } = require('../middleware/managerAuth');
const { authenticateAppOrAdmin } = require('../middleware/appAuth');

const router = new Router();
const upload = multer({ storage: multer.memoryStorage() });

// Upload new APK — protected by manager API token
router.post('/apk/upload', managerAuth, upload.single('apk'), apkController.upload);

// Get latest APK info — accessible by app users and management UI admins
router.get('/apk/latest', authenticateAppOrAdmin, apkController.latest);

module.exports = router;
