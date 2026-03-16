const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { User } = require('../models');
const { Sequelize } = require('sequelize')
class AuthController {
  /**
   * Sign up new user
   */
  async signUp(ctx) {
    try {
      const { username, email, password } = ctx.request.body;

      // Validate input
      if (!username || !email || !password) {
        ctx.status = 400;
        ctx.body = { error: 'Username, email, and password are required' };
        return;
      }

      if (password.length < 6) {
        ctx.status = 400;
        ctx.body = { error: 'Password must be at least 6 characters long' };
        return;
      }

      // Check if user already exists
      const existingUser = await User.findOne({
        where: {
          [global.db.Sequelize.Op.or]: [
            { username },
            { email }
          ]
        }
      });

      if (existingUser) {
        ctx.status = 409;
        ctx.body = {
          error: existingUser.username === username
            ? 'Username already exists'
            : 'Email already exists'
        };
        return;
      }

      // Hash password
      const hashedPassword = await bcrypt.hash(password, global.cfg.bcrypt.saltRounds);

      // Create user
      const user = await User.create({
        username,
        email,
        password: hashedPassword
      });

      // Generate token
      const token = jwt.sign(
        { id: user.id, username: user.username },
        global.cfg.jwt.secret,
        { expiresIn: global.cfg.jwt.expiresIn }
      );

      global.log.info('USER_SIGNUP', 'New user registered', {
        username: user.username,
        email: user.email
      }, {
        userId: user.id,
        ipAddress: ctx.ip,
        userAgent: ctx.headers['user-agent']
      });

      ctx.status = 201;
      ctx.body = {
        success: true,
        token,
        user: user.toJSON()
      };
    } catch (error) {
      console.error('Sign up error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to create user' };
    }
  }

  /**
   * Sign in user
   */
  async signIn(ctx) {
    try {
      console.log("signin");
      const { username, password } = ctx.request.body;
      // Validate input
      if (!username || !password) {

        global.log.warn('LOGIN_FAILED', 'Invalid login attempt', {
          username
        }, {
          ipAddress: ctx.ip,
          userAgent: ctx.headers['user-agent']
        });

        ctx.status = 400;
        ctx.body = { error: 'Username and password are required' };
        return;
      }

      // Find user by username or email
      const user = await User.findOne({
        where: {
          [Sequelize.Op.or]: [
            { username },
            { email: username }
          ]
        }
      });

      if (!user) {
        console.log(`[DEBUG] User not found for username: "${username}"`);
        global.log.warn('LOGIN_FAILED', 'Invalid login attempt', {
          username
        }, {
          ipAddress: ctx.ip,
          userAgent: ctx.headers['user-agent']
        });

        ctx.status = 401;
        ctx.body = { error: 'Invalid credentials bulbul 2' };
        return;
      }

      console.log(`[DEBUG] User found: id=${user.id}, isActive=${user.isActive}, passwordHash="${user.password}"`);

      // Check if user is active
      if (!user.isActive) {

        global.log.warn('LOGIN_FAILED', 'Invalid login attempt', {
          username
        }, {
          ipAddress: ctx.ip,
          userAgent: ctx.headers['user-agent']
        });

        ctx.status = 401;
        ctx.body = { error: 'Account is deactivated' };
        return;
      }

      // Verify password
      const isValidPassword = await bcrypt.compare(password, user.password);
      console.log(`[DEBUG] bcrypt.compare("${password}", "${user.password}") => ${isValidPassword}`);

      if (!isValidPassword) {

        global.log.warn('LOGIN_FAILED', 'Invalid login attempt', {
          username
        }, {
          ipAddress: ctx.ip,
          userAgent: ctx.headers['user-agent']
        });

        ctx.status = 401;
        ctx.body = { error: 'Invalid credentials bulbul 1' };
        return;
      }

      // Update last login
      await user.update({ lastLogin: new Date() });

      // Generate token
      const token = jwt.sign(
        { id: user.id, username: user.username },
        global.cfg.jwt.secret,
        { expiresIn: global.cfg.jwt.expiresIn }
      );

      global.log.info('USER_LOGIN', 'User logged in', {
        username: user.username
      }, {
        userId: user.id,
        ipAddress: ctx.ip,
        userAgent: ctx.headers['user-agent']
      });

      ctx.body = {
        success: true,
        token,
        user: user.toJSON()
      };
    } catch (error) {
      console.error('Sign in error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to sign in' };
    }
  }

  /**
   * Get current user profile
   */
  async getProfile(ctx) {
    try {
      const user = ctx.state.user;

      ctx.body = {
        success: true,
        user: user.toJSON()
      };
    } catch (error) {
      console.error('Get profile error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to get profile' };
    }
  }

  /**
   * Update user profile
   */
  async updateProfile(ctx) {
    try {
      const user = ctx.state.user;
      const { username, email } = ctx.request.body;

      // Check if username/email already taken by another user
      if (username || email) {
        const whereClause = [];
        if (username && username !== user.username) {
          whereClause.push({ username });
        }
        if (email && email !== user.email) {
          whereClause.push({ email });
        }

        if (whereClause.length > 0) {
          const existingUser = await User.findOne({
            where: {
              id: { [global.db.Sequelize.Op.ne]: user.id },
              [global.db.Sequelize.Op.or]: whereClause
            }
          });

          if (existingUser) {
            ctx.status = 409;
            ctx.body = {
              error: existingUser.username === username
                ? 'Username already exists'
                : 'Email already exists'
            };
            return;
          }
        }
      }

      // Update user
      await user.update({
        username: username || user.username,
        email: email || user.email
      });

      ctx.body = {
        success: true,
        user: user.toJSON()
      };
    } catch (error) {
      console.error('Update profile error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to update profile' };
    }
  }

  /**
   * Change password
   */
  async changePassword(ctx) {
    try {
      const user = ctx.state.user;
      const { currentPassword, newPassword } = ctx.request.body;

      // Validate input
      if (!currentPassword || !newPassword) {
        ctx.status = 400;
        ctx.body = { error: 'Current password and new password are required' };
        return;
      }

      if (newPassword.length < 6) {
        ctx.status = 400;
        ctx.body = { error: 'New password must be at least 6 characters long' };
        return;
      }

      // Verify current password
      const isValidPassword = await bcrypt.compare(currentPassword, user.password);

      if (!isValidPassword) {
        ctx.status = 401;
        ctx.body = { error: 'Current password is incorrect' };
        return;
      }

      // Hash new password
      const hashedPassword = await bcrypt.hash(newPassword, global.cfg.bcrypt.saltRounds);

      // Update password
      await user.update({ password: hashedPassword });

      ctx.body = {
        success: true,
        message: 'Password changed successfully'
      };
    } catch (error) {
      console.error('Change password error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to change password' };
    }
  }

  /**
   * Refresh token
   */
  async refreshToken(ctx) {
    try {
      const user = ctx.state.user;

      // Generate new token
      const token = jwt.sign(
        { id: user.id, username: user.username },
        global.cfg.jwt.secret,
        { expiresIn: global.cfg.jwt.expiresIn }
      );

      ctx.body = {
        success: true,
        token
      };
    } catch (error) {
      console.error('Refresh token error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to refresh token' };
    }
  }
}

module.exports = new AuthController();