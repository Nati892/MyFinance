const { Op } = require('sequelize');
const { ExpenseSchedule, ExpenseCategory, AppUser, HouseholdMember, Expense } = require('../models');

class ExpenseSchedulesController {
  /**
   * GET /app/expense-schedules?householdId=X
   * List all expense schedules for a household.
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

      const schedules = await ExpenseSchedule.findAll({
        where: { householdId: Number(householdId) },
        include: [
          { model: ExpenseCategory, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] },
          { model: AppUser, attributes: ['id', 'username'] }
        ],
        order: [['createdAt', 'ASC']]
      });

      ctx.body = { success: true, expenseSchedules: schedules.map(s => s.toJSON()) };
    } catch (error) {
      console.error('ExpenseSchedules list error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to fetch expense schedules' };
    }
  }

  /**
   * GET /app/expense-schedules/today-suggestions?householdId=X
   * Returns schedules that match today's weekday and haven't been logged today.
   */
  async todaySuggestions(ctx) {
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

      // Today's weekday: 0=Sun, 1=Mon, ..., 6=Sat
      const todayDow = new Date().getDay();

      const allSchedules = await ExpenseSchedule.findAll({
        where: { householdId: Number(householdId), isActive: true },
        include: [
          { model: ExpenseCategory, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] },
          { model: AppUser, attributes: ['id', 'username'] }
        ]
      });

      // Filter to schedules where today's weekday is in daysOfWeek
      const todaySchedules = allSchedules.filter(s => {
        const days = Array.isArray(s.daysOfWeek) ? s.daysOfWeek : JSON.parse(s.daysOfWeek);
        return days.includes(todayDow);
      });

      if (todaySchedules.length === 0) {
        ctx.body = { success: true, suggestions: [] };
        return;
      }

      // Get today's expenses for this household
      const startOfDay = new Date();
      startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date();
      endOfDay.setHours(23, 59, 59, 999);

      const todayExpenses = await Expense.findAll({
        where: {
          householdId: Number(householdId),
          dateTime: { [Op.between]: [startOfDay, endOfDay] }
        }
      });

      // A schedule is a suggestion if no today-expense matches (same category + same description)
      const suggestions = todaySchedules.filter(schedule => {
        return !todayExpenses.some(expense => {
          const categoryMatch = expense.expenseCategoryId === schedule.expenseCategoryId;
          const descriptionMatch = expense.description === schedule.description;
          return categoryMatch && descriptionMatch;
        });
      });

      ctx.body = { success: true, suggestions: suggestions.map(s => s.toJSON()) };
    } catch (error) {
      console.error('ExpenseSchedules todaySuggestions error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to fetch today suggestions' };
    }
  }

  /**
   * POST /app/expense-schedules
   * Create a new expense schedule.
   * Body: { description, expenseCategoryId, householdId, daysOfWeek,
   *         amount?, paymentMethod?, note?, isActive? }
   */
  async create(ctx) {
    try {
      const {
        description,
        expenseCategoryId,
        householdId,
        daysOfWeek,
        amount,
        paymentMethod,
        note,
        isActive
      } = ctx.request.body;

      if (!description || !expenseCategoryId || !householdId || !daysOfWeek) {
        ctx.status = 400;
        ctx.body = { error: 'description, expenseCategoryId, householdId, and daysOfWeek are required' };
        return;
      }

      if (!Array.isArray(daysOfWeek) || daysOfWeek.length === 0) {
        ctx.status = 400;
        ctx.body = { error: 'daysOfWeek must be a non-empty array of weekday numbers (0–6)' };
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

      const record = await ExpenseSchedule.create({
        description,
        expenseCategoryId: Number(expenseCategoryId),
        appUserId,
        householdId: Number(householdId),
        daysOfWeek: daysOfWeek.map(Number).filter(d => d >= 0 && d <= 6),
        amount: amount != null ? Number(amount) : null,
        paymentMethod: paymentMethod || null,
        note: note || null,
        isActive: isActive !== undefined ? Boolean(isActive) : true
      });

      const created = await ExpenseSchedule.findByPk(record.id, {
        include: [
          { model: ExpenseCategory, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] },
          { model: AppUser, attributes: ['id', 'username'] }
        ]
      });

      ctx.status = 201;
      ctx.body = { success: true, expenseSchedule: created.toJSON() };
    } catch (error) {
      console.error('ExpenseSchedules create error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to create expense schedule' };
    }
  }

  /**
   * PUT /app/expense-schedules/:id
   * Update an expense schedule.
   */
  async update(ctx) {
    try {
      const { id } = ctx.params;
      const appUserId = ctx.state.appUser.id;

      const record = await ExpenseSchedule.findByPk(id);
      if (!record) {
        ctx.status = 404;
        ctx.body = { error: 'Expense schedule not found' };
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
        description,
        expenseCategoryId,
        daysOfWeek,
        amount,
        paymentMethod,
        note,
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

      if (daysOfWeek !== undefined && (!Array.isArray(daysOfWeek) || daysOfWeek.length === 0)) {
        ctx.status = 400;
        ctx.body = { error: 'daysOfWeek must be a non-empty array of weekday numbers (0–6)' };
        return;
      }

      await record.update({
        description:       description       !== undefined ? description       : record.description,
        expenseCategoryId: expenseCategoryId !== undefined ? Number(expenseCategoryId) : record.expenseCategoryId,
        daysOfWeek:        daysOfWeek        !== undefined ? daysOfWeek.map(Number).filter(d => d >= 0 && d <= 6) : record.daysOfWeek,
        amount:            amount            !== undefined ? (amount != null ? Number(amount) : null) : record.amount,
        paymentMethod:     paymentMethod     !== undefined ? (paymentMethod || null) : record.paymentMethod,
        note:              note              !== undefined ? (note || null) : record.note,
        isActive:          isActive          !== undefined ? Boolean(isActive) : record.isActive
      });

      const updated = await ExpenseSchedule.findByPk(record.id, {
        include: [
          { model: ExpenseCategory, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] },
          { model: AppUser, attributes: ['id', 'username'] }
        ]
      });

      ctx.body = { success: true, expenseSchedule: updated.toJSON() };
    } catch (error) {
      console.error('ExpenseSchedules update error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to update expense schedule' };
    }
  }

  /**
   * DELETE /app/expense-schedules/:id
   */
  async delete(ctx) {
    try {
      const { id } = ctx.params;
      const appUserId = ctx.state.appUser.id;

      const record = await ExpenseSchedule.findByPk(id);
      if (!record) {
        ctx.status = 404;
        ctx.body = { error: 'Expense schedule not found' };
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
      console.error('ExpenseSchedules delete error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to delete expense schedule' };
    }
  }
}

module.exports = new ExpenseSchedulesController();
