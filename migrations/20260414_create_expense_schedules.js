const { DataTypes } = require('sequelize');

module.exports = {
  up: async (sequelize, qi) => {
    await qi.createTable('expense_schedules', {
      id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false
      },
      householdId: {
        type: DataTypes.INTEGER,
        allowNull: false,
        references: { model: 'households', key: 'id' }
      },
      appUserId: {
        type: DataTypes.INTEGER,
        allowNull: false,
        references: { model: 'app_users', key: 'id' }
      },
      expenseCategoryId: {
        type: DataTypes.INTEGER,
        allowNull: false,
        references: { model: 'expense_categories', key: 'id' }
      },
      description: {
        type: DataTypes.STRING(255),
        allowNull: false
      },
      amount: {
        type: DataTypes.DECIMAL(10, 2),
        allowNull: true
      },
      paymentMethod: {
        type: DataTypes.ENUM('card', 'cash', 'bank_transfer'),
        allowNull: true
      },
      // JSON array of weekday numbers: 0=Sun, 1=Mon, ..., 6=Sat
      daysOfWeek: {
        type: DataTypes.JSON,
        allowNull: false
      },
      isActive: {
        type: DataTypes.BOOLEAN,
        defaultValue: true,
        allowNull: false
      },
      note: {
        type: DataTypes.TEXT,
        allowNull: true
      },
      createdAt: {
        type: DataTypes.DATE,
        allowNull: false
      },
      updatedAt: {
        type: DataTypes.DATE,
        allowNull: false
      }
    });
  },

  down: async (sequelize, qi) => {
    await qi.dropTable('expense_schedules');
  }
};
