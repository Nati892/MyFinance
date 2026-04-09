const { QueryTypes } = require('sequelize');

module.exports = {
  up: async (sequelize) => {
    const tables = await sequelize.query(
      "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'expenses'",
      { type: QueryTypes.SELECT }
    );
    if (tables.length === 0) return;

    const cols = await sequelize.query(
      "SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'expenses' AND COLUMN_NAME = 'parentExpenseId'",
      { type: QueryTypes.SELECT }
    );
    if (cols.length > 0) return;

    await sequelize.query(`
      ALTER TABLE expenses
        ADD COLUMN parentExpenseId INTEGER NULL REFERENCES expenses(id) ON DELETE SET NULL
    `, { type: QueryTypes.RAW });
  }
};
