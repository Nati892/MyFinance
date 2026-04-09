const path = require('path');
const fs = require('fs');
const { ApkRelease } = require('../models');

const APK_DIR = path.join(__dirname, '../public/apk');

class ApkController {
  /**
   * POST /api/apk/upload
   * Protected by managerAuth + multer memoryStorage.
   * Accepts a single file field named "apk".
   */
  async upload(ctx) {
    try {
      const file = ctx.file;
      if (!file) {
        ctx.status = 400;
        ctx.body = { error: 'No file uploaded. Use field name "apk".' };
        return;
      }

      // Determine next version
      const latest = await ApkRelease.findOne({ order: [['version', 'DESC']] });
      const nextVersion = latest ? latest.version + 1 : 1;
      const filename = `app_v${nextVersion}.apk`;
      const destPath = path.join(APK_DIR, filename);

      // Ensure directory exists
      if (!fs.existsSync(APK_DIR)) {
        fs.mkdirSync(APK_DIR, { recursive: true });
      }

      // Write buffer to disk
      fs.writeFileSync(destPath, file.buffer);

      await ApkRelease.create({ version: nextVersion, filename });

      console.log(`[APK] Uploaded version ${nextVersion} (${filename})`);

      ctx.status = 201;
      ctx.body = { success: true, version: nextVersion, filename };
    } catch (error) {
      console.error('APK upload error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to upload APK' };
    }
  }

  /**
   * GET /api/apk/latest
   * Protected by authenticateApp.
   * Returns the latest APK version and download URL.
   */
  async latest(ctx) {
    try {
      const release = await ApkRelease.findOne({ order: [['version', 'DESC']] });
      if (!release) {
        ctx.status = 404;
        ctx.body = { error: 'No APK available' };
        return;
      }

      const baseUrl = `${ctx.protocol}://${ctx.host}`;
      ctx.body = {
        success: true,
        version: release.version,
        filename: release.filename,
        downloadUrl: `${baseUrl}/apk/${release.filename}`
      };
    } catch (error) {
      console.error('APK latest error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to fetch latest APK info' };
    }
  }
}

module.exports = new ApkController();
