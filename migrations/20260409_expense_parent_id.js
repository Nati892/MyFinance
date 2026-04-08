const { QueryTypes } = require('sequelize');

module.exports = {
  up: async (sequelize) => {
    await sequelize.query(`
      ALTER TABLE expenses
        ADD COLUMN parentExpenseId INTEGER NULL REFERENCES expenses(id) ON DELETE SET NULL
    `, { type: QueryTypes.RAW });
  }
};
