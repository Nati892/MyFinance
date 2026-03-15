const path = require('path');
const fs = require('fs');
const { QueryTypes } = require('sequelize');

/**
 * Runs any pending migrations from the /migrations directory.
 * Migrations are tracked in a `schema_migrations` table.
 * Each migration file must export: { up: async (sequelize) => {} }
 */
async function runMigrations(sequelize) {
  const qi = sequelize.getQueryInterface();

  // Ensure tracking table exists (RAW type avoids formatResults on DDL)
  await sequelize.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name VARCHAR(255) PRIMARY KEY,
      ran_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  `, { type: QueryTypes.RAW });

  // Get already-applied migrations
  const applied = await sequelize.query(
    'SELECT name FROM schema_migrations',
    { type: QueryTypes.SELECT }
  );
  const appliedNames = new Set(applied.map(r => r.name));

  // Read migration files sorted by name
  const migrationsDir = path.join(__dirname, '../migrations');
  if (!fs.existsSync(migrationsDir)) {
    console.log('[Migrations] No migrations directory found, skipping.');
    return;
  }

  const files = fs.readdirSync(migrationsDir)
    .filter(f => f.endsWith('.js'))
    .sort();

  let ran = 0;
  for (const file of files) {
    if (appliedNames.has(file)) continue;

    const migration = require(path.join(migrationsDir, file));
    console.log(`[Migrations] Running: ${file}`);
    await migration.up(sequelize, qi);
    await sequelize.query(
      'INSERT INTO schema_migrations (name) VALUES (?)',
      { type: QueryTypes.INSERT, replacements: [file] }
    );
    ran++;
    console.log(`[Migrations] Done: ${file}`);
  }

  if (ran === 0) {
    console.log('[Migrations] All up to date.');
  }
}

module.exports = { runMigrations };
