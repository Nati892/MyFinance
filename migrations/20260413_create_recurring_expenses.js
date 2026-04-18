const { DataTypes } = require('sequelize');

module.exports = {
  up: async (sequelize, qi) => {
    await qi.createTable('recurring_expenses', {
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
      amount: {
        type: DataTypes.DECIMAL(10, 2),
        allowNull: false
      },
      description: {
        type: DataTypes.STRING(255),
        allowNull: true
      },
      note: {
        type: DataTypes.TEXT,
        allowNull: true
      },
      paymentMethod: {
        type: DataTypes.ENUM('card', 'cash', 'bank_transfer'),
        defaultValue: 'bank_transfer',
        allowNull: false
      },
      dayOfMonth: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 10
      },
      startYear: {
        type: DataTypes.INTEGER,
        allowNull: false
      },
      startMonth: {
        type: DataTypes.INTEGER,
        allowNull: false
      },
      isActive: {
        type: DataTypes.BOOLEAN,
        defaultValue: true,
        allowNull: false
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
    await qi.dropTable('recurring_expenses');
  }
};
