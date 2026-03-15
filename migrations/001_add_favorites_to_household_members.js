/**
 * Add favoriteExpenseCategoryIds (JSON) and favoritesLastCalculatedAt (DATETIME)
 * columns to household_members table.
 */
const { QueryTypes } = require('sequelize');

module.exports = {
  async up(sequelize) {
    const cols = await sequelize.query(
      "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'household_members' AND TABLE_SCHEMA = DATABASE()",
      { type: QueryTypes.SELECT }
    );
    const existing = new Set(cols.map(c => c.COLUMN_NAME));

    if (!existing.has('favoriteExpenseCategoryIds')) {
      await sequelize.query(
        "ALTER TABLE household_members ADD COLUMN favoriteExpenseCategoryIds JSON NOT NULL DEFAULT ('[]')",
        { type: QueryTypes.RAW }
      );
    }

    if (!existing.has('favoritesLastCalculatedAt')) {
      await sequelize.query(
        'ALTER TABLE household_members ADD COLUMN favoritesLastCalculatedAt DATETIME NULL',
        { type: QueryTypes.RAW }
      );
    }
  }
};
