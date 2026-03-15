const Router = require('@koa/router');
const notesController = require('../controllers/notes');
const { authenticateApp } = require('../middleware/appAuth');

const router = new Router();

router.get('/app/notes', authenticateApp, notesController.list);
router.post('/app/notes', authenticateApp, notesController.create);
router.put('/app/notes/:id', authenticateApp, notesController.update);
router.delete('/app/notes/:id', authenticateApp, notesController.delete);

module.exports = router;
