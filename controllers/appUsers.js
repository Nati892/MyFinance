const bcrypt = require('bcryptjs');
const { AppUser, Household, HouseholdMember } = require('../models');

class AppUsersController {
  /**
   * List all app users (paginated), including their households
   */
  async list(ctx) {
    try {
      const page = parseInt(ctx.query.page) || 1;
      const limit = parseInt(ctx.query.limit) || 20;
      const offset = (page - 1) * limit;

      const { count, rows: users } = await AppUser.findAndCountAll({
        include: [
          {
            model: HouseholdMember,
            include: [
              {
                model: Household
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
        users: users.map(u => u.toJSON()),
        pagination: {
          total: count,
          page,
          limit,
          pages
        }
      };
    } catch (error) {
      console.error('List app users error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to list app users' };
    }
  }

  /**
   * Get single app user by id, including their households
   */
  async get(ctx) {
    try {
      const { id } = ctx.params;

      const user = await AppUser.findByPk(id, {
        include: [
          {
            model: HouseholdMember,
            include: [
              {
                model: Household
              }
            ]
          }
        ]
      });

      if (!user) {
        ctx.status = 404;
        ctx.body = { error: 'App user not found' };
        return;
      }

      ctx.body = {
        success: true,
        user: user.toJSON()
      };
    } catch (error) {
      console.error('Get app user error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to get app user' };
    }
  }

  /**
   * Create a new app user
   */
  async create(ctx) {
    try {
      const { username, password } = ctx.request.body;

      if (!username || !password) {
        ctx.status = 400;
        ctx.body = { error: 'Username and password are required' };
        return;
      }

      const existingUser = await AppUser.findOne({ where: { username } });
      if (existingUser) {
        ctx.status = 409;
        ctx.body = { error: 'Username already exists' };
        return;
      }

      const hashedPassword = await bcrypt.hash(password, global.cfg.bcrypt.saltRounds);

      const user = await AppUser.create({
        username,
        password: hashedPassword
      });

      global.log.info('APP_USER_CREATED', 'New app user created', {
        username: user.username
      }, {
        userId: user.id,
        ipAddress: ctx.ip,
        userAgent: ctx.headers['user-agent']
      });

      ctx.status = 201;
      ctx.body = {
        success: true,
        user: user.toJSON()
      };
    } catch (error) {
      console.error('Create app user error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to create app user' };
    }
  }

  /**
   * Update an app user's username and/or isActive status
   */
  async update(ctx) {
    try {
      const { id } = ctx.params;
      const { username, isActive } = ctx.request.body;

      const user = await AppUser.findByPk(id);

      if (!user) {
        ctx.status = 404;
        ctx.body = { error: 'App user not found' };
        return;
      }

      if (username && username !== user.username) {
        const existingUser = await AppUser.findOne({ where: { username } });
        if (existingUser) {
          ctx.status = 409;
          ctx.body = { error: 'Username already exists' };
          return;
        }
      }

      await user.update({
        username: username !== undefined ? username : user.username,
        isActive: isActive !== undefined ? isActive : user.isActive
      });

      ctx.body = {
        success: true,
        user: user.toJSON()
      };
    } catch (error) {
      console.error('Update app user error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to update app user' };
    }
  }

  /**
   * Reset an app user's password
   */
  async resetPassword(ctx) {
    try {
      const { id } = ctx.params;
      const { newPassword } = ctx.request.body;

      if (!newPassword) {
        ctx.status = 400;
        ctx.body = { error: 'New password is required' };
        return;
      }

      const user = await AppUser.findByPk(id);

      if (!user) {
        ctx.status = 404;
        ctx.body = { error: 'App user not found' };
        return;
      }

      const hashedPassword = await bcrypt.hash(newPassword, global.cfg.bcrypt.saltRounds);

      await user.update({ password: hashedPassword });

      ctx.body = { success: true };
    } catch (error) {
      console.error('Reset app user password error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to reset password' };
    }
  }

  /**
   * Delete an app user
   */
  async delete(ctx) {
    try {
      const { id } = ctx.params;

      const user = await AppUser.findByPk(id);

      if (!user) {
        ctx.status = 404;
        ctx.body = { error: 'App user not found' };
        return;
      }

      await user.destroy();

      ctx.body = { success: true };
    } catch (error) {
      console.error('Delete app user error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to delete app user' };
    }
  }
}

module.exports = new AppUsersController();
