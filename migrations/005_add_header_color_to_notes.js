/**
 * Add headerColor column to notes table
 */
const { QueryTypes } = require('sequelize');

module.exports = {
  async up(sequelize) {
    const cols = await sequelize.query(
      "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'notes' AND TABLE_SCHEMA = DATABASE()",
      { type: QueryTypes.SELECT }
    );
    const existing = new Set(cols.map(c => c.COLUMN_NAME));

    if (!existing.has('headerColor')) {
      await sequelize.query(
        'ALTER TABLE notes ADD COLUMN headerColor VARCHAR(20) NULL DEFAULT NULL',
        { type: QueryTypes.RAW }
      );
    }
  }
};
