const { RecurringExpense, ExpenseCategory, AppUser, HouseholdMember } = require('../models');

class RecurringExpensesController {
  /**
   * GET /app/recurring-expenses?householdId=X
   * List all recurring expenses for a household.
   */
  async list(ctx) {
    try {
      const { householdId } = ctx.request.query;
      if (!householdId) {
        ctx.status = 400;
        ctx.body = { error: 'householdId is required' };
        return;
      }

      const appUserId = ctx.state.appUser.id;
      const membership = await HouseholdMember.findOne({
        where: { householdId: Number(householdId), appUserId }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'You are not a member of this household' };
        return;
      }

      const recurring = await RecurringExpense.findAll({
        where: { householdId: Number(householdId) },
        include: [
          { model: ExpenseCategory, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] },
          { model: AppUser, attributes: ['id', 'username'] }
        ],
        order: [['createdAt', 'ASC']]
      });

      ctx.body = { success: true, recurringExpenses: recurring.map(r => r.toJSON()) };
    } catch (error) {
      console.error('RecurringExpenses list error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to fetch recurring expenses' };
    }
  }

  /**
   * POST /app/recurring-expenses
   * Create a new recurring expense.
   * Body: { amount, description, note, paymentMethod, expenseCategoryId, householdId,
   *         dayOfMonth, startYear, startMonth }
   */
  async create(ctx) {
    try {
      const {
        amount,
        description,
        note,
        paymentMethod,
        expenseCategoryId,
        householdId,
        dayOfMonth,
        startYear,
        startMonth
      } = ctx.request.body;

      if (!amount || !expenseCategoryId || !householdId || !startYear || !startMonth) {
        ctx.status = 400;
        ctx.body = { error: 'amount, expenseCategoryId, householdId, startYear, and startMonth are required' };
        return;
      }

      const appUserId = ctx.state.appUser.id;
      const membership = await HouseholdMember.findOne({
        where: { householdId: Number(householdId), appUserId }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'You are not a member of this household' };
        return;
      }

      const category = await ExpenseCategory.findOne({
        where: { id: Number(expenseCategoryId), householdId: Number(householdId) }
      });
      if (!category) {
        ctx.status = 400;
        ctx.body = { error: 'Invalid expenseCategoryId for this household' };
        return;
      }

      const day = dayOfMonth ? Math.min(Math.max(Number(dayOfMonth), 1), 28) : 10;

      const record = await RecurringExpense.create({
        amount,
        description: description || null,
        note: note || null,
        paymentMethod: paymentMethod || 'bank_transfer',
        expenseCategoryId: Number(expenseCategoryId),
        appUserId,
        householdId: Number(householdId),
        dayOfMonth: day,
        startYear: Number(startYear),
        startMonth: Number(startMonth),
        isActive: true
      });

      const created = await RecurringExpense.findByPk(record.id, {
        include: [
          { model: ExpenseCategory, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] },
          { model: AppUser, attributes: ['id', 'username'] }
        ]
      });

      ctx.status = 201;
      ctx.body = { success: true, recurringExpense: created.toJSON() };
    } catch (error) {
      console.error('RecurringExpenses create error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to create recurring expense' };
    }
  }

  /**
   * PUT /app/recurring-expenses/:id
   * Update a recurring expense.
   */
  async update(ctx) {
    try {
      const { id } = ctx.params;
      const appUserId = ctx.state.appUser.id;

      const record = await RecurringExpense.findByPk(id);
      if (!record) {
        ctx.status = 404;
        ctx.body = { error: 'Recurring expense not found' };
        return;
      }

      const membership = await HouseholdMember.findOne({
        where: { householdId: record.householdId, appUserId }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'You are not a member of this household' };
        return;
      }

      const {
        amount,
        description,
        note,
        paymentMethod,
        expenseCategoryId,
        dayOfMonth,
        startYear,
        startMonth,
        isActive
      } = ctx.request.body;

      if (expenseCategoryId) {
        const category = await ExpenseCategory.findOne({
          where: { id: Number(expenseCategoryId), householdId: record.householdId }
        });
        if (!category) {
          ctx.status = 400;
          ctx.body = { error: 'Invalid expenseCategoryId for this household' };
          return;
        }
      }

      await record.update({
        amount:            amount            !== undefined ? amount            : record.amount,
        description:       description       !== undefined ? (description || null)       : record.description,
        note:              note              !== undefined ? (note || null)              : record.note,
        paymentMethod:     paymentMethod     !== undefined ? paymentMethod     : record.paymentMethod,
        expenseCategoryId: expenseCategoryId !== undefined ? Number(expenseCategoryId) : record.expenseCategoryId,
        dayOfMonth:        dayOfMonth        !== undefined ? Math.min(Math.max(Number(dayOfMonth), 1), 28) : record.dayOfMonth,
        startYear:         startYear         !== undefined ? Number(startYear)         : record.startYear,
        startMonth:        startMonth        !== undefined ? Number(startMonth)        : record.startMonth,
        isActive:          isActive          !== undefined ? Boolean(isActive)         : record.isActive
      });

      const updated = await RecurringExpense.findByPk(record.id, {
        include: [
          { model: ExpenseCategory, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] },
          { model: AppUser, attributes: ['id', 'username'] }
        ]
      });

      ctx.body = { success: true, recurringExpense: updated.toJSON() };
    } catch (error) {
      console.error('RecurringExpenses update error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to update recurring expense' };
    }
  }

  /**
   * DELETE /app/recurring-expenses/:id
   */
  async delete(ctx) {
    try {
      const { id } = ctx.params;
      const appUserId = ctx.state.appUser.id;

      const record = await RecurringExpense.findByPk(id);
      if (!record) {
        ctx.status = 404;
        ctx.body = { error: 'Recurring expense not found' };
        return;
      }

      const membership = await HouseholdMember.findOne({
        where: { householdId: record.householdId, appUserId }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'You are not a member of this household' };
        return;
      }

      await record.destroy();
      ctx.body = { success: true };
    } catch (error) {
      console.error('RecurringExpenses delete error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to delete recurring expense' };
    }
  }
}

module.exports = new RecurringExpensesController();
