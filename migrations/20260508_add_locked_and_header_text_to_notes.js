const { DataTypes } = require('sequelize');

module.exports = {
  up: async (sequelize, qi) => {
    await qi.addColumn('notes', 'headerText', {
      type: DataTypes.STRING(120),
      allowNull: true,
      defaultValue: null
    });
    await qi.addColumn('notes', 'locked', {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false
    });
  },

  down: async (sequelize, qi) => {
    await qi.removeColumn('notes', 'headerText');
    await qi.removeColumn('notes', 'locked');
  }
};
