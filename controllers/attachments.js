const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');
const sharp = require('sharp');
const { TransactionAttachment, HouseholdMember } = require('../models');

const ATTACHMENTS_DIR = path.join(__dirname, '../public/attachments');
const THUMBS_DIR = path.join(ATTACHMENTS_DIR, 'thumbs');

const ALLOWED_MIME_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'image/heif',
  'application/pdf'
]);

const IMAGE_MIME_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'image/heif'
]);

/**
 * Build public URLs for file and thumbnail based on request context.
 */
function buildUrls(ctx, attachment) {
  const base = `${ctx.protocol}://${ctx.host}`;
  return {
    fileUrl:  `${base}/api/app/attachments/${attachment.id}/file`,
    thumbUrl: attachment.isImage ? `${base}/api/app/attachments/${attachment.id}/thumb` : null
  };
}

/**
 * Format a TransactionAttachment for API responses.
 */
function formatAttachment(ctx, attachment) {
  const obj = attachment.toJSON ? attachment.toJSON() : attachment;
  const urls = buildUrls(ctx, obj);
  return {
    id:               obj.id,
    expenseId:        obj.expenseId,
    incomeId:         obj.incomeId,
    householdId:      obj.householdId,
    appUserId:        obj.appUserId,
    filename:         obj.filename,
    originalFilename: obj.originalFilename,
    mimeType:         obj.mimeType,
    size:             obj.size,
    isImage:          obj.isImage,
    createdAt:        obj.createdAt,
    updatedAt:        obj.updatedAt,
    fileUrl:          urls.fileUrl,
    thumbUrl:         urls.thumbUrl
  };
}

/**
 * Ensure directory exists.
 */
function ensureDir(dir) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

/**
 * Safely unlink a file, ignoring errors if the file does not exist.
 */
function safeUnlink(filePath) {
  if (!filePath) return;
  try {
    fs.unlinkSync(filePath);
  } catch (_) {
    // file may already be gone
  }
}

class AttachmentsController {
  /**
   * GET /api/app/attachments?expenseId=…
   * GET /api/app/attachments?incomeId=…
   * GET /api/app/attachments/household/:householdId
   */
  async list(ctx) {
    try {
      const appUserId = ctx.state.appUser.id;
      const { expenseId, incomeId, householdId } = ctx.request.query;

      // At least one filter is required
      if (!expenseId && !incomeId && !householdId) {
        ctx.status = 400;
        ctx.body = { error: 'expenseId, incomeId, or householdId query param is required' };
        return;
      }

      // Determine the householdId to verify membership
      let resolvedHouseholdId = householdId ? Number(householdId) : null;

      if (!resolvedHouseholdId && (expenseId || incomeId)) {
        // Look up the household from an existing attachment or just query with household filter after auth
        // We'll fetch one row to find the householdId
        const sample = await TransactionAttachment.findOne({
          where: expenseId ? { expenseId: Number(expenseId) } : { incomeId: Number(incomeId) },
          attributes: ['householdId']
        });
        if (sample) {
          resolvedHouseholdId = sample.householdId;
        }
      }

      if (resolvedHouseholdId) {
        const membership = await HouseholdMember.findOne({
          where: { householdId: resolvedHouseholdId, appUserId }
        });
        if (!membership) {
          ctx.status = 403;
          ctx.body = { error: 'You are not a member of this household' };
          return;
        }
      }

      const where = {};
      if (expenseId)   where.expenseId   = Number(expenseId);
      if (incomeId)    where.incomeId    = Number(incomeId);
      if (householdId) where.householdId = Number(householdId);

      const rows = await TransactionAttachment.findAll({
        where,
        order: [['createdAt', 'ASC']]
      });

      ctx.body = {
        success:     true,
        attachments: rows.map(r => formatAttachment(ctx, r))
      };
    } catch (error) {
      console.error('Attachments list error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to fetch attachments' };
    }
  }

  /**
   * GET /api/app/attachments/household/:householdId
   * Dedicated route for listing all attachments for a household.
   */
  async listByHousehold(ctx) {
    try {
      const appUserId = ctx.state.appUser.id;
      const householdId = Number(ctx.params.householdId);

      const membership = await HouseholdMember.findOne({
        where: { householdId, appUserId }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'You are not a member of this household' };
        return;
      }

      const rows = await TransactionAttachment.findAll({
        where: { householdId },
        order: [['createdAt', 'DESC']]
      });

      ctx.body = {
        success:     true,
        attachments: rows.map(r => formatAttachment(ctx, r))
      };
    } catch (error) {
      console.error('Attachments listByHousehold error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to fetch attachments' };
    }
  }

  /**
   * POST /api/app/attachments
   * Multipart upload — multer puts file in ctx.file (memoryStorage).
   *
   * Body fields: expenseId OR incomeId (at least one), householdId
   */
  async create(ctx) {
    try {
      const appUserId = ctx.state.appUser.id;
      const file = ctx.file;

      console.log('[Attachments] create called — appUserId:', appUserId,
        '| file:', file ? `${file.originalname} (${file.mimetype}, ${file.size}B)` : 'MISSING',
        '| body:', JSON.stringify(ctx.request.body));

      if (!file) {
        console.warn('[Attachments] create rejected: no file in request');
        ctx.status = 400;
        ctx.body = { error: 'No file uploaded. Use field name "file".' };
        return;
      }

      // Validate MIME type
      if (!ALLOWED_MIME_TYPES.has(file.mimetype)) {
        console.warn('[Attachments] create rejected: unsupported MIME type:', file.mimetype);
        ctx.status = 415;
        ctx.body = {
          error: `Unsupported file type "${file.mimetype}". Allowed: image/jpeg, image/png, image/webp, image/heic, image/heif, application/pdf`
        };
        return;
      }

      const { expenseId, incomeId, householdId } = ctx.request.body;

      if (!householdId) {
        console.warn('[Attachments] create rejected: missing householdId');
        ctx.status = 400;
        ctx.body = { error: 'householdId is required' };
        return;
      }

      if (!expenseId && !incomeId) {
        console.warn('[Attachments] create rejected: missing expenseId and incomeId');
        ctx.status = 400;
        ctx.body = { error: 'expenseId or incomeId is required' };
        return;
      }

      // Verify household membership
      const membership = await HouseholdMember.findOne({
        where: { householdId: Number(householdId), appUserId }
      });
      if (!membership) {
        console.warn('[Attachments] create rejected: user', appUserId, 'not in household', householdId);
        ctx.status = 403;
        ctx.body = { error: 'You are not a member of this household' };
        return;
      }

      // Determine extension from MIME type
      const mimeToExt = {
        'image/jpeg':    'jpg',
        'image/png':     'png',
        'image/webp':    'webp',
        'image/heic':    'heic',
        'image/heif':    'heif',
        'application/pdf': 'pdf'
      };
      const ext = mimeToExt[file.mimetype] || 'bin';

      const uuid = uuidv4();
      const storedFilename = `${uuid}.${ext}`;
      const householdDir = path.join(ATTACHMENTS_DIR, String(householdId));

      ensureDir(householdDir);

      const storagePath = path.join(householdDir, storedFilename);
      fs.writeFileSync(storagePath, file.buffer);
      console.log('[Attachments] file saved to disk:', storagePath);

      // Generate thumbnail if image
      const isImage = IMAGE_MIME_TYPES.has(file.mimetype);
      let thumbnailPath = null;

      if (isImage) {
        ensureDir(THUMBS_DIR);
        thumbnailPath = path.join(THUMBS_DIR, `${uuid}.jpg`);
        try {
          await sharp(file.buffer)
            .resize(256, 256, { fit: 'inside', withoutEnlargement: true })
            .jpeg({ quality: 80 })
            .toFile(thumbnailPath);
          console.log('[Attachments] thumbnail created:', thumbnailPath);
        } catch (thumbErr) {
          console.warn('[Attachments] Thumbnail generation failed:', thumbErr.message);
          thumbnailPath = null;
        }
      }

      const attachment = await TransactionAttachment.create({
        expenseId:        expenseId  ? Number(expenseId)  : null,
        incomeId:         incomeId   ? Number(incomeId)   : null,
        householdId:      Number(householdId),
        appUserId,
        filename:         storedFilename,
        originalFilename: file.originalname || null,
        mimeType:         file.mimetype,
        size:             file.size,
        storagePath,
        thumbnailPath,
        isImage
      });

      console.log('[Attachments] created id:', attachment.id,
        '| expenseId:', expenseId, '| incomeId:', incomeId, '| isImage:', isImage);

      ctx.status = 201;
      ctx.body = {
        success:    true,
        attachment: formatAttachment(ctx, attachment)
      };
    } catch (error) {
      console.error('Attachments create error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to upload attachment' };
    }
  }

  /**
   * PUT /api/app/attachments/:id
   * Rename (update display filename).
   *
   * Body: { filename }
   */
  async rename(ctx) {
    try {
      const appUserId = ctx.state.appUser.id;
      const { id } = ctx.params;
      const { filename } = ctx.request.body;

      if (!filename) {
        ctx.status = 400;
        ctx.body = { error: 'filename is required' };
        return;
      }

      const attachment = await TransactionAttachment.findByPk(id);
      if (!attachment) {
        ctx.status = 404;
        ctx.body = { error: 'Attachment not found' };
        return;
      }

      // Verify household membership
      const membership = await HouseholdMember.findOne({
        where: { householdId: attachment.householdId, appUserId }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'You are not a member of this household' };
        return;
      }

      await attachment.update({ filename: String(filename) });

      ctx.body = {
        success:    true,
        attachment: formatAttachment(ctx, attachment)
      };
    } catch (error) {
      console.error('Attachments rename error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to rename attachment' };
    }
  }

  /**
   * DELETE /api/app/attachments/:id
   * Remove DB row and unlink files from disk.
   */
  async delete(ctx) {
    try {
      const appUserId = ctx.state.appUser.id;
      const { id } = ctx.params;

      const attachment = await TransactionAttachment.findByPk(id);
      if (!attachment) {
        ctx.status = 404;
        ctx.body = { error: 'Attachment not found' };
        return;
      }

      // Verify household membership
      const membership = await HouseholdMember.findOne({
        where: { householdId: attachment.householdId, appUserId }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'You are not a member of this household' };
        return;
      }

      // Remove files from disk
      safeUnlink(attachment.storagePath);
      safeUnlink(attachment.thumbnailPath);

      await attachment.destroy();

      ctx.body = { success: true };
    } catch (error) {
      console.error('Attachments delete error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to delete attachment' };
    }
  }

  /**
   * GET /api/app/attachments/:id/file
   * Stream the original file to the client.
   */
  async streamFile(ctx) {
    try {
      const appUserId = ctx.state.appUser.id;
      const { id } = ctx.params;

      const attachment = await TransactionAttachment.findByPk(id);
      if (!attachment) {
        ctx.status = 404;
        ctx.body = { error: 'Attachment not found' };
        return;
      }

      // Verify household membership
      const membership = await HouseholdMember.findOne({
        where: { householdId: attachment.householdId, appUserId }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'You are not a member of this household' };
        return;
      }

      if (!attachment.storagePath || !fs.existsSync(attachment.storagePath)) {
        ctx.status = 404;
        ctx.body = { error: 'File not found on disk' };
        return;
      }

      ctx.set('Content-Type', attachment.mimeType || 'application/octet-stream');
      ctx.set('Content-Disposition', `inline; filename="${attachment.originalFilename || attachment.filename}"`);
      ctx.body = fs.createReadStream(attachment.storagePath);
    } catch (error) {
      console.error('Attachments streamFile error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to stream file' };
    }
  }

  /**
   * GET /api/app/attachments/:id/thumb
   * Stream the thumbnail (JPEG, 256x256) to the client.
   * Only available for image attachments.
   */
  async streamThumb(ctx) {
    try {
      const appUserId = ctx.state.appUser.id;
      const { id } = ctx.params;

      const attachment = await TransactionAttachment.findByPk(id);
      if (!attachment) {
        ctx.status = 404;
        ctx.body = { error: 'Attachment not found' };
        return;
      }

      // Verify household membership
      const membership = await HouseholdMember.findOne({
        where: { householdId: attachment.householdId, appUserId }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'You are not a member of this household' };
        return;
      }

      if (!attachment.isImage) {
        ctx.status = 400;
        ctx.body = { error: 'Thumbnail not available for non-image attachments' };
        return;
      }

      if (!attachment.thumbnailPath || !fs.existsSync(attachment.thumbnailPath)) {
        // Fall back to the original file if thumbnail is missing
        if (attachment.storagePath && fs.existsSync(attachment.storagePath)) {
          ctx.set('Content-Type', attachment.mimeType || 'image/jpeg');
          ctx.body = fs.createReadStream(attachment.storagePath);
          return;
        }
        ctx.status = 404;
        ctx.body = { error: 'Thumbnail not found' };
        return;
      }

      ctx.set('Content-Type', 'image/jpeg');
      ctx.body = fs.createReadStream(attachment.thumbnailPath);
    } catch (error) {
      console.error('Attachments streamThumb error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to stream thumbnail' };
    }
  }
}

/**
 * Delete all attachment files from disk for the given expenseIds or incomeIds.
 * Used by the expenses/incomes delete handlers before destroying DB rows.
 *
 * @param {number[]} expenseIds
 * @param {number[]} incomeIds
 */
async function deleteAttachmentFilesForTransactions({ expenseIds = [], incomeIds = [] }) {
  const { Op } = require('sequelize');
  const where = {};
  const conditions = [];
  if (expenseIds.length) conditions.push({ expenseId: { [Op.in]: expenseIds } });
  if (incomeIds.length)  conditions.push({ incomeId:  { [Op.in]: incomeIds } });
  if (!conditions.length) return;

  where[Op.or] = conditions;

  const rows = await TransactionAttachment.findAll({ where, attributes: ['storagePath', 'thumbnailPath'] });
  for (const row of rows) {
    safeUnlink(row.storagePath);
    safeUnlink(row.thumbnailPath);
  }
}

module.exports = new AttachmentsController();
module.exports.deleteAttachmentFilesForTransactions = deleteAttachmentFilesForTransactions;
