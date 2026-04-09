const { QueryTypes } = require('sequelize');

module.exports = {
  up: async (sequelize) => {
    const tables = await sequelize.query(
      "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'expenses'",
      { type: QueryTypes.SELECT }
    );
    if (tables.length === 0) return;

    const cols = await sequelize.query(
      "SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'expenses' AND COLUMN_NAME = 'installmentTotal'",
      { type: QueryTypes.SELECT }
    );
    if (cols.length > 0) return;

    await sequelize.query(`
      ALTER TABLE expenses
        ADD COLUMN installmentTotal   INTEGER NULL,
        ADD COLUMN installmentCurrent INTEGER NULL
    `, { type: QueryTypes.RAW });
  }
};
