const { QueryTypes } = require('sequelize');

module.exports = {
  up: async (sequelize) => {
    // If the table doesn't exist yet, skip — sequelize.sync() will create it
    // with the column already defined in the model.
    const tables = await sequelize.query(
      "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'household_members'",
      { type: QueryTypes.SELECT }
    );
    if (tables.length === 0) {
      console.log('[Migration 001] household_members table not yet created, skipping ALTER');
      return;
    }

    // If column already exists (prior successful run), skip.
    const cols = await sequelize.query(
      "SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'household_members' AND COLUMN_NAME = 'favoriteExpenseCategoryIds'",
      { type: QueryTypes.SELECT }
    );
    if (cols.length > 0) {
      return;
    }

    await sequelize.query(
      "ALTER TABLE household_members ADD COLUMN favoriteExpenseCategoryIds JSON NOT NULL DEFAULT ('[]')"
    );
  }
};
