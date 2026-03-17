const { Log } = require('../models');
const { Op } = require('sequelize');

class Logger {
    constructor() {
        this.isInitialized = false; // The shield is down!
        this.queuedLogs = []; // Temporary holding bay


        this.logLevels = {
            debug: 0,
            info: 1,
            warn: 2,
            err: 3
        };

        // Initialize size management
        this.MAX_DB_SIZE = 100 * 1024 * 1024; // 100MB
        this.CLEANUP_PERCENTAGE = 0.2; // Delete oldest 20%
        this.sizeCheckInterval = null;

        // Start periodic size check
        this.startSizeMonitoring();
    }
    async info(action, description, data = {}, context = {}) {
        return this.log('info', description, data, context);
    }
    async err(action, description, data = {}, context = {}) {
        return this.log('err', description, data, context);

    }
    async warn(action, description, data = {}, context = {}) {
        return this.log('warn', description, data, context);

    }

    async log(level, action, description, data = {}, context = {}) {
        try {
            // Console output always works
            if (global.cfg && global.cfg.env === 'development') {
                const timestamp = new Date().toISOString();
                const logColor = this.getLogColor(level);
                console.log(`${logColor}[${timestamp}] [${level.toUpperCase()}] ${action}: ${description || ''}${this.resetColor()}`);
            }

            // Queue logs until initialized
            if (!this.isInitialized) {
                this.queuedLogs.push({ level, action, description, data, context });
                return;
            }

            // Only attempt database write after initialization
            const logEntry = {
                level,
                action,
                description: JSON.stringify(description),
                source: 'backend',
                data: JSON.stringify(data) || {},
                userId: context.userId || null,
                ipAddress: context.ipAddress || null,
                userAgent: context.userAgent || null,
                method: context.method || null,
                path: context.path || null,
                statusCode: context.statusCode || null,
                duration: context.duration || null,
                errorStack: context.errorStack || null,
                metadata: context.metadata || {}
            };

            await Log.create(logEntry);

        } catch (error) {
            console.error('Logger database error - falling back to console:', error.message);
            // Never throw from logger - that leads to the dark side!
        }
    }

    // Call this after database is ready
    async initialize() {
        this.isInitialized = true;
        console.log('⚡ Logger initialized - processing queued logs...');

        // Process queued logs
        for (const log of this.queuedLogs) {
            await this.log(log.level, log.action, log.description, log.data, log.context);
        }
        this.queuedLogs = [];
    }

    async cleanupOldLogs() {
        try {
            console.log('🧹 Initiating log cleanup...');

            // Get total count
            const totalCount = await Log.count();
            const deleteCount = Math.floor(totalCount * this.CLEANUP_PERCENTAGE);

            // Get IDs of oldest logs to delete
            const oldestLogs = await Log.findAll({
                attributes: ['id'],
                order: [['createdAt', 'ASC']],
                limit: deleteCount,
                raw: true
            });

            const idsToDelete = oldestLogs.map(log => log.id);

            // Delete in batches to avoid timeout
            const batchSize = 1000;
            for (let i = 0; i < idsToDelete.length; i += batchSize) {
                const batch = idsToDelete.slice(i, i + batchSize);
                await Log.destroy({
                    where: {
                        id: { [Op.in]: batch }
                    }
                });
            }

            console.log(`✅ Cleaned up ${idsToDelete.length} old log entries`);

            // Log the cleanup action
            await this.info('SYSTEM_CLEANUP', `Removed ${idsToDelete.length} old log entries`, {
                totalBefore: totalCount,
                deleted: idsToDelete.length,
                remaining: totalCount - idsToDelete.length
            });

        } catch (error) {
            console.error('Cleanup error:', error);
        }
    }

    startSizeMonitoring() {
        // Check size every hour
        this.sizeCheckInterval = setInterval(() => {
            this.cleanupOldLogs();
        }, 60 * 60 * 1000);
    }

    stopSizeMonitoring() {
        if (this.sizeCheckInterval) {
            clearInterval(this.sizeCheckInterval);
            this.sizeCheckInterval = null;
        }
    }

    // Helper methods
    getLogColor(level) {
        const colors = {
            debug: '\x1b[36m', // Cyan
            info: '\x1b[32m',  // Green
            warn: '\x1b[33m',  // Yellow
            err: '\x1b[31m'    // Red
        };
        return colors[level] || '';
    }

    resetColor() {
        return '\x1b[0m';
    }

    // Request logging middleware
    requestLogger() {
        return async (ctx, next) => {
            const start = Date.now();
            const requestId = Math.random().toString(36).substr(2, 9);

            ctx.state.requestId = requestId;
            ctx.state.requestStart = start;

            try {
                await next();

                const duration = Date.now() - start;

                // Log successful requests (skip health checks)
                if (ctx.path !== '/health' && ctx.status < 400) {
                    await this.log('info', 'HTTP_REQUEST', `${ctx.method} ${ctx.path}`, {
                        query: ctx.query,
                        body: ctx.method !== 'GET' ? ctx.request.body : undefined
                    }, {
                        method: ctx.method,
                        path: ctx.path,
                        statusCode: ctx.status,
                        duration,
                        userId: ctx.state.user?.id,
                        ipAddress: ctx.ip,
                        userAgent: ctx.headers['user-agent'],
                        metadata: { requestId }
                    });
                }
            } catch (error) {
                const duration = Date.now() - start;

                // Log error requests
                await this.log('err', 'HTTP_ERROR', `${ctx.method} ${ctx.path}`, error, {
                    method: ctx.method,
                    path: ctx.path,
                    statusCode: ctx.status || 500,
                    duration,
                    userId: ctx.state.user?.id,
                    ipAddress: ctx.ip,
                    userAgent: ctx.headers['user-agent'],
                    metadata: { requestId }
                });

                throw error;
            }
        };
    }
}

// Create singleton instance
const logger = new Logger();

module.exports = logger;