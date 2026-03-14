const jwt = require('jsonwebtoken');
const { AppUser } = require('../models');

/**
 * Authentication middleware for AppUsers
 * Verifies JWT token and attaches app user to context
 */
const authenticateApp = async (ctx, next) => {
  try {
    // Get token from header
    const authHeader = ctx.headers.authorization;

    if (!authHeader) {
      ctx.status = 401;
      ctx.body = { error: 'No authorization header provided' };
      return;
    }

    // Extract token (Bearer <token>)
    const token = authHeader.startsWith('Bearer ')
      ? authHeader.substring(7)
      : authHeader;

    if (!token) {
      ctx.status = 401;
      ctx.body = { error: 'No token provided' };
      return;
    }

    // Verify token
    const decoded = jwt.verify(token, global.cfg.jwt.secret);

    // Ensure this is an app user token, not an admin token
    if (decoded.type !== 'appUser') {
      ctx.status = 401;
      ctx.body = { error: 'Invalid token type' };
      return;
    }

    // Get app user from database
    const appUser = await AppUser.findByPk(decoded.id);

    if (!appUser) {
      ctx.status = 401;
      ctx.body = { error: 'User not found' };
      return;
    }

    if (!appUser.isActive) {
      ctx.status = 401;
      ctx.body = { error: 'User account is deactivated' };
      return;
    }

    // Attach app user to context
    ctx.state.appUser = appUser;

    await next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      ctx.status = 401;
      ctx.body = { error: 'Invalid token' };
    } else if (error.name === 'TokenExpiredError') {
      ctx.status = 401;
      ctx.body = { error: 'Token expired' };
    } else {
      ctx.status = 500;
      ctx.body = { error: 'Authentication error' };
    }
  }
};

module.exports = {
  authenticateApp
};
