const { Expense, ExpenseCategory, AppUser, Household, HouseholdMember, Card, RecurringExpense, TransactionAttachment, sequelize } = require('../models');
const { Op } = require('sequelize');
const { deleteAttachmentFilesForTransactions } = require('./attachments');
const {
  getCurrentFinancialPeriod,
  getFinancialPeriod,
  getCalendarMonthPeriod,
  getFinancialWeeks,
  getHourlySlots,
  getDailySlots
} = require('../utils/financialCalendar');

/**
 * Create one Expense row (or a chain of installment rows).
 * Shared by the HTTP `create` handler and by shopping-session completion.
 *
 * Returns the first Expense (the head of the installment chain), reloaded
 * with ExpenseCategory + AppUser includes.
 */
async function createExpenseRecord({
  amount,
  dateTime,
  description,
  note,
  paymentMethod,
  cardId,
  expenseCategoryId,
  householdId,
  appUserId,
  installmentTotal,
  installmentCurrent
}) {
  const total   = installmentTotal && Number(installmentTotal) > 1 ? Number(installmentTotal) : null;
  const current = total ? (installmentCurrent ? Number(installmentCurrent) : 1) : null;

  let firstExpense;
  let parentId = null;
  if (total && total > 1) {
    const baseDate = new Date(dateTime);
    for (let i = 0; i < total; i++) {
      const paymentDate = new Date(baseDate);
      paymentDate.setMonth(paymentDate.getMonth() + i);
      const rec = await Expense.create({
        amount,
        dateTime:           paymentDate.toISOString(),
        description:        description || null,
        note:               note        || null,
        paymentMethod,
        cardId:             cardId ? Number(cardId) : null,
        expenseCategoryId:  Number(expenseCategoryId),
        appUserId,
        householdId:        Number(householdId),
        installmentTotal:   total,
        installmentCurrent: current + i,
        parentExpenseId:    i === 0 ? null : parentId
      });
      if (i === 0) {
        firstExpense = rec;
        parentId = rec.id;
      }
    }
  } else {
    firstExpense = await Expense.create({
      amount,
      dateTime,
      description: description || null,
      note:        note        || null,
      paymentMethod,
      cardId:      cardId ? Number(cardId) : null,
      expenseCategoryId: Number(expenseCategoryId),
      appUserId,
      householdId: Number(householdId),
      installmentTotal:  null,
      installmentCurrent: null
    });
  }

  return Expense.findByPk(firstExpense.id, {
    include: [
      { model: ExpenseCategory, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] },
      { model: AppUser,         attributes: ['id', 'username'] },
      {
        model:    TransactionAttachment,
        as:       'attachments',
        attributes: ['id', 'filename', 'originalFilename', 'mimeType', 'size', 'isImage', 'createdAt'],
        required: false
      }
    ]
  });
}

/**
 * Given a recurring expense's dayOfMonth and the full financial period,
 * returns the Date when it occurs within that period, or null if it doesn't.
 */
function getRecurringOccurrence(dayOfMonth, period) {
  // Try the first calendar month of the period (period.start month)
  const startYear  = period.start.getFullYear();
  const startMonth = period.start.getMonth();
  const d1 = new Date(startYear, startMonth, dayOfMonth, 12, 0, 0, 0);
  if (d1 >= period.start && d1 <= period.end) return d1;

  // Try the second calendar month of the period (period.end month)
  const endYear  = period.end.getFullYear();
  const endMonth = period.end.getMonth();
  const d2 = new Date(endYear, endMonth, dayOfMonth, 12, 0, 0, 0);
  if (d2 >= period.start && d2 <= period.end) return d2;

  return null;
}

class ExpensesController {
  /**
   * GET /api/app/expenses
   * List expenses for a household with financial-calendar scoping.
   *
   * Query params:
   *   householdId   (required)
   *   view          'hourly' | 'daily' | 'weekly' | 'monthly'  (default 'monthly')
   *   periodOffset  integer  (default 0)
   *   weekNumber    1-5  (required for hourly / daily views)
   *   date          ISO string  (required for hourly view)
   *   categoryId    optional filter
   */
  async list(ctx) {
    try {
      const {
        householdId,
        view          = 'monthly',
        periodOffset  = 0,
        periodType    = 'financial',
        weekNumber,
        date,
        categoryId
      } = ctx.request.query;

      // --- Validate householdId ---
      if (!householdId) {
        ctx.status = 400;
        ctx.body   = { error: 'householdId is required' };
        return;
      }

      // --- Verify user is a member of the household ---
      const appUserId  = ctx.state.appUser.id;
      const membership = await HouseholdMember.findOne({
        where: { householdId: Number(householdId), appUserId }
      });

      if (!membership) {
        ctx.status = 403;
        ctx.body   = { error: 'You are not a member of this household' };
        return;
      }

      // --- Resolve the financial period ---
      const offset = parseInt(periodOffset, 10) || 0;
      const household = await Household.findByPk(Number(householdId), {
        attributes: ['id', 'financialMonthStartDay']
      });
      const startDay = household?.financialMonthStartDay ?? 10;
      const period = periodType === 'calendar'
        ? getCalendarMonthPeriod(offset)
        : getFinancialPeriod(offset, startDay);
      const weeks  = getFinancialWeeks(period);

      // --- Build date range based on view ---
      let dateStart = period.start;
      let dateEnd   = period.end;
      let slots     = null;

      if (view === 'weekly') {
        // Use the full financial period; no weekNumber required for this view
        // dateStart and dateEnd already set to period.start / period.end

      } else if (view === 'daily') {
        if (!date) {
          ctx.status = 400;
          ctx.body   = { error: 'date is required for daily view' };
          return;
        }
        const targetDate = new Date(date);
        if (isNaN(targetDate.getTime())) {
          ctx.status = 400;
          ctx.body   = { error: 'date is not a valid ISO date string' };
          return;
        }
        dateStart = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 0, 0, 0, 0);
        dateEnd   = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 23, 59, 59, 999);

      } else if (view === 'hourly') {
        if (!date) {
          ctx.status = 400;
          ctx.body   = { error: 'date is required for hourly view' };
          return;
        }
        const targetDate = new Date(date);
        if (isNaN(targetDate.getTime())) {
          ctx.status = 400;
          ctx.body   = { error: 'date is not a valid ISO date string' };
          return;
        }
        dateStart = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 0, 0, 0, 0);
        dateEnd   = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate(), 23, 59, 59, 999);
        slots     = getHourlySlots(targetDate);
      }

      // --- Build where clause ---
      const where = {
        householdId: Number(householdId),
        dateTime: {
          [Op.between]: [dateStart, dateEnd]
        }
      };

      if (categoryId) {
        where.expenseCategoryId = Number(categoryId);
      }

      // --- Fetch regular expenses ---
      const expenses = await Expense.findAll({
        where,
        include: [
          {
            model:      ExpenseCategory,
            attributes: ['id', 'name', 'nameHe', 'icon', 'color']
          },
          {
            model:      AppUser,
            attributes: ['id', 'username']
          },
          {
            model:      Card,
            as:         'card',
            attributes: ['id', 'lastFourDigits', 'nickname', 'bankName', 'cardType'],
            required:   false
          },
          {
            model:      TransactionAttachment,
            as:         'attachments',
            attributes: ['id', 'filename', 'originalFilename', 'mimeType', 'size', 'isImage', 'createdAt'],
            required:   false
          }
        ],
        order: [['dateTime', 'DESC']]
      });

      // --- Fetch and merge recurring expenses ---
      const allRecurring = await RecurringExpense.findAll({
        where: { householdId: Number(householdId), isActive: true },
        include: [
          { model: ExpenseCategory, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] },
          { model: AppUser,         attributes: ['id', 'username'] }
        ]
      });

      const recurringEntries = [];
      for (const rec of allRecurring) {
        const occurrenceDate = getRecurringOccurrence(rec.dayOfMonth, period);
        if (!occurrenceDate) continue;

        // Check it falls within the (potentially narrower) sub-period window
        if (occurrenceDate < dateStart || occurrenceDate > dateEnd) continue;

        // Check startYear/startMonth <= occurrence calendar month
        const occYear  = occurrenceDate.getFullYear();
        const occMonth = occurrenceDate.getMonth() + 1; // 1-based
        if (rec.startYear > occYear || (rec.startYear === occYear && rec.startMonth > occMonth)) continue;

        const r = rec.toJSON();
        recurringEntries.push({
          ...r,
          dateTime:           occurrenceDate.toISOString(),
          isRecurring:        true,
          recurringExpenseId: r.id,
          // Reshape associations to match Expense format expected by Flutter
          ExpenseCategory: r.ExpenseCategory,
          AppUser:         r.AppUser,
          card:            null,
          cardId:          null,
          installmentTotal:   null,
          installmentCurrent: null,
          parentExpenseId:    null
        });
      }

      const baseUrl = `${ctx.protocol}://${ctx.host}`;

      function enrichAttachments(expenseObj) {
        if (!Array.isArray(expenseObj.attachments)) {
          expenseObj.attachments = [];
        }
        expenseObj.attachments = expenseObj.attachments.map(a => ({
          ...a,
          fileUrl:  `${baseUrl}/api/app/attachments/${a.id}/file`,
          thumbUrl: a.isImage ? `${baseUrl}/api/app/attachments/${a.id}/thumb` : null
        }));
        expenseObj.attachmentCount = expenseObj.attachments.length;
        return expenseObj;
      }

      const allExpenses = [
        ...expenses.map(e => enrichAttachments(e.toJSON())),
        ...recurringEntries.map(r => ({ ...r, attachments: [], attachmentCount: 0 }))
      ].sort((a, b) => new Date(b.dateTime) - new Date(a.dateTime));

      // --- Compute total ---
      const totalAmount = allExpenses.reduce((sum, e) => sum + parseFloat(e.amount), 0);

      // --- Build response ---
      const response = {
        success:     true,
        expenses:    allExpenses,
        period:      { start: period.start, end: period.end, label: period.label },
        totalAmount: Math.round(totalAmount * 100) / 100
      };

      if (view === 'monthly' || view === 'weekly') {
        response.weeks = weeks;
      }

      if (slots) {
        response.slots = slots;
      }

      ctx.body = response;

    } catch (error) {
      console.error('Expenses list error:', error);
      ctx.status = 500;
      ctx.body   = { error: 'Failed to fetch expenses' };
    }
  }

  /**
   * POST /api/app/expenses
   * Create a new expense transaction.
   *
   * Body: { amount, dateTime, description, note, paymentMethod, expenseCategoryId, householdId }
   */
  async create(ctx) {
    try {
      const {
        amount,
        dateTime,
        description,
        note,
        paymentMethod,
        cardId,
        expenseCategoryId,
        householdId,
        installmentTotal,
        installmentCurrent
      } = ctx.request.body;

      // --- Required fields ---
      if (!amount || !dateTime || !expenseCategoryId || !householdId) {
        ctx.status = 400;
        ctx.body   = { error: 'amount, dateTime, expenseCategoryId, and householdId are required' };
        return;
      }

      // --- Verify user is a member of the household ---
      const appUserId  = ctx.state.appUser.id;
      const membership = await HouseholdMember.findOne({
        where: { householdId: Number(householdId), appUserId }
      });

      if (!membership) {
        ctx.status = 403;
        ctx.body   = { error: 'You are not a member of this household' };
        return;
      }

      // --- Validate category belongs to household ---
      const category = await ExpenseCategory.findOne({
        where: { id: Number(expenseCategoryId), householdId: Number(householdId) }
      });

      if (!category) {
        ctx.status = 400;
        ctx.body   = { error: 'Invalid expenseCategoryId for this household' };
        return;
      }

      const created = await createExpenseRecord({
        amount,
        dateTime,
        description,
        note,
        paymentMethod,
        cardId,
        expenseCategoryId,
        householdId,
        appUserId,
        installmentTotal,
        installmentCurrent
      });

      const baseUrl = `${ctx.protocol}://${ctx.host}`;
      const expenseJson = created.toJSON();
      if (!Array.isArray(expenseJson.attachments)) expenseJson.attachments = [];
      expenseJson.attachments = expenseJson.attachments.map(a => ({
        ...a,
        fileUrl:  `${baseUrl}/api/app/attachments/${a.id}/file`,
        thumbUrl: a.isImage ? `${baseUrl}/api/app/attachments/${a.id}/thumb` : null
      }));
      expenseJson.attachmentCount = expenseJson.attachments.length;

      ctx.status = 201;
      ctx.body   = { success: true, expense: expenseJson };

    } catch (error) {
      console.error('Expenses create error:', error);
      ctx.status = 500;
      ctx.body   = { error: 'Failed to create expense' };
    }
  }

  /**
   * PUT /api/app/expenses/:id
   * Update an existing expense (only the creator can update).
   *
   * Body: { amount, dateTime, description, note, paymentMethod, expenseCategoryId }
   */
  async update(ctx) {
    try {
      const { id }   = ctx.params;
      const appUserId = ctx.state.appUser.id;

      const expense = await Expense.findByPk(id);

      if (!expense) {
        ctx.status = 404;
        ctx.body   = { error: 'Expense not found' };
        return;
      }

      if (expense.appUserId !== appUserId) {
        ctx.status = 403;
        ctx.body   = { error: 'You can only update your own expenses' };
        return;
      }

      const {
        amount,
        dateTime,
        description,
        note,
        paymentMethod,
        cardId,
        expenseCategoryId,
        installmentTotal,
        installmentCurrent
      } = ctx.request.body;

      // --- Validate new category if provided ---
      if (expenseCategoryId) {
        const category = await ExpenseCategory.findOne({
          where: { id: Number(expenseCategoryId), householdId: expense.householdId }
        });

        if (!category) {
          ctx.status = 400;
          ctx.body   = { error: 'Invalid expenseCategoryId for this household' };
          return;
        }
      }

      // --- Apply updates ---
      await expense.update({
        amount:             amount             !== undefined ? amount             : expense.amount,
        dateTime:           dateTime           !== undefined ? dateTime           : expense.dateTime,
        description:        description        !== undefined ? description        : expense.description,
        note:               note               !== undefined ? note               : expense.note,
        paymentMethod:      paymentMethod      !== undefined ? paymentMethod      : expense.paymentMethod,
        cardId:             cardId             !== undefined ? (cardId ? Number(cardId) : null) : expense.cardId,
        expenseCategoryId:  expenseCategoryId  !== undefined ? Number(expenseCategoryId) : expense.expenseCategoryId,
        installmentTotal:   installmentTotal   !== undefined ? (installmentTotal ? Number(installmentTotal) : null) : expense.installmentTotal,
        installmentCurrent: installmentCurrent !== undefined ? (installmentCurrent ? Number(installmentCurrent) : null) : expense.installmentCurrent
      });

      // --- Reload with includes ---
      const updated = await Expense.findByPk(expense.id, {
        include: [
          {
            model:      ExpenseCategory,
            attributes: ['id', 'name', 'nameHe', 'icon', 'color']
          },
          {
            model:      AppUser,
            attributes: ['id', 'username']
          }
        ]
      });

      ctx.body = { success: true, expense: updated.toJSON() };

    } catch (error) {
      console.error('Expenses update error:', error);
      ctx.status = 500;
      ctx.body   = { error: 'Failed to update expense' };
    }
  }

  /**
   * PUT /api/app/expenses/:id/installment-amount
   * Update the amount of an installment expense across a chosen scope.
   *
   * Body: { amount, scope }  — scope: 'all' | 'forward' | 'this'
   *   all     → update every record in the installment group
   *   forward → update this record and every later installment (installmentCurrent >=)
   *   this    → update only this record
   */
  async updateInstallmentAmount(ctx) {
    try {
      const { id }    = ctx.params;
      const appUserId = ctx.state.appUser.id;
      const { amount, scope } = ctx.request.body;

      if (amount === undefined || !scope || !['all', 'forward', 'this'].includes(scope)) {
        ctx.status = 400;
        ctx.body   = { error: 'amount and scope (all|forward|this) are required' };
        return;
      }

      const expense = await Expense.findByPk(id);
      if (!expense) {
        ctx.status = 404;
        ctx.body   = { error: 'Expense not found' };
        return;
      }

      if (expense.appUserId !== appUserId) {
        ctx.status = 403;
        ctx.body   = { error: 'You can only update your own expenses' };
        return;
      }

      if (scope === 'this') {
        await expense.update({ amount });
        ctx.body = { success: true };
        return;
      }

      // Determine the root of this installment group
      const rootId = expense.parentExpenseId ?? expense.id;

      const where = {
        [Op.or]: [{ id: rootId }, { parentExpenseId: rootId }]
      };

      if (scope === 'forward') {
        where.installmentCurrent = { [Op.gte]: expense.installmentCurrent };
      }

      await Expense.update({ amount }, { where });

      ctx.body = { success: true };
    } catch (error) {
      console.error('Expenses updateInstallmentAmount error:', error);
      ctx.status = 500;
      ctx.body   = { error: 'Failed to update installment amounts' };
    }
  }

  /**
   * DELETE /api/app/expenses/:id
   * Delete an expense (only the creator can delete).
   */
  async delete(ctx) {
    try {
      const { id }    = ctx.params;
      const appUserId  = ctx.state.appUser.id;

      const expense = await Expense.findByPk(id);

      if (!expense) {
        ctx.status = 404;
        ctx.body   = { error: 'Expense not found' };
        return;
      }

      if (expense.appUserId !== appUserId) {
        ctx.status = 403;
        ctx.body   = { error: 'You can only delete your own expenses' };
        return;
      }

      // Collect all expense IDs in this chain (this + children)
      const childExpenses = await Expense.findAll({
        where:      { parentExpenseId: expense.id },
        attributes: ['id']
      });
      const allExpenseIds = [expense.id, ...childExpenses.map(c => c.id)];

      // Remove attachment files from disk for all expenses in this chain
      // (DB rows will be removed by ON DELETE CASCADE after expense rows are destroyed)
      await deleteAttachmentFilesForTransactions({ expenseIds: allExpenseIds });

      // Cascade-delete all future installments linked to this expense
      await Expense.destroy({ where: { parentExpenseId: expense.id } });
      await expense.destroy();

      ctx.body = { success: true };

    } catch (error) {
      console.error('Expenses delete error:', error);
      ctx.status = 500;
      ctx.body   = { error: 'Failed to delete expense' };
    }
  }
}

module.exports = new ExpensesController();
module.exports.createExpenseRecord = createExpenseRecord;
