const { ExpenseCategory, Expense, Household, HouseholdMember, sequelize } = require('../models');
const { Op } = require('sequelize');

/**
 * Returns the start and end Date objects for the current financial month.
 * Financial month runs from the 10th of one month to the 9th of the next.
 * If today >= 10: start = this month's 10th 00:00:00, end = next month's 9th 23:59:59
 * If today < 10:  start = last month's 10th 00:00:00, end = this month's 9th 23:59:59
 */
function getCurrentFinancialPeriod() {
  const now = new Date();
  const day = now.getDate();
  const year = now.getFullYear();
  const month = now.getMonth(); // 0-indexed

  let start, end;

  if (day >= 10) {
    // Start: 10th of this month
    start = new Date(year, month, 10, 0, 0, 0, 0);
    // End: 9th of next month
    end = new Date(year, month + 1, 9, 23, 59, 59, 999);
  } else {
    // Start: 10th of last month
    start = new Date(year, month - 1, 10, 0, 0, 0, 0);
    // End: 9th of this month
    end = new Date(year, month, 9, 23, 59, 59, 999);
  }

  return { start, end };
}

class ExpenseCategoriesController {
  /**
   * Admin: GET all expense categories for a given householdId (query param)
   * Ordered by sortOrder, includes Household name
   */
  async adminList(ctx) {
    try {
      const { householdId } = ctx.query;

      if (!householdId) {
        ctx.status = 400;
        ctx.body = { error: 'householdId query parameter is required' };
        return;
      }

      const categories = await ExpenseCategory.findAll({
        where: { householdId },
        include: [
          {
            model: Household,
            attributes: ['id', 'name']
          }
        ],
        order: [['sortOrder', 'ASC']]
      });

      ctx.body = {
        success: true,
        categories
      };
    } catch (error) {
      console.error('Admin list expense categories error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to retrieve expense categories' };
    }
  }

  /**
   * Admin: POST create a new expense category
   * Body: { name, icon, color, sortOrder, monthlyBudget, householdId }
   */
  async adminCreate(ctx) {
    try {
      const { name, icon, color, sortOrder, monthlyBudget, householdId } = ctx.request.body;

      if (!name || !icon || !householdId) {
        ctx.status = 400;
        ctx.body = { error: 'name, icon, and householdId are required' };
        return;
      }

      const household = await Household.findByPk(householdId);
      if (!household) {
        ctx.status = 404;
        ctx.body = { error: 'Household not found' };
        return;
      }

      const category = await ExpenseCategory.create({
        name,
        icon,
        color,
        sortOrder,
        monthlyBudget,
        householdId
      });

      ctx.status = 201;
      ctx.body = {
        success: true,
        category
      };
    } catch (error) {
      console.error('Admin create expense category error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to create expense category' };
    }
  }

  /**
   * Admin: PUT /:id update an expense category
   * Body: { name, icon, color, sortOrder, monthlyBudget }
   */
  async adminUpdate(ctx) {
    try {
      const { id } = ctx.params;
      const { name, icon, color, sortOrder, monthlyBudget } = ctx.request.body;

      const category = await ExpenseCategory.findByPk(id);
      if (!category) {
        ctx.status = 404;
        ctx.body = { error: 'Expense category not found' };
        return;
      }

      await category.update({ name, icon, color, sortOrder, monthlyBudget });

      ctx.body = {
        success: true,
        category
      };
    } catch (error) {
      console.error('Admin update expense category error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to update expense category' };
    }
  }

  /**
   * Admin: DELETE /:id delete an expense category
   */
  async adminDelete(ctx) {
    try {
      const { id } = ctx.params;

      const category = await ExpenseCategory.findByPk(id);
      if (!category) {
        ctx.status = 404;
        ctx.body = { error: 'Expense category not found' };
        return;
      }

      await category.destroy();

      ctx.body = { success: true };
    } catch (error) {
      console.error('Admin delete expense category error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to delete expense category' };
    }
  }

  /**
   * Admin: PUT /reorder bulk update sortOrder
   * Body: { items: [{id, sortOrder}] }
   */
  async adminReorder(ctx) {
    try {
      const { items } = ctx.request.body;

      if (!items || !Array.isArray(items)) {
        ctx.status = 400;
        ctx.body = { error: 'items array is required' };
        return;
      }

      await sequelize.transaction(async (t) => {
        for (const item of items) {
          await ExpenseCategory.update(
            { sortOrder: item.sortOrder },
            { where: { id: item.id }, transaction: t }
          );
        }
      });

      ctx.body = { success: true };
    } catch (error) {
      console.error('Admin reorder expense categories error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to reorder expense categories' };
    }
  }

  /**
   * App: GET expense categories for a household with budget progress
   * Query: householdId
   * Validates that the current app user is a member of the household
   */
  async appList(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { householdId } = ctx.query;

      if (!householdId) {
        ctx.status = 400;
        ctx.body = { error: 'householdId query parameter is required' };
        return;
      }

      // Validate that the app user is a member of the requested household
      const membership = await HouseholdMember.findOne({
        where: { householdId, appUserId: appUser.id }
      });

      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'You are not a member of this household' };
        return;
      }

      const categories = await ExpenseCategory.findAll({
        where: { householdId },
        order: [['sortOrder', 'ASC']]
      });

      const { start, end } = getCurrentFinancialPeriod();

      // Calculate current spend per category for the financial month
      const categoriesWithBudget = await Promise.all(
        categories.map(async (category) => {
          const result = await Expense.findOne({
            attributes: [
              [sequelize.fn('SUM', sequelize.col('amount')), 'totalSpend']
            ],
            where: {
              expenseCategoryId: category.id,
              dateTime: {
                [Op.between]: [start, end]
              }
            },
            raw: true
          });

          const currentSpend = parseFloat(result.totalSpend) || 0;

          return {
            ...category.toJSON(),
            monthlyBudget: category.monthlyBudget,
            currentSpend
          };
        })
      );

      ctx.body = {
        success: true,
        categories: categoriesWithBudget
      };
    } catch (error) {
      console.error('App list expense categories error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to retrieve expense categories' };
    }
  }

  /**
   * App: PUT /app/:id/budget update monthlyBudget for a category
   * Body: { monthlyBudget }
   * Validates that the category belongs to a household the user is a member of
   */
  async appUpdateBudget(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;
      const { monthlyBudget } = ctx.request.body;

      if (monthlyBudget === undefined || monthlyBudget === null) {
        ctx.status = 400;
        ctx.body = { error: 'monthlyBudget is required' };
        return;
      }

      const category = await ExpenseCategory.findByPk(id);
      if (!category) {
        ctx.status = 404;
        ctx.body = { error: 'Expense category not found' };
        return;
      }

      // Validate that the app user is a member of the category's household
      const membership = await HouseholdMember.findOne({
        where: { householdId: category.householdId, appUserId: appUser.id }
      });

      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'You are not a member of this household' };
        return;
      }

      await category.update({ monthlyBudget });

      ctx.body = {
        success: true,
        category
      };
    } catch (error) {
      console.error('App update budget error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to update budget' };
    }
  }
}

module.exports = new ExpenseCategoriesController();
