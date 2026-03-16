const { Asset, HouseholdMember, sequelize } = require('../models');

class AssetsController {
  /**
   * App: GET /app/assets?householdId=X
   * Returns all assets for the household ordered by sortOrder.
   */
  async list(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { householdId } = ctx.query;

      if (!householdId) {
        ctx.status = 400;
        ctx.body = { error: 'householdId query parameter is required' };
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

      const assets = await Asset.findAll({
        where: { householdId },
        order: [['sortOrder', 'ASC']]
      });

      ctx.body = { success: true, assets };
    } catch (error) {
      console.error('Assets list error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to retrieve assets' };
    }
  }

  /**
   * App: POST /app/assets
   * Body: { name, value, liquidity, description, householdId, sortOrder }
   */
  async create(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { name, value, liquidity, description, householdId, sortOrder } = ctx.request.body;

      if (!name || !householdId) {
        ctx.status = 400;
        ctx.body = { error: 'name and householdId are required' };
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

      const asset = await Asset.create({
        name,
        value: value ?? 0,
        liquidity: liquidity ?? 'medium',
        description: description ?? null,
        householdId,
        sortOrder: sortOrder ?? 0
      });

      ctx.status = 201;
      ctx.body = { success: true, asset };
    } catch (error) {
      console.error('Assets create error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to create asset' };
    }
  }

  /**
   * App: PUT /app/assets/:id
   * Body: { name, value, liquidity, description, sortOrder }
   */
  async update(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;
      const { name, value, liquidity, description, sortOrder } = ctx.request.body;

      const asset = await Asset.findByPk(id);
      if (!asset) {
        ctx.status = 404;
        ctx.body = { error: 'Asset not found' };
        return;
      }

      const membership = await HouseholdMember.findOne({
        where: { householdId: asset.householdId, appUserId: appUser.id }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'Not a member of this household' };
        return;
      }

      await asset.update({ name, value, liquidity, description, sortOrder });

      ctx.body = { success: true, asset };
    } catch (error) {
      console.error('Assets update error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to update asset' };
    }
  }

  /**
   * App: DELETE /app/assets/:id
   */
  async delete(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;

      const asset = await Asset.findByPk(id);
      if (!asset) {
        ctx.status = 404;
        ctx.body = { error: 'Asset not found' };
        return;
      }

      const membership = await HouseholdMember.findOne({
        where: { householdId: asset.householdId, appUserId: appUser.id }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'Not a member of this household' };
        return;
      }

      await asset.destroy();

      ctx.body = { success: true };
    } catch (error) {
      console.error('Assets delete error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to delete asset' };
    }
  }

  /**
   * App: PUT /app/assets/reorder
   * Body: { items: [{id, sortOrder}] }
   */
  async reorder(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { items } = ctx.request.body;

      if (!items || !Array.isArray(items)) {
        ctx.status = 400;
        ctx.body = { error: 'items array is required' };
        return;
      }

      // Verify that the user is a member of the household for the first asset
      if (items.length > 0) {
        const firstAsset = await Asset.findByPk(items[0].id);
        if (!firstAsset) {
          ctx.status = 404;
          ctx.body = { error: 'Asset not found' };
          return;
        }

        const membership = await HouseholdMember.findOne({
          where: { householdId: firstAsset.householdId, appUserId: appUser.id }
        });
        if (!membership) {
          ctx.status = 403;
          ctx.body = { error: 'Not a member of this household' };
          return;
        }
      }

      await sequelize.transaction(async (t) => {
        for (const item of items) {
          await Asset.update(
            { sortOrder: item.sortOrder },
            { where: { id: item.id }, transaction: t }
          );
        }
      });

      ctx.body = { success: true };
    } catch (error) {
      console.error('Assets reorder error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to reorder assets' };
    }
  }
}

module.exports = new AssetsController();
