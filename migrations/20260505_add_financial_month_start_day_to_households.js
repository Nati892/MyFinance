const { DataTypes } = require('sequelize');

module.exports = {
  up: async (sequelize, qi) => {
    await qi.addColumn('households', 'financialMonthStartDay', {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 10
    });
  },

  down: async (sequelize, qi) => {
    await qi.removeColumn('households', 'financialMonthStartDay');
  }
};
