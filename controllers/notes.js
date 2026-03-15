const { Note, HouseholdMember, AppUser } = require('../models');
const { getIO } = require('../utils/socket');

class NotesController {
  /**
   * GET /api/app/notes?householdId=X
   * Returns all notes for the household (shared wall).
   */
  async list(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { householdId } = ctx.query;

      if (!householdId) {
        ctx.status = 400;
        ctx.body = { error: 'householdId is required' };
        return;
      }

      const membership = await HouseholdMember.findOne({
        where: { householdId, appUserId: appUser.id }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'Not a member of this household' };
        return;
      }

      const notes = await Note.findAll({
        where: { householdId },
        include: [{ model: AppUser, attributes: ['id', 'username'] }],
        order: [['zIndex', 'ASC']]
      });

      ctx.body = { success: true, notes };
    } catch (error) {
      console.error('Notes list error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to retrieve notes' };
    }
  }

  /**
   * POST /api/app/notes
   * Body: { content, posX, posY, zIndex, householdId }
   */
  async create(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { content, posX, posY, zIndex, householdId } = ctx.request.body;

      if (!householdId) {
        ctx.status = 400;
        ctx.body = { error: 'householdId is required' };
        return;
      }

      const membership = await HouseholdMember.findOne({
        where: { householdId, appUserId: appUser.id }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'Not a member of this household' };
        return;
      }

      const note = await Note.create({
        content: content || '',
        posX: posX ?? 50,
        posY: posY ?? 50,
        zIndex: zIndex ?? 1,
        householdId,
        appUserId: appUser.id
      });

      const noteWithUser = await Note.findByPk(note.id, {
        include: [{ model: AppUser, attributes: ['id', 'username'] }]
      });

      const io = getIO();
      if (io) {
        io.to(`household:${householdId}`).emit('note:created', noteWithUser);
      }

      ctx.status = 201;
      ctx.body = { success: true, note: noteWithUser };
    } catch (error) {
      console.error('Notes create error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to create note' };
    }
  }

  /**
   * PUT /api/app/notes/:id
   * Body: { content, posX, posY, zIndex }
   */
  async update(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;
      const { content, posX, posY, zIndex } = ctx.request.body;

      const note = await Note.findByPk(id);
      if (!note) {
        ctx.status = 404;
        ctx.body = { error: 'Note not found' };
        return;
      }

      const membership = await HouseholdMember.findOne({
        where: { householdId: note.householdId, appUserId: appUser.id }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'Not a member of this household' };
        return;
      }

      const updates = {};
      if (content !== undefined) updates.content = content;
      if (posX !== undefined) updates.posX = posX;
      if (posY !== undefined) updates.posY = posY;
      if (zIndex !== undefined) updates.zIndex = zIndex;

      await note.update(updates);

      const updatedNote = await Note.findByPk(id, {
        include: [{ model: AppUser, attributes: ['id', 'username'] }]
      });

      const io = getIO();
      if (io) {
        io.to(`household:${note.householdId}`).emit('note:updated', updatedNote);
      }

      ctx.body = { success: true, note: updatedNote };
    } catch (error) {
      console.error('Notes update error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to update note' };
    }
  }

  /**
   * DELETE /api/app/notes/:id
   */
  async delete(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;

      const note = await Note.findByPk(id);
      if (!note) {
        ctx.status = 404;
        ctx.body = { error: 'Note not found' };
        return;
      }

      const membership = await HouseholdMember.findOne({
        where: { householdId: note.householdId, appUserId: appUser.id }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'Not a member of this household' };
        return;
      }

      const householdId = note.householdId;
      await note.destroy();

      const io = getIO();
      if (io) {
        io.to(`household:${householdId}`).emit('note:deleted', Number(id));
      }

      ctx.body = { success: true };
    } catch (error) {
      console.error('Notes delete error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to delete note' };
    }
  }
}

module.exports = new NotesController();
