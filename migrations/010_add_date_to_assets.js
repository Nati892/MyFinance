const { QueryTypes } = require('sequelize');
module.exports = {
  async up(sequelize) {
    const cols = await sequelize.query(
      "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'assets' AND TABLE_SCHEMA = DATABASE()",
      { type: QueryTypes.SELECT }
    );
    const existing = new Set(cols.map(c => c.COLUMN_NAME));
    if (!existing.has('date')) {
      await sequelize.query(
        "ALTER TABLE assets ADD COLUMN `date` DATE NULL DEFAULT NULL",
        { type: QueryTypes.RAW }
      );
    }
  }
};
