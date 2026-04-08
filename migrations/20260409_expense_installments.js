const { QueryTypes } = require('sequelize');

module.exports = {
  up: async (sequelize) => {
    await sequelize.query(`
      ALTER TABLE expenses
        ADD COLUMN installmentTotal   INTEGER NULL,
        ADD COLUMN installmentCurrent INTEGER NULL
    `, { type: QueryTypes.RAW });
  }
};
