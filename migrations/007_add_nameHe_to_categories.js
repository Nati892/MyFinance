const { QueryTypes } = require('sequelize');

module.exports = {
  async up(sequelize) {
    const expenseCols = await sequelize.query(
      "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'expense_categories' AND TABLE_SCHEMA = DATABASE()",
      { type: QueryTypes.SELECT }
    );
    const expenseExisting = new Set(expenseCols.map(c => c.COLUMN_NAME));

    if (!expenseExisting.has('nameHe')) {
      await sequelize.query(
        'ALTER TABLE expense_categories ADD COLUMN nameHe VARCHAR(100) NULL DEFAULT NULL',
        { type: QueryTypes.RAW }
      );
    }

    const incomeCols = await sequelize.query(
      "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'income_categories' AND TABLE_SCHEMA = DATABASE()",
      { type: QueryTypes.SELECT }
    );
    const incomeExisting = new Set(incomeCols.map(c => c.COLUMN_NAME));

    if (!incomeExisting.has('nameHe')) {
      await sequelize.query(
        'ALTER TABLE income_categories ADD COLUMN nameHe VARCHAR(100) NULL DEFAULT NULL',
        { type: QueryTypes.RAW }
      );
    }
  }
};
