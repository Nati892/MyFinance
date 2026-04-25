const Router = require('@koa/router');
const multer = require('@koa/multer');
const attachmentsController = require('../controllers/attachments');
const { authenticateApp } = require('../middleware/appAuth');

const router = new Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 15 * 1024 * 1024 } // 15 MB
});

// List attachments by expenseId / incomeId query params
router.get('/app/attachments', authenticateApp, attachmentsController.list.bind(attachmentsController));

// List all attachments for a household
router.get(
  '/app/attachments/household/:householdId',
  authenticateApp,
  attachmentsController.listByHousehold.bind(attachmentsController)
);

// Upload a new attachment
router.post(
  '/app/attachments',
  authenticateApp,
  upload.single('file'),
  attachmentsController.create.bind(attachmentsController)
);

// Rename (update display filename)
router.put('/app/attachments/:id', authenticateApp, attachmentsController.rename.bind(attachmentsController));

// Delete attachment (removes DB row + files from disk)
router.delete('/app/attachments/:id', authenticateApp, attachmentsController.delete.bind(attachmentsController));

// Stream the original file
router.get('/app/attachments/:id/file',  authenticateApp, attachmentsController.streamFile.bind(attachmentsController));

// Stream the thumbnail
router.get('/app/attachments/:id/thumb', authenticateApp, attachmentsController.streamThumb.bind(attachmentsController));

module.exports = router;
