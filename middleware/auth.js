const jwt = require('jsonwebtoken');
const { User } = require('../models');

/**
 * Authentication middleware
 * Verifies JWT token and attaches user to context
 */
const authenticate = async (ctx, next) => {
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
    
    // Get user from database
    const user = await User.findByPk(decoded.id);
    
    if (!user) {
      ctx.status = 401;
      ctx.body = { error: 'User not found' };
      return;
    }

    if (!user.isActive) {
      ctx.status = 401;
      ctx.body = { error: 'User account is deactivated' };
      return;
    }

    // Attach user to context
    ctx.state.user = user;
    
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
 * Optional authentication middleware
 * Attaches user if token is valid, but doesn't fail if no token
 */
const optionalAuth = async (ctx, next) => {
  try {
    const authHeader = ctx.headers.authorization;
    
    if (authHeader) {
      const token = authHeader.startsWith('Bearer ') 
        ? authHeader.substring(7) 
        : authHeader;

      if (token) {
        const decoded = jwt.verify(token, global.cfg.jwt.secret);
        const user = await User.findByPk(decoded.id);
        
        if (user && user.isActive) {
          ctx.state.user = user;
        }
      }
    }
  } catch (error) {
    // Silently fail for optional auth
  }
  
  await next();
};

module.exports = {
  authenticate,
  optionalAuth
};