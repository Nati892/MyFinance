const { AppUser, Household, HouseholdMember, ExpenseCategory, IncomeCategory } = require('../models');

class HouseholdsController {
  /**
   * List all households (paginated), including member count and member list
   */
  async list(ctx) {
    try {
      const page = parseInt(ctx.query.page) || 1;
      const limit = parseInt(ctx.query.limit) || 20;
      const offset = (page - 1) * limit;

      const { count, rows: households } = await Household.findAndCountAll({
        include: [
          {
            model: HouseholdMember,
            include: [
              {
                model: AppUser,
                attributes: ['id', 'username']
              }
            ]
          }
        ],
        limit,
        offset,
        order: [['createdAt', 'DESC']]
      });

      const pages = Math.ceil(count / limit);

      ctx.body = {
        success: true,
        households: households.map(h => {
          const json = h.toJSON();
          json.memberCount = json.HouseholdMembers ? json.HouseholdMembers.length : 0;
          return json;
        }),
        pagination: {
          total: count,
          page,
          limit,
          pages
        }
      };
    } catch (error) {
      console.error('List households error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to list households' };
    }
  }

  /**
   * Get single household by id, including full member list, expense and income categories
   */
  async get(ctx) {
    try {
      const { id } = ctx.params;

      const household = await Household.findByPk(id, {
        include: [
          {
            model: HouseholdMember,
            include: [
              {
                model: AppUser,
                attributes: ['id', 'username', 'isActive', 'lastLogin', 'createdAt']
              }
            ]
          },
          {
            model: ExpenseCategory
          },
          {
            model: IncomeCategory
          }
        ]
      });

      if (!household) {
        ctx.status = 404;
        ctx.body = { error: 'Household not found' };
        return;
      }

      ctx.body = {
        success: true,
        household: household.toJSON()
      };
    } catch (error) {
      console.error('Get household error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to get household' };
    }
  }

  /**
   * Create a new household
   */
  async create(ctx) {
    try {
      const { name, description } = ctx.request.body;

      if (!name) {
        ctx.status = 400;
        ctx.body = { error: 'Name is required' };
        return;
      }

      const household = await Household.create({ name, description });

      ctx.status = 201;
      ctx.body = {
        success: true,
        household: household.toJSON()
      };
    } catch (error) {
      console.error('Create household error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to create household' };
    }
  }

  /**
   * Update a household's name and/or description
   */
  async update(ctx) {
    try {
      const { id } = ctx.params;
      const { name, description } = ctx.request.body;

      const household = await Household.findByPk(id);

      if (!household) {
        ctx.status = 404;
        ctx.body = { error: 'Household not found' };
        return;
      }

      await household.update({
        name: name !== undefined ? name : household.name,
        description: description !== undefined ? description : household.description
      });

      ctx.body = {
        success: true,
        household: household.toJSON()
      };
    } catch (error) {
      console.error('Update household error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to update household' };
    }
  }

  /**
   * Delete a household
   */
  async delete(ctx) {
    try {
      const { id } = ctx.params;

      const household = await Household.findByPk(id);

      if (!household) {
        ctx.status = 404;
        ctx.body = { error: 'Household not found' };
        return;
      }

      await household.destroy();

      ctx.body = { success: true };
    } catch (error) {
      console.error('Delete household error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to delete household' };
    }
  }

  /**
   * Add a member to a household
   */
  async addMember(ctx) {
    try {
      const { id } = ctx.params;
      const { appUserId, role } = ctx.request.body;

      if (!appUserId) {
        ctx.status = 400;
        ctx.body = { error: 'appUserId is required' };
        return;
      }

      const household = await Household.findByPk(id);

      if (!household) {
        ctx.status = 404;
        ctx.body = { error: 'Household not found' };
        return;
      }

      const appUser = await AppUser.findByPk(appUserId);

      if (!appUser) {
        ctx.status = 404;
        ctx.body = { error: 'App user not found' };
        return;
      }

      const existingMember = await HouseholdMember.findOne({
        where: { householdId: id, appUserId }
      });

      if (existingMember) {
        ctx.status = 409;
        ctx.body = { error: 'User is already a member of this household' };
        return;
      }

      await HouseholdMember.create({
        householdId: id,
        appUserId,
        role: role || 'member'
      });

      const members = await HouseholdMember.findAll({
        where: { householdId: id },
        include: [
          {
            model: AppUser,
            attributes: ['id', 'username', 'isActive']
          }
        ]
      });

      ctx.status = 201;
      ctx.body = {
        success: true,
        members: members.map(m => m.toJSON())
      };
    } catch (error) {
      console.error('Add household member error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to add member to household' };
    }
  }

  /**
   * Remove a member from a household
   */
  async removeMember(ctx) {
    try {
      const { id, appUserId } = ctx.params;

      const member = await HouseholdMember.findOne({
        where: { householdId: id, appUserId }
      });

      if (!member) {
        ctx.status = 404;
        ctx.body = { error: 'Household member not found' };
        return;
      }

      await member.destroy();

      ctx.body = { success: true };
    } catch (error) {
      console.error('Remove household member error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to remove member from household' };
    }
  }

  /**
   * Update a member's role within a household
   */
  async updateMemberRole(ctx) {
    try {
      const { id, appUserId } = ctx.params;
      const { role } = ctx.request.body;

      if (!role) {
        ctx.status = 400;
        ctx.body = { error: 'Role is required' };
        return;
      }

      const member = await HouseholdMember.findOne({
        where: { householdId: id, appUserId }
      });

      if (!member) {
        ctx.status = 404;
        ctx.body = { error: 'Household member not found' };
        return;
      }

      await member.update({ role });

      const updatedMember = await HouseholdMember.findOne({
        where: { householdId: id, appUserId },
        include: [
          {
            model: AppUser,
            attributes: ['id', 'username', 'isActive']
          }
        ]
      });

      ctx.body = {
        success: true,
        member: updatedMember.toJSON()
      };
    } catch (error) {
      console.error('Update household member role error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to update member role' };
    }
  }
}

module.exports = new HouseholdsController();
