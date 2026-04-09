const managerAuth = async (ctx, next) => {
  const authHeader = ctx.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    ctx.status = 401;
    ctx.body = { error: 'Manager token required' };
    return;
  }

  const token = authHeader.substring(7);
  if (token !== global.cfg.managerApiToken) {
    ctx.status = 403;
    ctx.body = { error: 'Invalid manager token' };
    return;
  }

  await next();
};

module.exports = { managerAuth };
