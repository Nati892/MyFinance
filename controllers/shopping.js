const {
  ShoppingCategory,
  ShoppingStore,
  ShoppingItem,
  ShoppingList,
  ShoppingListItem,
  ShoppingSession,
  ShoppingSessionItem,
  HouseholdMember,
  AppUser,
  ExpenseCategory,
  Expense,
  BudgetPlanItem
} = require('../models');
const { getIO } = require('../utils/socket');
const { createExpenseRecord } = require('./expenses');

// Plan + lifecycle fields accepted by createSession and updateSession
const PLAN_FIELDS = [
  'mode',
  'plannedMinPrice',
  'plannedMaxPrice',
  'plannedYear',
  'plannedMonth',
  'plannedWeekOfMonth',
  'expenseCategoryId'
];

function pickPlanFields(body) {
  const out = {};
  for (const k of PLAN_FIELDS) {
    if (body[k] !== undefined) out[k] = body[k];
  }
  return out;
}

async function upsertBudgetPlanItemForSession(session) {
  if (!session.expenseCategoryId || !session.plannedYear || !session.plannedMonth) {
    return null;
  }
  const [item] = await BudgetPlanItem.findOrCreate({
    where: {
      householdId: session.householdId,
      expenseCategoryId: session.expenseCategoryId,
      year: session.plannedYear,
      month: session.plannedMonth
    },
    defaults: {
      minAmount: session.plannedMinPrice || 0,
      maxAmount: session.plannedMaxPrice || 0,
      description: session.name
    }
  });
  await item.update({
    minAmount: session.plannedMinPrice || 0,
    maxAmount: session.plannedMaxPrice || 0
  });
  return item;
}

// ─── Helpers ────────────────────────────────────────────────────────────────

async function assertMember(householdId, appUserId, ctx) {
  const m = await HouseholdMember.findOne({ where: { householdId, appUserId } });
  if (!m) {
    ctx.status = 403;
    ctx.body = { error: 'Not a member of this household' };
    return false;
  }
  return true;
}

// ─── Categories ──────────────────────────────────────────────────────────────

class ShoppingController {

  async listCategories(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { householdId } = ctx.query;
      if (!householdId) { ctx.status = 400; ctx.body = { error: 'householdId required' }; return; }
      if (!await assertMember(householdId, appUser.id, ctx)) return;

      const categories = await ShoppingCategory.findAll({
        where: { householdId },
        order: [['name', 'ASC']]
      });
      ctx.body = { success: true, categories };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async createCategory(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { name, nameHe, icon, householdId } = ctx.request.body;
      if (!householdId || !name) { ctx.status = 400; ctx.body = { error: 'name and householdId required' }; return; }
      if (!await assertMember(householdId, appUser.id, ctx)) return;

      const category = await ShoppingCategory.create({ name, nameHe, icon, householdId });
      ctx.status = 201;
      ctx.body = { success: true, category };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async updateCategory(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;
      const { name, nameHe, icon } = ctx.request.body;

      const category = await ShoppingCategory.findByPk(id);
      if (!category) { ctx.status = 404; ctx.body = { error: 'Not found' }; return; }
      if (!await assertMember(category.householdId, appUser.id, ctx)) return;

      const updates = {};
      if (name !== undefined) updates.name = name;
      if (nameHe !== undefined) updates.nameHe = nameHe;
      if (icon !== undefined) updates.icon = icon;
      await category.update(updates);
      ctx.body = { success: true, category };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async deleteCategory(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;
      const category = await ShoppingCategory.findByPk(id);
      if (!category) { ctx.status = 404; ctx.body = { error: 'Not found' }; return; }
      if (!await assertMember(category.householdId, appUser.id, ctx)) return;
      await category.destroy();
      ctx.body = { success: true };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  // ─── Stores ────────────────────────────────────────────────────────────────

  async listStores(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { householdId } = ctx.query;
      if (!householdId) { ctx.status = 400; ctx.body = { error: 'householdId required' }; return; }
      if (!await assertMember(householdId, appUser.id, ctx)) return;

      const stores = await ShoppingStore.findAll({
        where: { householdId },
        order: [['name', 'ASC']]
      });
      ctx.body = { success: true, stores };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async createStore(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { name, householdId } = ctx.request.body;
      if (!householdId || !name) { ctx.status = 400; ctx.body = { error: 'name and householdId required' }; return; }
      if (!await assertMember(householdId, appUser.id, ctx)) return;

      const store = await ShoppingStore.create({ name, householdId });
      ctx.status = 201;
      ctx.body = { success: true, store };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async updateStore(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;
      const { name } = ctx.request.body;

      const store = await ShoppingStore.findByPk(id);
      if (!store) { ctx.status = 404; ctx.body = { error: 'Not found' }; return; }
      if (!await assertMember(store.householdId, appUser.id, ctx)) return;

      if (name !== undefined) await store.update({ name });
      ctx.body = { success: true, store };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async deleteStore(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;
      const store = await ShoppingStore.findByPk(id);
      if (!store) { ctx.status = 404; ctx.body = { error: 'Not found' }; return; }
      if (!await assertMember(store.householdId, appUser.id, ctx)) return;
      await store.destroy();
      ctx.body = { success: true };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  // ─── Items ─────────────────────────────────────────────────────────────────

  async listItems(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { householdId } = ctx.query;
      if (!householdId) { ctx.status = 400; ctx.body = { error: 'householdId required' }; return; }
      if (!await assertMember(householdId, appUser.id, ctx)) return;

      const items = await ShoppingItem.findAll({
        where: { householdId },
        include: [{ model: ShoppingCategory, as: 'category', attributes: ['id', 'name', 'nameHe', 'icon'] }],
        order: [['name', 'ASC']]
      });
      ctx.body = { success: true, items };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async createItem(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { name, nameHe, icon, defaultUnit, categoryId, householdId } = ctx.request.body;
      if (!householdId || !name) { ctx.status = 400; ctx.body = { error: 'name and householdId required' }; return; }
      if (!await assertMember(householdId, appUser.id, ctx)) return;

      const item = await ShoppingItem.create({
        name, nameHe, icon,
        defaultUnit: defaultUnit || 'pcs',
        categoryId: categoryId || null,
        householdId,
        createdBy: appUser.id
      });
      const itemWithCategory = await ShoppingItem.findByPk(item.id, {
        include: [{ model: ShoppingCategory, as: 'category', attributes: ['id', 'name', 'nameHe', 'icon'] }]
      });
      ctx.status = 201;
      ctx.body = { success: true, item: itemWithCategory };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async updateItem(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;
      const { name, nameHe, icon, defaultUnit, categoryId } = ctx.request.body;

      const item = await ShoppingItem.findByPk(id);
      if (!item) { ctx.status = 404; ctx.body = { error: 'Not found' }; return; }
      if (!await assertMember(item.householdId, appUser.id, ctx)) return;

      const updates = {};
      if (name !== undefined) updates.name = name;
      if (nameHe !== undefined) updates.nameHe = nameHe;
      if (icon !== undefined) updates.icon = icon;
      if (defaultUnit !== undefined) updates.defaultUnit = defaultUnit;
      if (categoryId !== undefined) updates.categoryId = categoryId;
      await item.update(updates);

      const updated = await ShoppingItem.findByPk(id, {
        include: [{ model: ShoppingCategory, as: 'category', attributes: ['id', 'name', 'nameHe', 'icon'] }]
      });
      ctx.body = { success: true, item: updated };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async deleteItem(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;
      const item = await ShoppingItem.findByPk(id);
      if (!item) { ctx.status = 404; ctx.body = { error: 'Not found' }; return; }
      if (!await assertMember(item.householdId, appUser.id, ctx)) return;
      await item.destroy();
      ctx.body = { success: true };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  // ─── Lists (templates) ─────────────────────────────────────────────────────

  async listLists(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { householdId } = ctx.query;
      if (!householdId) { ctx.status = 400; ctx.body = { error: 'householdId required' }; return; }
      if (!await assertMember(householdId, appUser.id, ctx)) return;

      const lists = await ShoppingList.findAll({
        where: { householdId },
        order: [['createdAt', 'DESC']]
      });
      ctx.body = { success: true, lists };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async createList(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { name, nameHe, householdId } = ctx.request.body;
      if (!householdId || !name) { ctx.status = 400; ctx.body = { error: 'name and householdId required' }; return; }
      if (!await assertMember(householdId, appUser.id, ctx)) return;

      const list = await ShoppingList.create({ name, nameHe, householdId, createdBy: appUser.id });
      ctx.status = 201;
      ctx.body = { success: true, list };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async updateList(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;
      const { name, nameHe } = ctx.request.body;

      const list = await ShoppingList.findByPk(id);
      if (!list) { ctx.status = 404; ctx.body = { error: 'Not found' }; return; }
      if (!await assertMember(list.householdId, appUser.id, ctx)) return;

      const updates = {};
      if (name !== undefined) updates.name = name;
      if (nameHe !== undefined) updates.nameHe = nameHe;
      await list.update(updates);
      ctx.body = { success: true, list };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async deleteList(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;
      const list = await ShoppingList.findByPk(id);
      if (!list) { ctx.status = 404; ctx.body = { error: 'Not found' }; return; }
      if (!await assertMember(list.householdId, appUser.id, ctx)) return;
      await list.destroy();
      ctx.body = { success: true };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async getListItems(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;
      const list = await ShoppingList.findByPk(id, {
        include: [{
          model: ShoppingListItem,
          as: 'listItems',
          include: [{ model: ShoppingItem, as: 'item', include: [{ model: ShoppingCategory, as: 'category' }] }],
          order: [['sortOrder', 'ASC']]
        }]
      });
      if (!list) { ctx.status = 404; ctx.body = { error: 'Not found' }; return; }
      if (!await assertMember(list.householdId, appUser.id, ctx)) return;
      ctx.body = { success: true, list };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async addListItem(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;
      const { itemId, amount, unit, extraData, sortOrder } = ctx.request.body;

      const list = await ShoppingList.findByPk(id);
      if (!list) { ctx.status = 404; ctx.body = { error: 'Not found' }; return; }
      if (!await assertMember(list.householdId, appUser.id, ctx)) return;

      const listItem = await ShoppingListItem.create({
        listId: id,
        itemId,
        amount: amount || 1,
        unit: unit || 'pcs',
        extraData: extraData || null,
        sortOrder: sortOrder || 0
      });
      const withItem = await ShoppingListItem.findByPk(listItem.id, {
        include: [{ model: ShoppingItem, as: 'item', include: [{ model: ShoppingCategory, as: 'category' }] }]
      });
      ctx.status = 201;
      ctx.body = { success: true, listItem: withItem };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async updateListItem(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id, itemId } = ctx.params;
      const { amount, unit, extraData, sortOrder } = ctx.request.body;

      const listItem = await ShoppingListItem.findOne({ where: { id: itemId, listId: id } });
      if (!listItem) { ctx.status = 404; ctx.body = { error: 'Not found' }; return; }

      const list = await ShoppingList.findByPk(id);
      if (!await assertMember(list.householdId, appUser.id, ctx)) return;

      const updates = {};
      if (amount !== undefined) updates.amount = amount;
      if (unit !== undefined) updates.unit = unit;
      if (extraData !== undefined) updates.extraData = extraData;
      if (sortOrder !== undefined) updates.sortOrder = sortOrder;
      await listItem.update(updates);
      ctx.body = { success: true, listItem };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async deleteListItem(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id, itemId } = ctx.params;

      const listItem = await ShoppingListItem.findOne({ where: { id: itemId, listId: id } });
      if (!listItem) { ctx.status = 404; ctx.body = { error: 'Not found' }; return; }

      const list = await ShoppingList.findByPk(id);
      if (!await assertMember(list.householdId, appUser.id, ctx)) return;

      await listItem.destroy();
      ctx.body = { success: true };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  // ─── Sessions ──────────────────────────────────────────────────────────────

  async listSessions(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { householdId } = ctx.query;
      if (!householdId) { ctx.status = 400; ctx.body = { error: 'householdId required' }; return; }
      if (!await assertMember(householdId, appUser.id, ctx)) return;

      const sessions = await ShoppingSession.findAll({
        where: { householdId },
        include: [{
          model: ShoppingSessionItem,
          as: 'sessionItems',
          include: [
            { model: ShoppingItem, as: 'item', include: [{ model: ShoppingCategory, as: 'category' }] },
            { model: ShoppingStore, as: 'store' }
          ],
          order: [['sortOrder', 'ASC']]
        }],
        order: [['zIndex', 'ASC']]
      });
      ctx.body = { success: true, sessions };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async createSession(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { name, listId, noteColor, householdId, items } = ctx.request.body;
      if (!householdId || !name) { ctx.status = 400; ctx.body = { error: 'name and householdId required' }; return; }
      if (!await assertMember(householdId, appUser.id, ctx)) return;

      const session = await ShoppingSession.create({
        name,
        listId: listId || null,
        noteColor: noteColor || '#fff9c4',
        householdId,
        createdBy: appUser.id,
        ...pickPlanFields(ctx.request.body)
      });

      // Clone items from template list OR use provided items array
      let sessionItemsData = [];
      if (listId && !items) {
        const listItems = await ShoppingListItem.findAll({
          where: { listId },
          order: [['sortOrder', 'ASC']]
        });
        sessionItemsData = listItems.map((li, idx) => ({
          sessionId: session.id,
          itemId: li.itemId,
          amount: li.amount,
          unit: li.unit,
          extraData: li.extraData,
          sortOrder: idx
        }));
      } else if (items && Array.isArray(items)) {
        sessionItemsData = items.map((it, idx) => ({
          sessionId: session.id,
          itemId: it.itemId,
          amount: it.amount || 1,
          unit: it.unit || 'pcs',
          extraData: it.extraData || null,
          sortOrder: idx
        }));
      }

      if (sessionItemsData.length > 0) {
        await ShoppingSessionItem.bulkCreate(sessionItemsData);
      }

      const sessionWithItems = await ShoppingSession.findByPk(session.id, {
        include: [{
          model: ShoppingSessionItem,
          as: 'sessionItems',
          include: [
            { model: ShoppingItem, as: 'item', include: [{ model: ShoppingCategory, as: 'category' }] },
            { model: ShoppingStore, as: 'store' }
          ],
          order: [['sortOrder', 'ASC']]
        }]
      });

      const io = getIO();
      if (io) {
        io.to(`household:${householdId}`).emit('shopping:created', sessionWithItems);
      }

      ctx.status = 201;
      ctx.body = { success: true, session: sessionWithItems };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async updateSession(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;
      const { posX, posY, zIndex, rotation, width, height, noteColor, name } = ctx.request.body;

      const session = await ShoppingSession.findByPk(id);
      if (!session) { ctx.status = 404; ctx.body = { error: 'Not found' }; return; }
      if (!await assertMember(session.householdId, appUser.id, ctx)) return;

      const updates = {};
      if (posX !== undefined) updates.posX = posX;
      if (posY !== undefined) updates.posY = posY;
      if (zIndex !== undefined) updates.zIndex = zIndex;
      if (rotation !== undefined) updates.rotation = rotation;
      if (width !== undefined) updates.width = width;
      if (height !== undefined) updates.height = height;
      if (noteColor !== undefined) updates.noteColor = noteColor;
      if (name !== undefined) updates.name = name;
      Object.assign(updates, pickPlanFields(ctx.request.body));
      await session.update(updates);

      // If this session is already linked to a plan item and any plan field changed,
      // propagate the change to the linked BudgetPlanItem.
      const planFieldChanged = PLAN_FIELDS.some(k => k in updates);
      if (session.linkedBudgetPlanItemId && planFieldChanged) {
        await upsertBudgetPlanItemForSession(session);
      }

      const io = getIO();
      if (io) {
        io.to(`household:${session.householdId}`).emit('shopping:updated', { id: session.id, ...updates });
      }

      ctx.body = { success: true, session };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async completeSession(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;
      const {
        actualAmount,
        dateTime,
        expenseCategoryId,
        description,
        note,
        paymentMethod,
        cardId,
        installmentTotal
      } = ctx.request.body;

      const session = await ShoppingSession.findByPk(id, {
        include: [{ model: ShoppingSessionItem, as: 'sessionItems' }]
      });
      if (!session) { ctx.status = 404; ctx.body = { error: 'Not found' }; return; }
      if (!await assertMember(session.householdId, appUser.id, ctx)) return;

      if (session.completedAt) {
        ctx.status = 400;
        ctx.body = { error: 'Session already completed' };
        return;
      }

      // Resolve amount: prefer explicit, otherwise sum obtained/partial item prices.
      let amount = actualAmount !== undefined ? Number(actualAmount) : null;
      if (amount === null) {
        amount = session.sessionItems
          .filter(it => it.status === 'got' || it.status === 'partial')
          .reduce((s, it) => s + (parseFloat(it.price) || 0), 0);
      }
      if (!amount || amount <= 0) {
        ctx.status = 400;
        ctx.body = { error: 'Cannot create expense with amount 0. Enter prices on items or pass actualAmount.' };
        return;
      }

      const categoryId = expenseCategoryId || session.expenseCategoryId;
      if (!categoryId) {
        ctx.status = 400;
        ctx.body = { error: 'expenseCategoryId is required (either on body or session)' };
        return;
      }

      // Validate category belongs to household
      const category = await ExpenseCategory.findOne({
        where: { id: Number(categoryId), householdId: session.householdId }
      });
      if (!category) {
        ctx.status = 400;
        ctx.body = { error: 'Invalid expenseCategoryId for this household' };
        return;
      }

      const expense = await createExpenseRecord({
        amount,
        dateTime: dateTime || new Date().toISOString(),
        description: description || session.name,
        note,
        paymentMethod: paymentMethod || 'card',
        cardId,
        expenseCategoryId: categoryId,
        householdId: session.householdId,
        appUserId: appUser.id,
        installmentTotal,
        installmentCurrent: installmentTotal ? 1 : null
      });

      await session.update({
        completedAt: new Date(),
        linkedExpenseId: expense.id,
        expenseCategoryId: categoryId
      });

      const io = getIO();
      if (io) {
        io.to(`household:${session.householdId}`).emit('shopping:completed', {
          sessionId: session.id,
          expenseId: expense.id,
          amount
        });
      }

      ctx.body = { success: true, expense: expense.toJSON(), session };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async attachToPlan(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;

      const session = await ShoppingSession.findByPk(id);
      if (!session) { ctx.status = 404; ctx.body = { error: 'Not found' }; return; }
      if (!await assertMember(session.householdId, appUser.id, ctx)) return;

      if (!session.expenseCategoryId || !session.plannedYear || !session.plannedMonth) {
        ctx.status = 400;
        ctx.body = { error: 'Session must have expenseCategoryId, plannedYear and plannedMonth set' };
        return;
      }

      const item = await upsertBudgetPlanItemForSession(session);
      if (!item) {
        ctx.status = 500;
        ctx.body = { error: 'Failed to create plan item' };
        return;
      }

      await session.update({ linkedBudgetPlanItemId: item.id });

      ctx.body = { success: true, budgetPlanItem: item, session };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async deleteSession(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;
      const session = await ShoppingSession.findByPk(id);
      if (!session) { ctx.status = 404; ctx.body = { error: 'Not found' }; return; }
      if (!await assertMember(session.householdId, appUser.id, ctx)) return;

      const householdId = session.householdId;
      await session.destroy();

      const io = getIO();
      if (io) {
        io.to(`household:${householdId}`).emit('shopping:deleted', Number(id));
      }

      ctx.body = { success: true };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async patchSessionItem(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id, itemId } = ctx.params;
      const { status, price, storeId, note, amount, unit } = ctx.request.body;

      const session = await ShoppingSession.findByPk(id);
      if (!session) { ctx.status = 404; ctx.body = { error: 'Session not found' }; return; }
      if (!await assertMember(session.householdId, appUser.id, ctx)) return;

      const sessionItem = await ShoppingSessionItem.findOne({ where: { id: itemId, sessionId: id } });
      if (!sessionItem) { ctx.status = 404; ctx.body = { error: 'Item not found' }; return; }

      const updates = {};
      if (status !== undefined) updates.status = status;
      if (price !== undefined) updates.price = price;
      if (storeId !== undefined) updates.storeId = storeId;
      if (note !== undefined) updates.note = note;
      if (amount !== undefined) updates.amount = amount;
      if (unit !== undefined) updates.unit = unit;
      await sessionItem.update(updates);

      const updated = await ShoppingSessionItem.findByPk(sessionItem.id, {
        include: [
          { model: ShoppingItem, as: 'item', include: [{ model: ShoppingCategory, as: 'category' }] },
          { model: ShoppingStore, as: 'store' }
        ]
      });

      const io = getIO();
      if (io) {
        io.to(`household:${session.householdId}`).emit('shopping:itemUpdated', { sessionId: id, item: updated });
      }

      ctx.body = { success: true, sessionItem: updated };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }

  async addSessionItem(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;
      const { itemId, amount, unit, extraData } = ctx.request.body;

      const session = await ShoppingSession.findByPk(id);
      if (!session) { ctx.status = 404; ctx.body = { error: 'Not found' }; return; }
      if (!await assertMember(session.householdId, appUser.id, ctx)) return;

      const count = await ShoppingSessionItem.count({ where: { sessionId: id } });
      const sessionItem = await ShoppingSessionItem.create({
        sessionId: id,
        itemId,
        amount: amount || 1,
        unit: unit || 'pcs',
        extraData: extraData || null,
        sortOrder: count
      });

      const withItem = await ShoppingSessionItem.findByPk(sessionItem.id, {
        include: [
          { model: ShoppingItem, as: 'item', include: [{ model: ShoppingCategory, as: 'category' }] },
          { model: ShoppingStore, as: 'store' }
        ]
      });

      ctx.status = 201;
      ctx.body = { success: true, sessionItem: withItem };
    } catch (e) {
      console.error(e);
      ctx.status = 500; ctx.body = { error: 'Failed' };
    }
  }
}

module.exports = new ShoppingController();
