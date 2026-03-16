const { IncomeCategory, Household, HouseholdMember, sequelize } = require('../models');

class IncomeCategoriesController {
  /**
   * Admin: GET all income categories for a given householdId (query param)
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

      const categories = await IncomeCategory.findAll({
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
      console.error('Admin list income categories error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to retrieve income categories' };
    }
  }

  /**
   * Admin: POST create a new income category
   * Body: { name, icon, color, sortOrder, householdId }
   */
  async adminCreate(ctx) {
    try {
      const { name, nameHe, icon, color, sortOrder, householdId } = ctx.request.body;

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

      const category = await IncomeCategory.create({
        name,
        nameHe: nameHe || null,
        icon,
        color,
        sortOrder,
        householdId
      });

      ctx.status = 201;
      ctx.body = {
        success: true,
        category
      };
    } catch (error) {
      console.error('Admin create income category error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to create income category' };
    }
  }

  /**
   * Admin: PUT /:id update an income category
   * Body: { name, icon, color, sortOrder }
   */
  async adminUpdate(ctx) {
    try {
      const { id } = ctx.params;
      const { name, nameHe, icon, color, sortOrder } = ctx.request.body;

      const category = await IncomeCategory.findByPk(id);
      if (!category) {
        ctx.status = 404;
        ctx.body = { error: 'Income category not found' };
        return;
      }

      await category.update({ name, nameHe: nameHe || null, icon, color, sortOrder });

      ctx.body = {
        success: true,
        category
      };
    } catch (error) {
      console.error('Admin update income category error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to update income category' };
    }
  }

  /**
   * Admin: DELETE /:id delete an income category
   */
  async adminDelete(ctx) {
    try {
      const { id } = ctx.params;

      const category = await IncomeCategory.findByPk(id);
      if (!category) {
        ctx.status = 404;
        ctx.body = { error: 'Income category not found' };
        return;
      }

      await category.destroy();

      ctx.body = { success: true };
    } catch (error) {
      console.error('Admin delete income category error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to delete income category' };
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
          await IncomeCategory.update(
            { sortOrder: item.sortOrder },
            { where: { id: item.id }, transaction: t }
          );
        }
      });

      ctx.body = { success: true };
    } catch (error) {
      console.error('Admin reorder income categories error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to reorder income categories' };
    }
  }

  /**
   * App: POST create an income category from within the app
   * Body: { name, icon, color, householdId }
   */
  async appCreate(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { name, nameHe, icon, color, householdId } = ctx.request.body;

      if (!name || !icon || !householdId) {
        ctx.status = 400;
        ctx.body = { error: 'name, icon, and householdId are required' };
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

      const maxOrder = await IncomeCategory.max('sortOrder', { where: { householdId } });
      const sortOrder = (maxOrder ?? 0) + 1;

      const category = await IncomeCategory.create({
        name,
        nameHe: nameHe || null,
        icon: icon || 'label',
        color: color || '#4CAF50',
        sortOrder,
        householdId
      });

      ctx.status = 201;
      ctx.body = { success: true, category };
    } catch (error) {
      console.error('App create income category error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to create income category' };
    }
  }

  /**
   * App: GET income categories for a household
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

      const categories = await IncomeCategory.findAll({
        where: { householdId },
        order: [['sortOrder', 'ASC']]
      });

      ctx.body = {
        success: true,
        categories
      };
    } catch (error) {
      console.error('App list income categories error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to retrieve income categories' };
    }
  }
}

module.exports = new IncomeCategoriesController();
