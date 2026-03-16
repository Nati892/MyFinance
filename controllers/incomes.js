const { Income, IncomeCategory, AppUser, HouseholdMember, sequelize } = require('../models');
const { Op } = require('sequelize');
const {
  getCurrentFinancialPeriod,
  getFinancialPeriod,
  getFinancialWeeks,
  getHourlySlots,
  getDailySlots
} = require('../utils/financialCalendar');

class IncomesController {
  /**
   * GET /api/app/incomes
   * List incomes for a household with financial-calendar scoping.
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
        // Use the full financial period; no weekNumber required for this view
        // dateStart and dateEnd already set to period.start / period.end

      } else if (view === 'daily') {
        if (!date) {
          ctx.status = 400;
          ctx.body   = { error: 'date is required for daily view' };
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
          [Op.between]: [dateStart, dateEnd]
        }
      };

      if (categoryId) {
        where.incomeCategoryId = Number(categoryId);
      }

      // --- Fetch incomes ---
      const incomes = await Income.findAll({
        where,
        include: [
          {
            model:      IncomeCategory,
            attributes: ['id', 'name', 'nameHe', 'icon', 'color']
          },
          {
            model:      AppUser,
            attributes: ['id', 'username']
          }
        ],
        order: [['dateTime', 'DESC']]
      });

      // --- Compute total ---
      const totalAmount = incomes.reduce((sum, i) => sum + parseFloat(i.amount), 0);

      // --- Build response ---
      const response = {
        success:     true,
        incomes:     incomes.map(i => i.toJSON()),
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
      console.error('Incomes list error:', error);
      ctx.status = 500;
      ctx.body   = { error: 'Failed to fetch incomes' };
    }
  }

  /**
   * POST /api/app/incomes
   * Create a new income transaction.
   *
   * Body: { amount, dateTime, description, note, paymentMethod, incomeCategoryId, householdId }
   */
  async create(ctx) {
    try {
      const {
        amount,
        dateTime,
        description,
        note,
        paymentMethod,
        incomeCategoryId,
        householdId
      } = ctx.request.body;

      // --- Required fields ---
      if (!amount || !dateTime || !incomeCategoryId || !householdId) {
        ctx.status = 400;
        ctx.body   = { error: 'amount, dateTime, incomeCategoryId, and householdId are required' };
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
      const category = await IncomeCategory.findOne({
        where: { id: Number(incomeCategoryId), householdId: Number(householdId) }
      });

      if (!category) {
        ctx.status = 400;
        ctx.body   = { error: 'Invalid incomeCategoryId for this household' };
        return;
      }

      // --- Create ---
      const income = await Income.create({
        amount,
        dateTime,
        description: description || null,
        note:        note        || null,
        paymentMethod,
        incomeCategoryId: Number(incomeCategoryId),
        appUserId,
        householdId: Number(householdId)
      });

      // --- Reload with includes ---
      const created = await Income.findByPk(income.id, {
        include: [
          {
            model:      IncomeCategory,
            attributes: ['id', 'name', 'nameHe', 'icon', 'color']
          },
          {
            model:      AppUser,
            attributes: ['id', 'username']
          }
        ]
      });

      ctx.status = 201;
      ctx.body   = { success: true, income: created.toJSON() };

    } catch (error) {
      console.error('Incomes create error:', error);
      ctx.status = 500;
      ctx.body   = { error: 'Failed to create income' };
    }
  }

  /**
   * PUT /api/app/incomes/:id
   * Update an existing income (only the creator can update).
   *
   * Body: { amount, dateTime, description, note, paymentMethod, incomeCategoryId }
   */
  async update(ctx) {
    try {
      const { id }    = ctx.params;
      const appUserId  = ctx.state.appUser.id;

      const income = await Income.findByPk(id);

      if (!income) {
        ctx.status = 404;
        ctx.body   = { error: 'Income not found' };
        return;
      }

      if (income.appUserId !== appUserId) {
        ctx.status = 403;
        ctx.body   = { error: 'You can only update your own incomes' };
        return;
      }

      const {
        amount,
        dateTime,
        description,
        note,
        paymentMethod,
        incomeCategoryId
      } = ctx.request.body;

      // --- Validate new category if provided ---
      if (incomeCategoryId) {
        const category = await IncomeCategory.findOne({
          where: { id: Number(incomeCategoryId), householdId: income.householdId }
        });

        if (!category) {
          ctx.status = 400;
          ctx.body   = { error: 'Invalid incomeCategoryId for this household' };
          return;
        }
      }

      // --- Apply updates ---
      await income.update({
        amount:           amount           !== undefined ? amount           : income.amount,
        dateTime:         dateTime         !== undefined ? dateTime         : income.dateTime,
        description:      description      !== undefined ? description      : income.description,
        note:             note             !== undefined ? note             : income.note,
        paymentMethod:    paymentMethod    !== undefined ? paymentMethod    : income.paymentMethod,
        incomeCategoryId: incomeCategoryId !== undefined ? Number(incomeCategoryId) : income.incomeCategoryId
      });

      // --- Reload with includes ---
      const updated = await Income.findByPk(income.id, {
        include: [
          {
            model:      IncomeCategory,
            attributes: ['id', 'name', 'nameHe', 'icon', 'color']
          },
          {
            model:      AppUser,
            attributes: ['id', 'username']
          }
        ]
      });

      ctx.body = { success: true, income: updated.toJSON() };

    } catch (error) {
      console.error('Incomes update error:', error);
      ctx.status = 500;
      ctx.body   = { error: 'Failed to update income' };
    }
  }

  /**
   * DELETE /api/app/incomes/:id
   * Delete an income (only the creator can delete).
   */
  async delete(ctx) {
    try {
      const { id }    = ctx.params;
      const appUserId  = ctx.state.appUser.id;

      const income = await Income.findByPk(id);

      if (!income) {
        ctx.status = 404;
        ctx.body   = { error: 'Income not found' };
        return;
      }

      if (income.appUserId !== appUserId) {
        ctx.status = 403;
        ctx.body   = { error: 'You can only delete your own incomes' };
        return;
      }

      await income.destroy();

      ctx.body = { success: true };

    } catch (error) {
      console.error('Incomes delete error:', error);
      ctx.status = 500;
      ctx.body   = { error: 'Failed to delete income' };
    }
  }
}

module.exports = new IncomesController();
