const { Worker } = require('worker_threads');
const path = require('path');

const WORKER_PATH = path.join(__dirname, '../workers/favoritesWorker.js');
const RECALC_INTERVAL_MS = 60 * 60 * 1000;  // 1 hour
const CRON_INTERVAL_MS = 30 * 60 * 1000;    // 30 minutes

function runFavoritesWorker(householdId) {
  return new Promise((resolve, reject) => {
    const worker = new Worker(WORKER_PATH, { workerData: { householdId } });
    worker.on('message', resolve);
    worker.on('error', reject);
    worker.on('exit', (code) => {
      if (code !== 0) reject(new Error(`Favorites worker exited with code ${code}`));
    });
  });
}

async function runFavoritesCron() {
  const { Household, HouseholdMember } = require('../models');

  let households;
  try {
    households = await Household.findAll({ attributes: ['id'] });
  } catch (err) {
    console.error('[Cron] Failed to fetch households:', err.message);
    return;
  }

  const threshold = new Date(Date.now() - RECALC_INTERVAL_MS);

  for (const household of households) {
    try {
      const members = await HouseholdMember.findAll({
        where: { householdId: household.id }
      });

      if (members.length === 0) continue;

      const needsRecalc = members.some(
        (m) => !m.favoritesLastCalculatedAt || m.favoritesLastCalculatedAt < threshold
      );

      if (!needsRecalc) continue;

      runFavoritesWorker(household.id)
        .then((result) => {
          console.log(`[Cron] Favorites updated for household ${result.householdId}`);
        })
        .catch((err) => {
          console.error(`[Cron] Worker error for household ${household.id}:`, err.message);
        });
    } catch (err) {
      console.error(`[Cron] Error checking household ${household.id}:`, err.message);
    }
  }
}

function startCron() {
  setTimeout(() => runFavoritesCron().catch(console.error), 10000);
  setInterval(() => runFavoritesCron().catch(console.error), CRON_INTERVAL_MS);
  console.log('[Cron] Favorites cron scheduled (every 30 min)');
}

module.exports = { startCron };
