const { ExpenseCategory, CategoryBudgetOverride, Expense, RecurringExpense, Household, HouseholdMember, BudgetPlanItem, BudgetMonthConfig, sequelize } = require('../models');
const { Op, fn, col, literal } = require('sequelize');
const { getFinancialPeriodForAnchor } = require('../utils/financialCalendar');

async function getHouseholdStartDay(householdId) {
  const h = await Household.findByPk(householdId, { attributes: ['id', 'financialMonthStartDay'] });
  return h?.financialMonthStartDay ?? 10;
}

class BudgetsController {
  /**
   * App: GET /app/budget/month?householdId=X&year=Y&month=M
   * Returns all expense categories with budget and spending data for the calendar month.
   */
  async getMonthBudget(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { householdId, year, month } = ctx.query;

      if (!householdId || !year || !month) {
        ctx.status = 400;
        ctx.body = { error: 'householdId, year, and month are required' };
        return;
      }

      const membership = await HouseholdMember.findOne({
        where: { householdId, appUserId: appUser.id }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'Not a member of this household' };
        return;
      }

      const yearInt = parseInt(year, 10);
      const monthInt = parseInt(month, 10);

      const startDay = await getHouseholdStartDay(householdId);
      const period = getFinancialPeriodForAnchor(yearInt, monthInt, startDay);
      const monthStart = period.start;
      const monthEnd = period.end;

      const categories = await ExpenseCategory.findAll({
        where: { householdId },
        order: [['sortOrder', 'ASC']]
      });

      const overrides = await CategoryBudgetOverride.findAll({
        where: { householdId, year: yearInt, month: monthInt }
      });
      const overrideMap = {};
      for (const o of overrides) {
        overrideMap[o.expenseCategoryId] = o;
      }

      // Pre-fetch active recurring expenses for this household that apply to this month
      const allRecurring = await RecurringExpense.findAll({
        where: { householdId, isActive: true }
      });

      // Build a map of categoryId -> recurring total for this calendar month
      const recurringTotalByCategory = {};
      for (const rec of allRecurring) {
        // Check startYear/startMonth <= yearInt/monthInt
        if (rec.startYear > yearInt || (rec.startYear === yearInt && rec.startMonth > monthInt)) continue;
        const catId = rec.expenseCategoryId;
        recurringTotalByCategory[catId] = (recurringTotalByCategory[catId] || 0) + parseFloat(rec.amount);
      }

      const result = await Promise.all(categories.map(async (category) => {
        const spendRow = await Expense.findOne({
          attributes: [[fn('SUM', col('amount')), 'total']],
          where: {
            expenseCategoryId: category.id,
            dateTime: { [Op.between]: [monthStart, monthEnd] }
          },
          raw: true
        });

        const regularSpent  = parseFloat(spendRow.total) || 0;
        const recurringSpent = recurringTotalByCategory[category.id] || 0;
        const spent = regularSpent + recurringSpent;
        const override = overrideMap[category.id] || null;
        const baseBudget = category.monthlyBudget != null ? parseFloat(category.monthlyBudget) : null;
        const overrideAmount = override ? parseFloat(override.amount) : null;
        const effectiveBudget = overrideAmount !== null ? overrideAmount : baseBudget;
        const budgetResult = effectiveBudget !== null ? spent - effectiveBudget : null;

        return {
          id: category.id,
          name: category.name,
          nameHe: category.nameHe || null,
          icon: category.icon,
          color: category.color,
          parentCategoryId: category.parentCategoryId || null,
          baseBudget,
          override: overrideAmount,
          effectiveBudget,
          spent,
          result: budgetResult
        };
      }));

      ctx.body = { success: true, categories: result };
    } catch (error) {
      console.error('getMonthBudget error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to retrieve month budget' };
    }
  }

  /**
   * App: PUT /app/budget/base
   * Body: { expenseCategoryId, householdId, amount }
   * Sets the monthly base budget on the category itself (persists every month).
   */
  async setBaseBudget(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { expenseCategoryId, householdId, amount } = ctx.request.body;

      if (!expenseCategoryId || !householdId || amount === undefined || amount === null) {
        ctx.status = 400;
        ctx.body = { error: 'expenseCategoryId, householdId, and amount are required' };
        return;
      }

      const membership = await HouseholdMember.findOne({
        where: { householdId, appUserId: appUser.id }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'Not a member of this household' };
        return;
      }

      const category = await ExpenseCategory.findOne({
        where: { id: expenseCategoryId, householdId }
      });
      if (!category) {
        ctx.status = 404;
        ctx.body = { error: 'Category not found' };
        return;
      }

      await category.update({ monthlyBudget: amount >= 0 ? amount : null });

      ctx.body = { success: true };
    } catch (error) {
      console.error('setBaseBudget error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to set base budget' };
    }
  }

  /**
   * App: PUT /app/budget/override
   * Body: { expenseCategoryId, householdId, year, month, amount }
   * Upserts a CategoryBudgetOverride.
   */
  async setOverride(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { expenseCategoryId, householdId, year, month, amount } = ctx.request.body;

      if (!expenseCategoryId || !householdId || !year || !month || amount === undefined || amount === null) {
        ctx.status = 400;
        ctx.body = { error: 'expenseCategoryId, householdId, year, month, and amount are required' };
        return;
      }

      const membership = await HouseholdMember.findOne({
        where: { householdId, appUserId: appUser.id }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'Not a member of this household' };
        return;
      }

      const [override] = await CategoryBudgetOverride.upsert({
        expenseCategoryId,
        householdId,
        year,
        month,
        amount
      });

      ctx.body = { success: true, override };
    } catch (error) {
      console.error('setOverride error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to set budget override' };
    }
  }

  /**
   * App: GET /app/budget/by-week?householdId=X&year=Y&month=M[&expenseCategoryId=C]
   * Returns spending grouped by ISO week for the calendar month.
   */
  async getSpendingByWeek(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { householdId, year, month, expenseCategoryId } = ctx.query;

      if (!householdId || !year || !month) {
        ctx.status = 400;
        ctx.body = { error: 'householdId, year, and month are required' };
        return;
      }

      const membership = await HouseholdMember.findOne({
        where: { householdId, appUserId: appUser.id }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'Not a member of this household' };
        return;
      }

      const yearInt = parseInt(year, 10);
      const monthInt = parseInt(month, 10);

      const startDay = await getHouseholdStartDay(householdId);
      const period = getFinancialPeriodForAnchor(yearInt, monthInt, startDay);
      const monthStart = period.start;
      const monthEnd = period.end;

      const where = {
        householdId,
        dateTime: { [Op.between]: [monthStart, monthEnd] }
      };
      if (expenseCategoryId) {
        where.expenseCategoryId = expenseCategoryId;
      }

      const rows = await Expense.findAll({
        attributes: [
          [fn('WEEK', col('dateTime'), 3), 'isoWeek'],
          [fn('SUM', col('amount')), 'total']
        ],
        where,
        group: [fn('WEEK', col('dateTime'), 3)],
        order: [[fn('WEEK', col('dateTime'), 3), 'ASC']],
        raw: true
      });

      // Calculate week labels relative to the first ISO week of the month
      const firstWeek = rows.length > 0 ? parseInt(rows[0].isoWeek, 10) : null;
      const weeks = rows.map((row, idx) => ({
        weekLabel: `W${idx + 1}`,
        total: parseFloat(row.total) || 0
      }));

      ctx.body = { success: true, weeks };
    } catch (error) {
      console.error('getSpendingByWeek error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to retrieve spending by week' };
    }
  }

  /**
   * App: GET /app/budget/by-month?householdId=X&year=Y&startMonth=S&endMonth=E[&expenseCategoryId=C]
   * Returns spending grouped by month for a range.
   */
  async getSpendingByMonth(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { householdId, year, startMonth, endMonth, expenseCategoryId } = ctx.query;

      if (!householdId || !year || !startMonth || !endMonth) {
        ctx.status = 400;
        ctx.body = { error: 'householdId, year, startMonth, and endMonth are required' };
        return;
      }

      const membership = await HouseholdMember.findOne({
        where: { householdId, appUserId: appUser.id }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'Not a member of this household' };
        return;
      }

      const yearInt = parseInt(year, 10);
      const startMonthInt = parseInt(startMonth, 10);
      const endMonthInt = parseInt(endMonth, 10);

      const startDay = await getHouseholdStartDay(householdId);

      // Build the list of financial period anchors covering startMonth..endMonth.
      // Anchors may straddle a year boundary when startMonth > endMonth.
      const anchors = [];
      let curYear = yearInt;
      let curMonth = startMonthInt;
      while (true) {
        anchors.push({ year: curYear, month: curMonth });
        if (curYear === yearInt && curMonth === endMonthInt) break;
        curMonth += 1;
        if (curMonth > 12) { curMonth = 1; curYear += 1; }
        if (anchors.length > 36) break; // safety
      }

      const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

      const months = await Promise.all(anchors.map(async ({ year: yr, month: mo }) => {
        const period = getFinancialPeriodForAnchor(yr, mo, startDay);
        const where = {
          householdId,
          dateTime: { [Op.between]: [period.start, period.end] }
        };
        if (expenseCategoryId) {
          where.expenseCategoryId = expenseCategoryId;
        }
        const row = await Expense.findOne({
          attributes: [[fn('SUM', col('amount')), 'total']],
          where,
          raw: true
        });
        return {
          label: `${monthNames[mo - 1]} ${yr}`,
          total: parseFloat(row?.total) || 0
        };
      }));

      ctx.body = { success: true, months };
    } catch (error) {
      console.error('getSpendingByMonth error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to retrieve spending by month' };
    }
  }
  // ── Budget Plan Items ───────────────────────────────────────────────────────

  /**
   * GET /app/budget/plan-items?householdId=X&year=Y&month=M
   */
  async getPlanItems(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { householdId, year, month } = ctx.query;
      if (!householdId || !year || !month) {
        ctx.status = 400; ctx.body = { error: 'householdId, year, month required' }; return;
      }
      const membership = await HouseholdMember.findOne({ where: { householdId, appUserId: appUser.id } });
      if (!membership) { ctx.status = 403; ctx.body = { error: 'Not a member' }; return; }

      const items = await BudgetPlanItem.findAll({
        where: { householdId, year: parseInt(year), month: parseInt(month) },
        order: [['createdAt', 'ASC']]
      });
      ctx.body = { success: true, items };
    } catch (err) {
      console.error('getPlanItems error:', err);
      ctx.status = 500; ctx.body = { error: 'Failed to get plan items' };
    }
  }

  /**
   * POST /app/budget/plan-items
   * Body: { householdId, expenseCategoryId, year, month, description, amount }
   */
  async createPlanItem(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { householdId, expenseCategoryId, year, month, description, minAmount, maxAmount } = ctx.request.body;
      if (!householdId || !expenseCategoryId || !year || !month) {
        ctx.status = 400; ctx.body = { error: 'householdId, expenseCategoryId, year, month required' }; return;
      }
      const membership = await HouseholdMember.findOne({ where: { householdId, appUserId: appUser.id } });
      if (!membership) { ctx.status = 403; ctx.body = { error: 'Not a member' }; return; }

      const item = await BudgetPlanItem.create({
        householdId, expenseCategoryId, year, month,
        description: description || null,
        minAmount: parseFloat(minAmount) || 0,
        maxAmount: parseFloat(maxAmount) || 0
      });
      ctx.status = 201;
      ctx.body = { success: true, item };
    } catch (err) {
      console.error('createPlanItem error:', err);
      ctx.status = 500; ctx.body = { error: 'Failed to create plan item' };
    }
  }

  /**
   * PUT /app/budget/plan-items/:id
   * Body: { description, amount }
   */
  async updatePlanItem(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;
      const { description, minAmount, maxAmount } = ctx.request.body;

      const item = await BudgetPlanItem.findByPk(id);
      if (!item) { ctx.status = 404; ctx.body = { error: 'Item not found' }; return; }

      const membership = await HouseholdMember.findOne({ where: { householdId: item.householdId, appUserId: appUser.id } });
      if (!membership) { ctx.status = 403; ctx.body = { error: 'Not a member' }; return; }

      await item.update({
        description: description !== undefined ? (description || null) : item.description,
        minAmount: minAmount !== undefined ? (parseFloat(minAmount) || 0) : item.minAmount,
        maxAmount: maxAmount !== undefined ? (parseFloat(maxAmount) || 0) : item.maxAmount
      });
      ctx.body = { success: true, item };
    } catch (err) {
      console.error('updatePlanItem error:', err);
      ctx.status = 500; ctx.body = { error: 'Failed to update plan item' };
    }
  }

  /**
   * DELETE /app/budget/plan-items/:id
   */
  async deletePlanItem(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;

      const item = await BudgetPlanItem.findByPk(id);
      if (!item) { ctx.status = 404; ctx.body = { error: 'Item not found' }; return; }

      const membership = await HouseholdMember.findOne({ where: { householdId: item.householdId, appUserId: appUser.id } });
      if (!membership) { ctx.status = 403; ctx.body = { error: 'Not a member' }; return; }

      await item.destroy();
      ctx.body = { success: true };
    } catch (err) {
      console.error('deletePlanItem error:', err);
      ctx.status = 500; ctx.body = { error: 'Failed to delete plan item' };
    }
  }

  // ── Budget Month Config ─────────────────────────────────────────────────────

  /**
   * GET /app/budget/month-config?householdId=X&year=Y&month=M
   */
  async getMonthConfig(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { householdId, year, month } = ctx.query;
      if (!householdId || !year || !month) {
        ctx.status = 400; ctx.body = { error: 'householdId, year, month required' }; return;
      }
      const membership = await HouseholdMember.findOne({ where: { householdId, appUserId: appUser.id } });
      if (!membership) { ctx.status = 403; ctx.body = { error: 'Not a member' }; return; }

      const config = await BudgetMonthConfig.findOne({
        where: { householdId, year: parseInt(year), month: parseInt(month) }
      });
      ctx.body = { success: true, config: config || null };
    } catch (err) {
      console.error('getMonthConfig error:', err);
      ctx.status = 500; ctx.body = { error: 'Failed to get month config' };
    }
  }

  /**
   * PUT /app/budget/month-config
   * Body: { householdId, year, month, startAmount }
   */
  async upsertMonthConfig(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { householdId, year, month, startAmount, expectedIncome } = ctx.request.body;
      if (!householdId || !year || !month) {
        ctx.status = 400; ctx.body = { error: 'householdId, year, month required' }; return;
      }
      const membership = await HouseholdMember.findOne({ where: { householdId, appUserId: appUser.id } });
      if (!membership) { ctx.status = 403; ctx.body = { error: 'Not a member' }; return; }

      const [config] = await BudgetMonthConfig.upsert({
        householdId, year, month,
        startAmount: startAmount !== undefined ? (parseFloat(startAmount) || null) : null,
        expectedIncome: expectedIncome !== undefined ? (parseFloat(expectedIncome) || null) : null
      });
      ctx.body = { success: true, config };
    } catch (err) {
      console.error('upsertMonthConfig error:', err);
      ctx.status = 500; ctx.body = { error: 'Failed to save month config' };
    }
  }
}

module.exports = new BudgetsController();
