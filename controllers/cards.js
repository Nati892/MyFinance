const { Card, HouseholdMember } = require('../models');

class CardsController {
  /**
   * GET /api/app/cards?householdId=X
   * Returns all cards for the household.
   */
  async list(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { householdId } = ctx.query;

      if (!householdId) {
        ctx.status = 400;
        ctx.body = { error: 'householdId query parameter is required' };
        return;
      }

      const membership = await HouseholdMember.findOne({
        where: { householdId: Number(householdId), appUserId: appUser.id }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'Not a member of this household' };
        return;
      }

      const cards = await Card.findAll({
        where: { householdId: Number(householdId) },
        order: [['createdAt', 'ASC']]
      });

      ctx.body = { success: true, cards };
    } catch (error) {
      console.error('Cards list error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to retrieve cards' };
    }
  }

  /**
   * POST /api/app/cards
   * Body: { lastFourDigits, nickname, bankName, cardType, householdId }
   */
  async create(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { lastFourDigits, nickname, bankName, cardType, householdId } = ctx.request.body;

      if (!lastFourDigits || !householdId) {
        ctx.status = 400;
        ctx.body = { error: 'lastFourDigits and householdId are required' };
        return;
      }

      if (!/^\d{4}$/.test(lastFourDigits)) {
        ctx.status = 400;
        ctx.body = { error: 'lastFourDigits must be exactly 4 digits' };
        return;
      }

      const membership = await HouseholdMember.findOne({
        where: { householdId: Number(householdId), appUserId: appUser.id }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'Not a member of this household' };
        return;
      }

      const card = await Card.create({
        lastFourDigits,
        nickname: nickname || null,
        bankName: bankName || null,
        cardType: cardType || null,
        householdId: Number(householdId)
      });

      ctx.status = 201;
      ctx.body = { success: true, card };
    } catch (error) {
      console.error('Cards create error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to create card' };
    }
  }

  /**
   * PUT /api/app/cards/:id
   * Body: { lastFourDigits, nickname, bankName, cardType }
   */
  async update(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;

      const card = await Card.findByPk(id);
      if (!card) {
        ctx.status = 404;
        ctx.body = { error: 'Card not found' };
        return;
      }

      const membership = await HouseholdMember.findOne({
        where: { householdId: card.householdId, appUserId: appUser.id }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'Not a member of this household' };
        return;
      }

      const { lastFourDigits, nickname, bankName, cardType } = ctx.request.body;

      if (lastFourDigits !== undefined && !/^\d{4}$/.test(lastFourDigits)) {
        ctx.status = 400;
        ctx.body = { error: 'lastFourDigits must be exactly 4 digits' };
        return;
      }

      await card.update({
        lastFourDigits: lastFourDigits !== undefined ? lastFourDigits : card.lastFourDigits,
        nickname:       nickname       !== undefined ? nickname       : card.nickname,
        bankName:       bankName       !== undefined ? bankName       : card.bankName,
        cardType:       cardType       !== undefined ? cardType       : card.cardType
      });

      ctx.body = { success: true, card };
    } catch (error) {
      console.error('Cards update error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to update card' };
    }
  }

  /**
   * DELETE /api/app/cards/:id
   */
  async delete(ctx) {
    try {
      const appUser = ctx.state.appUser;
      const { id } = ctx.params;

      const card = await Card.findByPk(id);
      if (!card) {
        ctx.status = 404;
        ctx.body = { error: 'Card not found' };
        return;
      }

      const membership = await HouseholdMember.findOne({
        where: { householdId: card.householdId, appUserId: appUser.id }
      });
      if (!membership) {
        ctx.status = 403;
        ctx.body = { error: 'Not a member of this household' };
        return;
      }

      await card.destroy();
      ctx.body = { success: true };
    } catch (error) {
      console.error('Cards delete error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to delete card' };
    }
  }
  // ── Admin methods ──────────────────────────────────────────────────────────

  /**
   * GET /api/admin/cards?householdId=X
   */
  async adminList(ctx) {
    try {
      const { householdId } = ctx.query;
      if (!householdId) {
        ctx.status = 400;
        ctx.body = { error: 'householdId is required' };
        return;
      }
      const cards = await Card.findAll({
        where: { householdId: Number(householdId) },
        order: [['createdAt', 'ASC']]
      });
      ctx.body = { success: true, cards };
    } catch (error) {
      console.error('Admin cards list error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to retrieve cards' };
    }
  }

  /**
   * POST /api/admin/cards
   */
  async adminCreate(ctx) {
    try {
      const { lastFourDigits, nickname, bankName, cardType, householdId } = ctx.request.body;
      if (!lastFourDigits || !householdId) {
        ctx.status = 400;
        ctx.body = { error: 'lastFourDigits and householdId are required' };
        return;
      }
      if (!/^\d{4}$/.test(lastFourDigits)) {
        ctx.status = 400;
        ctx.body = { error: 'lastFourDigits must be exactly 4 digits' };
        return;
      }
      const card = await Card.create({
        lastFourDigits,
        nickname: nickname || null,
        bankName: bankName || null,
        cardType: cardType || null,
        householdId: Number(householdId)
      });
      ctx.status = 201;
      ctx.body = { success: true, card };
    } catch (error) {
      console.error('Admin cards create error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to create card' };
    }
  }

  /**
   * PUT /api/admin/cards/:id
   */
  async adminUpdate(ctx) {
    try {
      const { id } = ctx.params;
      const card = await Card.findByPk(id);
      if (!card) {
        ctx.status = 404;
        ctx.body = { error: 'Card not found' };
        return;
      }
      const { lastFourDigits, nickname, bankName, cardType } = ctx.request.body;
      if (lastFourDigits !== undefined && !/^\d{4}$/.test(lastFourDigits)) {
        ctx.status = 400;
        ctx.body = { error: 'lastFourDigits must be exactly 4 digits' };
        return;
      }
      await card.update({
        lastFourDigits: lastFourDigits !== undefined ? lastFourDigits : card.lastFourDigits,
        nickname:       nickname       !== undefined ? nickname       : card.nickname,
        bankName:       bankName       !== undefined ? bankName       : card.bankName,
        cardType:       cardType       !== undefined ? cardType       : card.cardType
      });
      ctx.body = { success: true, card };
    } catch (error) {
      console.error('Admin cards update error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to update card' };
    }
  }

  /**
   * DELETE /api/admin/cards/:id
   */
  async adminDelete(ctx) {
    try {
      const { id } = ctx.params;
      const card = await Card.findByPk(id);
      if (!card) {
        ctx.status = 404;
        ctx.body = { error: 'Card not found' };
        return;
      }
      await card.destroy();
      ctx.body = { success: true };
    } catch (error) {
      console.error('Admin cards delete error:', error);
      ctx.status = 500;
      ctx.body = { error: 'Failed to delete card' };
    }
  }
}

module.exports = new CardsController();
