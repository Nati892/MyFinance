const { Expense, Income, ExpenseCategory, IncomeCategory, HouseholdMember } = require('../models');
const {
  getCurrentFinancialPeriod,
  getFinancialPeriod,
  getFinancialWeeks,
  getHourlySlots,
  getDailySlots
} = require('../utils/financialCalendar');

class ExpensesController {
  /**
   * GET /api/app/expenses
   * List expenses for a household with financial-calendar scoping.
   *
   * Query params:
   *   householdId   (required)
   *   view          'hourly' | 'daily' | 'weekly' | 'monthly'  (default 'monthly')
   *   periodOffset  integer  (default 0)
   *   weekNumber    1-5  (required for hourly / daily views)
   *   date          ISO string  (required for hourly view)
   *   categoryId    optional filter
   */
  async list(ctx) {
    try {
      const {
        householdId,
        view          = 'monthly',
        periodOffset  = 0,
        weekNumber,
        date,
        categoryId
      } = ctx.request.query;

      // --- Validate householdId ---
      if (!householdId) {
        ctx.status = 400;
        ctx.body   = { error: 'householdId is required' };
        return;
      }

      // --- Verify user is a member of the household ---
      const appUserId  = ctx.state.appUser.id;
      const membership = await HouseholdMember.findOne({
        where: { householdId: Number(householdId), appUserId }
      });

      if (!membership) {
        ctx.status = 403;
        ctx.body   = { error: 'You are not a member of this household' };
        return;
      }

      // --- Resolve the financial period ---
      const offset = parseInt(periodOffset, 10) || 0;
      const period = getFinancialPeriod(offset);
      const weeks  = getFinancialWeeks(period);

      // --- Build date range based on view ---
      let dateStart = period.start;
      let dateEnd   = period.end;
      let slots     = null;

      if (view === 'weekly') {
        const wn = parseInt(weekNumber, 10);
        if (!wn || wn < 1 || wn > 5) {
          ctx.status = 400;
          ctx.body   = { error: 'weekNumber (1-5) is required for weekly view' };
          return;
        }
        const week = weeks.find(w => w.weekNumber === wn);
        if (!week || !week.start) {
          ctx.status = 400;
          ctx.body   = { error: `Week ${wn} does not exist in this period` };
          return;
        }
        dateStart = week.start;
        dateEnd   = week.end;

      } else if (view === 'daily') {
        const wn = parseInt(weekNumber, 10);
        if (!wn || wn < 1 || wn > 5) {
          ctx.status = 400;
          ctx.body   = { error: 'weekNumber (1-5) is required for daily view' };
          return;
        }
        const week = weeks.find(w => w.weekNumber === wn);
        if (!week || !week.start) {
          ctx.status = 400;
          ctx.body   = { error: `Week ${wn} does not exist in this period` };
          return;
        }
        dateStart = week.start;
        dateEnd   = week.end;
        slots     = getDailySlots(week);

      } else if (view === 'hourly') {
        if (!date) {
          ctx.status = 400;
          ctx.body   = { error: 'date is required for hourly view' };
          return;
        }
        const targetDate = new Date(date);
        if (isNaN(targetDate.getTime())) {
          ctx.status = 400;
          ctx.body   = { error: 'date is not a valid ISO date string' };
          return;
        }
        dateStart = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 0, 0, 0, 0);
        dateEnd   = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 23, 59, 59, 999);
        slots     = getHourlySlots(targetDate);
      }

      // --- Build where clause ---
      const where = {
        householdId: Number(householdId),
        dateTime: {
          [global.db.Sequelize.Op.between]: [dateStart, dateEnd]
        }
      };

      if (categoryId) {
        where.expenseCategoryId = Number(categoryId);
      }

      // --- Fetch expenses ---
      const expenses = await Expense.findAll({
        where,
        include: [
          {
            model:      global.db.models.ExpenseCategory,
            attributes: ['id', 'name', 'icon', 'color']
          },
          {
            model:      global.db.models.AppUser,
            attributes: ['id', 'username']
          }
        ],
        order: [['dateTime', 'DESC']]
      });

      // --- Compute total ---
      const totalAmount = expenses.reduce((sum, e) => sum + parseFloat(e.amount), 0);

      // --- Build response ---
      const response = {
        success:     true,
        expenses:    expenses.map(e => e.toJSON()),
        period:      { start: period.start, end: period.end, label: period.label },
        totalAmount: Math.round(totalAmount * 100) / 100
      };

      if (view === 'monthly' || view === 'weekly') {
        response.weeks = weeks;
      }

      if (slots) {
        response.slots = slots;
      }

      ctx.body = response;

    } catch (error) {
      console.error('Expenses list error:', error);
      ctx.status = 500;
      ctx.body   = { error: 'Failed to fetch expenses' };
    }
  }

  /**
   * POST /api/app/expenses
   * Create a new expense transaction.
   *
   * Body: { amount, dateTime, description, note, paymentMethod, expenseCategoryId, householdId }
   */
  async create(ctx) {
    try {
      const {
        amount,
        dateTime,
        description,
        note,
        paymentMethod,
        expenseCategoryId,
        householdId
      } = ctx.request.body;

      // --- Required fields ---
      if (!amount || !dateTime || !expenseCategoryId || !householdId) {
        ctx.status = 400;
        ctx.body   = { error: 'amount, dateTime, expenseCategoryId, and householdId are required' };
        return;
      }

      // --- Verify user is a member of the household ---
      const appUserId  = ctx.state.appUser.id;
      const membership = await HouseholdMember.findOne({
        where: { householdId: Number(householdId), appUserId }
      });

      if (!membership) {
        ctx.status = 403;
        ctx.body   = { error: 'You are not a member of this household' };
        return;
      }

      // --- Validate category belongs to household ---
      const category = await global.db.models.ExpenseCategory.findOne({
        where: { id: Number(expenseCategoryId), householdId: Number(householdId) }
      });

      if (!category) {
        ctx.status = 400;
        ctx.body   = { error: 'Invalid expenseCategoryId for this household' };
        return;
      }

      // --- Create ---
      const expense = await Expense.create({
        amount,
        dateTime,
        description: description || null,
        note:        note        || null,
        paymentMethod,
        expenseCategoryId: Number(expenseCategoryId),
        appUserId,
        householdId: Number(householdId)
      });

      // --- Reload with includes ---
      const created = await Expense.findByPk(expense.id, {
        include: [
          {
            model:      global.db.models.ExpenseCategory,
            attributes: ['id', 'name', 'icon', 'color']
          },
          {
            model:      global.db.models.AppUser,
            attributes: ['id', 'username']
          }
        ]
      });

      ctx.status = 201;
      ctx.body   = { success: true, expense: created.toJSON() };

    } catch (error) {
      console.error('Expenses create error:', error);
      ctx.status = 500;
      ctx.body   = { error: 'Failed to create expense' };
    }
  }

  /**
   * PUT /api/app/expenses/:id
   * Update an existing expense (only the creator can update).
   *
   * Body: { amount, dateTime, description, note, paymentMethod, expenseCategoryId }
   */
  async update(ctx) {
    try {
      const { id }   = ctx.params;
      const appUserId = ctx.state.appUser.id;

      const expense = await Expense.findByPk(id);

      if (!expense) {
        ctx.status = 404;
        ctx.body   = { error: 'Expense not found' };
        return;
      }

      if (expense.appUserId !== appUserId) {
        ctx.status = 403;
        ctx.body   = { error: 'You can only update your own expenses' };
        return;
      }

      const {
        amount,
        dateTime,
        description,
        note,
        paymentMethod,
        expenseCategoryId
      } = ctx.request.body;

      // --- Validate new category if provided ---
      if (expenseCategoryId) {
        const category = await global.db.models.ExpenseCategory.findOne({
          where: { id: Number(expenseCategoryId), householdId: expense.householdId }
        });

        if (!category) {
          ctx.status = 400;
          ctx.body   = { error: 'Invalid expenseCategoryId for this household' };
          return;
        }
      }

      // --- Apply updates ---
      await expense.update({
        amount:            amount            !== undefined ? amount            : expense.amount,
        dateTime:          dateTime          !== undefined ? dateTime          : expense.dateTime,
        description:       description       !== undefined ? description       : expense.description,
        note:              note              !== undefined ? note              : expense.note,
        paymentMethod:     paymentMethod     !== undefined ? paymentMethod     : expense.paymentMethod,
        expenseCategoryId: expenseCategoryId !== undefined ? Number(expenseCategoryId) : expense.expenseCategoryId
      });

      // --- Reload with includes ---
      const updated = await Expense.findByPk(expense.id, {
        include: [
          {
            model:      global.db.models.ExpenseCategory,
            attributes: ['id', 'name', 'icon', 'color']
          },
          {
            model:      global.db.models.AppUser,
            attributes: ['id', 'username']
          }
        ]
      });

      ctx.body = { success: true, expense: updated.toJSON() };

    } catch (error) {
      console.error('Expenses update error:', error);
      ctx.status = 500;
      ctx.body   = { error: 'Failed to update expense' };
    }
  }

  /**
   * DELETE /api/app/expenses/:id
   * Delete an expense (only the creator can delete).
   */
  async delete(ctx) {
    try {
      const { id }    = ctx.params;
      const appUserId  = ctx.state.appUser.id;

      const expense = await Expense.findByPk(id);

      if (!expense) {
        ctx.status = 404;
        ctx.body   = { error: 'Expense not found' };
        return;
      }

      if (expense.appUserId !== appUserId) {
        ctx.status = 403;
        ctx.body   = { error: 'You can only delete your own expenses' };
        return;
      }

      await expense.destroy();

      ctx.body = { success: true };

    } catch (error) {
      console.error('Expenses delete error:', error);
      ctx.status = 500;
      ctx.body   = { error: 'Failed to delete expense' };
    }
  }
}

module.exports = new ExpensesController();
