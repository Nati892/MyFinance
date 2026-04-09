const jwt = require('jsonwebtoken');
const { AppUser, User } = require('../models');

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

/**
 * Accepts either an app user JWT or a management user JWT.
 * Used for routes that both the Flutter app and the management UI need to access.
 */
const authenticateAppOrAdmin = async (ctx, next) => {
  const authHeader = ctx.headers.authorization;
  if (!authHeader) {
    ctx.status = 401;
    ctx.body = { error: 'No authorization header provided' };
    return;
  }

  const token = authHeader.startsWith('Bearer ')
    ? authHeader.substring(7)
    : authHeader;

  if (!token) {
    ctx.status = 401;
    ctx.body = { error: 'No token provided' };
    return;
  }

  try {
    const decoded = jwt.verify(token, global.cfg.jwt.secret);

    if (decoded.type === 'appUser') {
      const appUser = await AppUser.findByPk(decoded.id);
      if (!appUser || !appUser.isActive) {
        ctx.status = 401;
        ctx.body = { error: 'User not found or inactive' };
        return;
      }
      ctx.state.appUser = appUser;
    } else {
      const user = await User.findByPk(decoded.id);
      if (!user || !user.isActive) {
        ctx.status = 401;
        ctx.body = { error: 'User not found or inactive' };
        return;
      }
      ctx.state.user = user;
    }

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
  authenticateApp,
  authenticateAppOrAdmin,
};
