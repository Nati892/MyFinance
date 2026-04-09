const { QueryTypes } = require('sequelize');

module.exports = {
  up: async (sequelize) => {
    const tables = await sequelize.query(
      "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'app_users'",
      { type: QueryTypes.SELECT }
    );
    if (!tables.length) {
      console.log('[Migration] app_users table not yet created, skipping isDeveloper ALTER');
      return;
    }

    const cols = await sequelize.query(
      "SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'app_users' AND COLUMN_NAME = 'isDeveloper'",
      { type: QueryTypes.SELECT }
    );
    if (cols.length) return;

    await sequelize.query(
      "ALTER TABLE app_users ADD COLUMN isDeveloper TINYINT(1) NOT NULL DEFAULT 0"
    );
    console.log('[Migration] Added isDeveloper column to app_users');
  }
};
