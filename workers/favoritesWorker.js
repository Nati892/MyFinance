const { workerData, parentPort } = require('worker_threads');

// Load config (worker has its own module scope)
const env = process.env.ENV || 'development';
try {
  global.cfg = require(`../conf/${env}.js`);
} catch {
  global.cfg = require('../conf/example.js');
}

const { HouseholdMember, Expense, sequelize } = require('../models');
const { Op, fn, col, literal } = require('sequelize');

async function calculateFavoritesForHousehold(householdId) {
  const members = await HouseholdMember.findAll({ where: { householdId } });

  for (const member of members) {
    // Count expenses per category for this user (all time, not just current period)
    const counts = await Expense.findAll({
      attributes: [
        'expenseCategoryId',
        [fn('COUNT', col('id')), 'count']
      ],
      where: {
        appUserId: member.appUserId,
        householdId,
        expenseCategoryId: { [Op.ne]: null }
      },
      group: ['expenseCategoryId'],
      order: [[literal('count'), 'DESC']],
      limit: 3,
      raw: true
    });

    const favoriteIds = counts.map(r => r.expenseCategoryId);

    await member.update({
      favoriteExpenseCategoryIds: favoriteIds,
      favoritesLastCalculatedAt: new Date()
    });
  }
}

calculateFavoritesForHousehold(workerData.householdId)
  .then(() => {
    parentPort.postMessage({ done: true, householdId: workerData.householdId });
    // Close DB connections so worker thread can exit
    sequelize.close().catch(() => {});
  })
  .catch((err) => {
    parentPort.postMessage({ done: false, error: err.message });
    sequelize.close().catch(() => {});
  });
