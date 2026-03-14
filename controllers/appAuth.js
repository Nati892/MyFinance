const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { AppUser, AppUserToken, HouseholdMember, Household } = require('../models');
const { Op } = require('sequelize');

class AppAuthController {
  /**
   * Sign in app user
   */
  async signIn(ctx) {
    try {
      const { username, password } = ctx.request.body;

      // Validate input
      if (!username || !password) {
        global.log.warn('APP_LOGIN_FAILED', 'Invalid app login attempt', {
          username
        }, {
          ipAddress: ctx.ip,
          userAgent: ctx.headers['user-agent']
        });

        ctx.status = 400;
        ctx.body = { error: 'Username and password are required' };
        return;
      }

      // Find app user by username
      const appUser = await AppUser.findOne({ where: { username } });

      if (!appUser) {
        global.log.warn('APP_LOGIN_FAILED', 'Invalid app login attempt', {
          username
        }, {
          ipAddress: ctx.ip,
          userAgent: ctx.headers['user-agent']
        });

        ctx.status = 401;
        ctx.body = { error: 'Invalid credentials' };
        return;
      }

      // Check if user is active
      if (!appUser.isActive) {
        global.log.warn('APP_LOGIN_FAILED', 'Invalid app login attempt', {
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
      const isValidPassword = await bcrypt.compare(password, appUser.password);

      if (!isValidPassword) {
        global.log.warn('APP_LOGIN_FAILED', 'Invalid app login attempt', {
          username
        }, {
          ipAddress: ctx.ip,
          userAgent: ctx.headers['user-agent']
        });

        ctx.status = 401;
        ctx.body = { error: 'Invalid credentials' };
        return;
      }

      // Update last login
      await appUser.update({ lastLogin: new Date() });

      // Generate access token
      const accessToken = jwt.sign(
        { id: appUser.id, username: appUser.username, type: 'appUser' },
        global.cfg.jwt.secret,
        { expiresIn: '1h' }
      );

      // Generate refresh token
      const refreshToken = crypto.randomBytes(64).toString('hex');

      // Hash refresh token before storing
      const hashedRefreshToken = await bcrypt.hash(refreshToken, global.cfg.bcrypt.saltRounds);

      // Store hashed refresh token with 7-day expiry
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + 7);

      await AppUserToken.create({
        appUserId: appUser.id,
        token: hashedRefreshToken,
        expiresAt
      });

      global.log.info('APP_USER_LOGIN', 'App user logged in', {
        username: appUser.username
      }, {
        userId: appUser.id,
        ipAddress: ctx.ip,
        userAgent: ctx.headers['user-agent']
      });

      const memberships = await HouseholdMember.findAll({
        where: { appUserId: appUser.id },
        include: [{ model: Household, attributes: ['id', 'name'] }]
      });

      const households = memberships.map(m => ({
        householdId: m.householdId,
        householdName: m.Household?.name ?? '',
        role: m.role
      }));

      ctx.body = {
        success: true,
        accessToken,
        refreshToken,
        user: { ...appUser.toJSON(), households },
        expiresIn: 3600
      };
    } catch (error) {
      console.error('App sign in error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to sign in' };
    }
  }

  /**
   * Refresh access token using refresh token
   */
  async refreshToken(ctx) {
    try {
      const { refreshToken, userId } = ctx.request.body;

      // Validate input
      if (!refreshToken || !userId) {
        ctx.status = 400;
        ctx.body = { error: 'Refresh token and userId are required' };
        return;
      }

      // Find all non-expired tokens for this user
      const tokens = await AppUserToken.findAll({
        where: {
          appUserId: userId,
          expiresAt: { [Op.gt]: new Date() }
        }
      });

      if (!tokens || tokens.length === 0) {
        ctx.status = 401;
        ctx.body = { error: 'Invalid or expired refresh token' };
        return;
      }

      // Compare raw refresh token against each hashed one
      let matchedToken = null;
      for (const tokenRecord of tokens) {
        const isMatch = await bcrypt.compare(refreshToken, tokenRecord.token);
        if (isMatch) {
          matchedToken = tokenRecord;
          break;
        }
      }

      if (!matchedToken) {
        ctx.status = 401;
        ctx.body = { error: 'Invalid or expired refresh token' };
        return;
      }

      // Load the app user
      const appUser = await AppUser.findByPk(userId);

      if (!appUser || !appUser.isActive) {
        ctx.status = 401;
        ctx.body = { error: 'User not found or deactivated' };
        return;
      }

      // Delete the old token (rotate)
      await matchedToken.destroy();

      // Generate new access token
      const accessToken = jwt.sign(
        { id: appUser.id, username: appUser.username, type: 'appUser' },
        global.cfg.jwt.secret,
        { expiresIn: '1h' }
      );

      // Generate new refresh token
      const newRefreshToken = crypto.randomBytes(64).toString('hex');

      // Hash new refresh token before storing
      const hashedRefreshToken = await bcrypt.hash(newRefreshToken, global.cfg.bcrypt.saltRounds);

      // Store new hashed refresh token with 7-day expiry
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + 7);

      await AppUserToken.create({
        appUserId: appUser.id,
        token: hashedRefreshToken,
        expiresAt
      });

      // Update last login
      await appUser.update({ lastLogin: new Date() });

      ctx.body = {
        success: true,
        accessToken,
        refreshToken: newRefreshToken,
        expiresIn: 3600
      };
    } catch (error) {
      console.error('App refresh token error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to refresh token' };
    }
  }

  /**
   * Get app user profile with households
   */
  async getProfile(ctx) {
    try {
      const appUser = ctx.state.appUser;

      // Load household memberships with household details
      const memberships = await HouseholdMember.findAll({
        where: { appUserId: appUser.id },
        include: [
          {
            model: Household,
            attributes: ['id', 'name']
          }
        ]
      });

      const households = memberships.map(m => ({
        householdId: m.Household.id,
        householdName: m.Household.name,
        role: m.role
      }));

      ctx.body = {
        success: true,
        user: appUser.toJSON(),
        households
      };
    } catch (error) {
      console.error('App get profile error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to get profile' };
    }
  }

  /**
   * Sign out app user by deleting refresh token
   */
  async signOut(ctx) {
    try {
      const { refreshToken, userId } = ctx.request.body;

      // Validate input
      if (!refreshToken || !userId) {
        ctx.status = 400;
        ctx.body = { error: 'Refresh token and userId are required' };
        return;
      }

      // Find all non-expired tokens for this user
      const tokens = await AppUserToken.findAll({
        where: { appUserId: userId }
      });

      // Find and delete the matching token
      let deleted = false;
      for (const tokenRecord of tokens) {
        const isMatch = await bcrypt.compare(refreshToken, tokenRecord.token);
        if (isMatch) {
          await tokenRecord.destroy();
          deleted = true;
          break;
        }
      }

      global.log.info('APP_USER_LOGOUT', 'App user signed out', {}, {
        userId,
        ipAddress: ctx.ip,
        userAgent: ctx.headers['user-agent']
      });

      ctx.body = { success: true };
    } catch (error) {
      console.error('App sign out error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to sign out' };
    }
  }
}

module.exports = new AppAuthController();
