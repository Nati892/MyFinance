const Router = require('@koa/router');
const multer = require('@koa/multer');
const apkController = require('../controllers/apk');
const { managerAuth } = require('../middleware/managerAuth');
const { authenticateApp } = require('../middleware/appAuth');

const router = new Router();
const upload = multer({ storage: multer.memoryStorage() });

// Upload new APK — protected by manager API token
router.post('/apk/upload', managerAuth, upload.single('apk'), apkController.upload);

// Get latest APK info — protected by app user auth
router.get('/apk/latest', authenticateApp, apkController.latest);

module.exports = router;
