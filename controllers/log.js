const { Log, User } = require('../models');
const { Sequelize, Op } = require('sequelize');

function buildDateFilter(preset, dateFrom, dateTo) {
  const now = new Date();
  let startDate, endDate;

  if (preset) {
    switch (preset) {
      case 'today':
        startDate = new Date(now.setHours(0, 0, 0, 0));
        endDate = new Date(now.setHours(23, 59, 59, 999));
        break;
      case 'yesterday':
        const yesterday = new Date(now.setDate(now.getDate() - 1));
        startDate = new Date(yesterday.setHours(0, 0, 0, 0));
        endDate = new Date(yesterday.setHours(23, 59, 59, 999));
        break;
      case 'last7days':
        startDate = new Date(now.setDate(now.getDate() - 7));
        endDate = new Date();
        break;
      case 'last30days':
        startDate = new Date(now.setDate(now.getDate() - 30));
        endDate = new Date();
        break;
      case 'thisMonth':
        startDate = new Date(now.getFullYear(), now.getMonth(), 1);
        endDate = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
        break;
      case 'lastMonth':
        startDate = new Date(now.getFullYear(), now.getMonth() - 1, 1);
        endDate = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);
        break;
    }
  } else if (dateFrom || dateTo) {
    startDate = dateFrom ? new Date(dateFrom) : null;
    endDate = dateTo ? new Date(dateTo) : null;
  }

  if (startDate || endDate) {
    const filter = {};
    if (startDate) filter[Op.gte] = startDate;
    if (endDate) filter[Op.lte] = endDate;
    return filter;
  }

  return null;
}

class LogController {
  async getLogs(ctx) {
    try {
      const page = parseInt(ctx.query.page) || 1;
      const limit = parseInt(ctx.query.limit) || 10;
      const offset = (page - 1) * limit;

      // Extract filter parameters - The Force guides our search! 🔍
      const {
        level,
        source,
        userId,
        action,
        search,
        dateFrom,
        dateTo,
        preset
      } = ctx.query;

      // Build where clause
      const where = {};

      // Level filter
      if (level) {
        where.level = level;
      }

      // Source filter (frontend/backend)
      if (source) {
        where.source = source;
      }

      // User filter
      if (userId) {
        where.userId = userId;
      }

      // Action filter
      if (action) {
        where.action = action;
      }

      // Full text search in description and action
      if (search) {
        where[Op.or] = [
          { description: { [Op.like]: `%${search}%` } },
          { action: { [Op.like]: `%${search}%` } },
          { '$user.username$': { [Op.like]: `%${search}%` } }
        ];
      }

      // Date range filter
      const dateFilter = buildDateFilter(preset, dateFrom, dateTo);
      if (dateFilter) {
        where.createdAt = dateFilter;
      }

      const { count, rows } = await Log.findAndCountAll({
        where,
        include: [{
          model: User,
          as: 'user',
          attributes: ['id', 'username', 'email']
        }],
        limit,
        offset,
        order: [['createdAt', 'DESC']],
        distinct: true // Important for accurate count with joins
      });

      // Get unique values for filters
      const [levels, sources, actions, users] = await Promise.all([
        Log.findAll({
          attributes: [[Sequelize.fn('DISTINCT', Sequelize.col('level')), 'level']],
          raw: true
        }),
        Log.findAll({
          attributes: [[Sequelize.fn('DISTINCT', Sequelize.col('source')), 'source']],
          raw: true
        }),
        Log.findAll({
          attributes: [[Sequelize.fn('DISTINCT', Sequelize.col('action')), 'action']],
          order: [['action', 'ASC']],
          raw: true
        }),
        User.findAll({
          attributes: ['id', 'username'],
          include: [{
            model: Log,
            as: 'logs',
            attributes: [],
            required: true
          }],
          group: ['User.id'],
          raw: true
        })
      ]);

      ctx.body = {
        success: true,
        data: rows,
        pagination: {
          page,
          limit,
          total: count,
          pages: Math.ceil(count / limit)
        },
        filters: {
          levels: levels.map(l => l.level).filter(Boolean),
          sources: sources.map(s => s.source).filter(Boolean),
          actions: actions.map(a => a.action).filter(Boolean),
          users: users
        }
      };
    } catch (error) {
      ctx.status = 500;
      ctx.body = { error: error.message };
      global.log.err('GET_LOGS_ERROR', 'Failed to retrieve logs', error);
    }
  }

  // Helper method for date presets - Time manipulation worthy of a Jedi! ⏰


  async getLog(ctx) {
    try {
      const { id } = ctx.params;

      const log = await Log.findByPk(id, {
        include: [{
          model: User,
          as: 'user',
          attributes: ['id', 'username', 'email']
        }]
      });

      if (!log) {
        ctx.status = 404;
        ctx.body = { error: 'Log not found' };
        return;
      }

      ctx.body = {
        success: true,
        data: log
      };
    } catch (error) {
      ctx.status = 500;
      ctx.body = { error: error.message };
    }
  }

  async createLog(ctx) {
    try {
      const { action, description, metadata } = ctx.request.body;
      const userId = ctx.state.user.id; // Get from authenticated user

      // Get IP and user agent
      const ipAddress = ctx.request.ip;
      const userAgent = ctx.request.headers['user-agent'];

      const log = await Log.create({
        action,
        description,
        userId,
        ipAddress,
        userAgent,
        metadata
      });

      ctx.status = 201;
      ctx.body = {
        success: true,
        data: log
      };
    } catch (error) {
      ctx.status = 400;
      ctx.body = { error: error.message };
    }
  }

  async updateLog(ctx) {
    try {
      const { id } = ctx.params;
      const { action, description, metadata } = ctx.request.body;

      const log = await Log.findByPk(id);

      if (!log) {
        ctx.status = 404;
        ctx.body = { error: 'Log not found' };
        return;
      }

      await log.update({
        action,
        description,
        metadata
      });

      ctx.body = {
        success: true,
        data: log
      };
    } catch (error) {
      ctx.status = 400;
      ctx.body = { error: error.message };
    }
  }

  async deleteLog(ctx) {
    try {
      const { id } = ctx.params;

      const log = await Log.findByPk(id);

      if (!log) {
        ctx.status = 404;
        ctx.body = { error: 'Log not found' };
        return;
      }

      await log.destroy();

      ctx.body = {
        success: true,
        message: 'Log deleted successfully'
      };
    } catch (error) {
      ctx.status = 500;
      ctx.body = { error: error.message };
    }
  }

  async createBatchLogs(ctx) {
    try {
      const { logs } = ctx.request.body;

      if (!Array.isArray(logs) || logs.length === 0) {
        ctx.status = 400;
        ctx.body = { error: 'Invalid logs array' };
        return;
      }

      // Get user info
      const userId = ctx.state.user?.id || null;
      const ipAddress = ctx.ip;
      const userAgent = ctx.headers['user-agent'];

      // Process logs
      const logEntries = logs.map(log => ({
        action: log.action || 'UNKNOWN',
        description: log.description || null,
        level: log.level || 'info',
        source: log.source || 'frontend',
        data: log.data || {},
        userId,
        ipAddress,
        userAgent,
        method: log.method || null,
        path: log.path || null,
        statusCode: log.statusCode || null,
        duration: log.duration || null,
        errorStack: log.errorStack || null,
        metadata: {
          ...log.metadata,
          timestamp: log.timestamp || new Date()
        }
      }));

      // Bulk create
      const created = await Log.bulkCreate(logEntries);

      ctx.body = {
        success: true,
        message: `Created ${created.length} log entries`,
        count: created.length
      };

      // Log the batch operation itself
      global.log.info('BATCH_LOGS_CREATED', `Received ${logs.length} frontend logs`, {
        count: logs.length,
        levels: logs.reduce((acc, log) => {
          acc[log.level] = (acc[log.level] || 0) + 1;
          return acc;
        }, {})
      }, { userId, ipAddress, userAgent });

    } catch (error) {
      ctx.status = 500;
      ctx.body = { error: error.message };
      global.log.log('err','BATCH_LOGS_ERROR', 'Failed to create batch logs', error);
    }
  }

}

module.exports = new LogController();