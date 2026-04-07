const Router = require('@koa/router');
const c = require('../controllers/shopping');
const { authenticateApp } = require('../middleware/appAuth');

const router = new Router();

// Categories
router.get('/app/shopping/categories', authenticateApp, c.listCategories);
router.post('/app/shopping/categories', authenticateApp, c.createCategory);
router.put('/app/shopping/categories/:id', authenticateApp, c.updateCategory);
router.delete('/app/shopping/categories/:id', authenticateApp, c.deleteCategory);

// Stores
router.get('/app/shopping/stores', authenticateApp, c.listStores);
router.post('/app/shopping/stores', authenticateApp, c.createStore);
router.put('/app/shopping/stores/:id', authenticateApp, c.updateStore);
router.delete('/app/shopping/stores/:id', authenticateApp, c.deleteStore);

// Items
router.get('/app/shopping/items', authenticateApp, c.listItems);
router.post('/app/shopping/items', authenticateApp, c.createItem);
router.put('/app/shopping/items/:id', authenticateApp, c.updateItem);
router.delete('/app/shopping/items/:id', authenticateApp, c.deleteItem);

// Lists (templates)
router.get('/app/shopping/lists', authenticateApp, c.listLists);
router.post('/app/shopping/lists', authenticateApp, c.createList);
router.put('/app/shopping/lists/:id', authenticateApp, c.updateList);
router.delete('/app/shopping/lists/:id', authenticateApp, c.deleteList);
router.get('/app/shopping/lists/:id/items', authenticateApp, c.getListItems);
router.post('/app/shopping/lists/:id/items', authenticateApp, c.addListItem);
router.put('/app/shopping/lists/:id/items/:itemId', authenticateApp, c.updateListItem);
router.delete('/app/shopping/lists/:id/items/:itemId', authenticateApp, c.deleteListItem);

// Sessions (board cards)
router.get('/app/shopping/sessions', authenticateApp, c.listSessions);
router.post('/app/shopping/sessions', authenticateApp, c.createSession);
router.put('/app/shopping/sessions/:id', authenticateApp, c.updateSession);
router.delete('/app/shopping/sessions/:id', authenticateApp, c.deleteSession);
router.patch('/app/shopping/sessions/:id/items/:itemId', authenticateApp, c.patchSessionItem);
router.post('/app/shopping/sessions/:id/items', authenticateApp, c.addSessionItem);

module.exports = router;
