const { Setting } = require('../models');
const { Op } = require('sequelize');

class SettingsController {
  async getSettings(ctx) {
    try {
      const page = parseInt(ctx.query.page) || 1;
      const limit = parseInt(ctx.query.limit) || 50;
      const offset = (page - 1) * limit;

      // Extract filter parameters
      const { search, core, sendWithConfig } = ctx.query;

      // Build where clause
      const where = {};

      // Core settings filter
      if (core !== undefined) {
        where.core_setting = core === 'true';
      }

      // Send with config filter
      if (sendWithConfig !== undefined) {
        where.sendWithConfig = sendWithConfig === 'true';
      }

      // Search in key and description
      if (search) {
        where[Op.or] = [
          { key: { [Op.like]: `%${search}%` } },
          { description: { [Op.like]: `%${search}%` } }
        ];
      }

      const { count, rows } = await Setting.findAndCountAll({
        where,
        limit,
        offset,
        order: [['key', 'ASC']]
      });

      ctx.body = {
        success: true,
        data: rows,
        pagination: {
          page,
          limit,
          total: count,
          pages: Math.ceil(count / limit)
        }
      };
    } catch (error) {
      ctx.status = 500;
      ctx.body = { error: error.message };
      global.log.err('GET_SETTINGS_ERROR', 'Failed to retrieve settings', error);
    }
  }

  async getSetting(ctx) {
    try {
      const { id } = ctx.params;

      const setting = await Setting.findByPk(id);

      if (!setting) {
        ctx.status = 404;
        ctx.body = { error: 'Setting not found' };
        return;
      }

      ctx.body = {
        success: true,
        data: setting
      };
    } catch (error) {
      ctx.status = 500;
      ctx.body = { error: error.message };
      global.log.err('GET_SETTING_ERROR', 'Failed to retrieve setting', error);
    }
  }

  async createSetting(ctx) {
    try {
      const { key, value, description, sendWithConfig } = ctx.request.body;

      // Validate required fields
      if (!key) {
        ctx.status = 400;
        ctx.body = { error: 'Key is required' };
        return;
      }

      // Check if key already exists
      const existing = await Setting.findOne({ where: { key } });
      if (existing) {
        ctx.status = 400;
        ctx.body = { error: 'Setting with this key already exists' };
        return;
      }

      const setting = await Setting.create({
        key,
        value,
        description,
        sendWithConfig: sendWithConfig || false,
        core_setting: false // New settings are never core settings
      });

      global.log.info('SETTING_CREATED', `Setting ${key} created`, {
        settingId: setting.id,
        key: setting.key
      });

      ctx.status = 201;
      ctx.body = {
        success: true,
        data: setting
      };
    } catch (error) {
      ctx.status = 400;
      ctx.body = { error: error.message };
      global.log.err('CREATE_SETTING_ERROR', 'Failed to create setting', error);
    }
  }

  async updateSetting(ctx) {
    try {
      const { id } = ctx.params;
      const { value, description, sendWithConfig } = ctx.request.body;

      const setting = await Setting.findByPk(id);

      if (!setting) {
        ctx.status = 404;
        ctx.body = { error: 'Setting not found' };
        return;
      }

      // Track changes for logging
      const changes = {};
      if (value !== undefined && value !== setting.value) changes.value = { from: setting.value, to: value };
      if (description !== undefined && description !== setting.description) changes.description = { from: setting.description, to: description };
      if (sendWithConfig !== undefined && sendWithConfig !== setting.sendWithConfig) changes.sendWithConfig = { from: setting.sendWithConfig, to: sendWithConfig };

      await setting.update({
        value,
        description,
        sendWithConfig
      });

      global.log.info('SETTING_UPDATED', `Setting ${setting.key} updated`, {
        settingId: setting.id,
        key: setting.key,
        changes
      });

      ctx.body = {
        success: true,
        data: setting
      };
    } catch (error) {
      ctx.status = 400;
      ctx.body = { error: error.message };
      global.log.err('UPDATE_SETTING_ERROR', 'Failed to update setting', error);
    }
  }

  async deleteSetting(ctx) {
    try {
      const { id } = ctx.params;

      const setting = await Setting.findByPk(id);

      if (!setting) {
        ctx.status = 404;
        ctx.body = { error: 'Setting not found' };
        return;
      }

      // Prevent deletion of core settings
      if (setting.core_setting) {
        ctx.status = 403;
        ctx.body = { error: 'Core settings cannot be deleted' };
        return;
      }

      const key = setting.key;
      await setting.destroy();

      global.log.warn('SETTING_DELETED', `Setting ${key} deleted`, {
        settingId: id,
        key
      });

      ctx.body = {
        success: true,
        message: 'Setting deleted successfully'
      };
    } catch (error) {
      ctx.status = 500;
      ctx.body = { error: error.message };
      global.log.err('DELETE_SETTING_ERROR', 'Failed to delete setting', error);
    }
  }

  // Bulk operations
  async bulkUpdateSettings(ctx) {
    try {
      const { settings } = ctx.request.body;

      if (!Array.isArray(settings) || settings.length === 0) {
        ctx.status = 400;
        ctx.body = { error: 'Invalid settings array' };
        return;
      }

      const results = [];
      const errors = [];

      for (const settingUpdate of settings) {
        try {
          const setting = await Setting.findByPk(settingUpdate.id);
          if (!setting) {
            errors.push({ id: settingUpdate.id, error: 'Not found' });
            continue;
          }

          await setting.update({
            value: settingUpdate.value,
            description: settingUpdate.description,
            sendWithConfig: settingUpdate.sendWithConfig
          });

          results.push(setting);
        } catch (error) {
          errors.push({ id: settingUpdate.id, error: error.message });
        }
      }

      global.log.info('BULK_SETTINGS_UPDATE', `Updated ${results.length} settings`, {
        successCount: results.length,
        errorCount: errors.length
      });

      ctx.body = {
        success: true,
        updated: results.length,
        errors: errors.length > 0 ? errors : undefined
      };
    } catch (error) {
      ctx.status = 500;
      ctx.body = { error: error.message };
      global.log.err('BULK_UPDATE_ERROR', 'Failed to bulk update settings', error);
    }
  }

  // Get settings for config
  async getConfigSettings(ctx) {
    try {
      const settings = await Setting.findAll({
        where: { sendWithConfig: true },
        attributes: ['key', 'value']
      });

      // Convert to key-value object
      const config = {};
      settings.forEach(setting => {
        // Try to parse JSON values
        try {
          config[setting.key] = JSON.parse(setting.value);
        } catch {
          // If not JSON, use as string
          config[setting.key] = setting.value;
        }
      });

      ctx.body = {
        success: true,
        config
      };
    } catch (error) {
      ctx.status = 500;
      ctx.body = { error: error.message };
      global.log.err('GET_CONFIG_ERROR', 'Failed to retrieve config settings', error);
    }
  }
}

module.exports = new SettingsController();