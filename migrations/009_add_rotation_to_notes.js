const { QueryTypes } = require('sequelize');
module.exports = {
  async up(sequelize) {
    const cols = await sequelize.query(
      "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'notes' AND TABLE_SCHEMA = DATABASE()",
      { type: QueryTypes.SELECT }
    );
    const existing = new Set(cols.map(c => c.COLUMN_NAME));
    if (!existing.has('rotation')) {
      await sequelize.query(
        'ALTER TABLE notes ADD COLUMN rotation FLOAT NOT NULL DEFAULT 0',
        { type: QueryTypes.RAW }
      );
    }
  }
};
