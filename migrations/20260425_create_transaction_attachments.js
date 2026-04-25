const { DataTypes } = require('sequelize');

module.exports = {
  up: async (sequelize, qi) => {
    await qi.createTable('transaction_attachments', {
      id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false
      },
      expenseId: {
        type: DataTypes.INTEGER,
        allowNull: true,
        references: { model: 'expenses', key: 'id' },
        onDelete: 'CASCADE'
      },
      incomeId: {
        type: DataTypes.INTEGER,
        allowNull: true,
        references: { model: 'incomes', key: 'id' },
        onDelete: 'CASCADE'
      },
      householdId: {
        type: DataTypes.INTEGER,
        allowNull: false,
        references: { model: 'households', key: 'id' },
        onDelete: 'CASCADE'
      },
      appUserId: {
        type: DataTypes.INTEGER,
        allowNull: false,
        references: { model: 'app_users', key: 'id' }
      },
      filename: {
        type: DataTypes.STRING(255),
        allowNull: true
      },
      originalFilename: {
        type: DataTypes.STRING(255),
        allowNull: true
      },
      mimeType: {
        type: DataTypes.STRING(100),
        allowNull: true
      },
      size: {
        type: DataTypes.INTEGER,
        allowNull: true
      },
      storagePath: {
        type: DataTypes.STRING(500),
        allowNull: true
      },
      thumbnailPath: {
        type: DataTypes.STRING(500),
        allowNull: true
      },
      isImage: {
        type: DataTypes.BOOLEAN,
        allowNull: false,
        defaultValue: false
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

    await qi.addIndex('transaction_attachments', ['expenseId'],   { name: 'idx_ta_expense_id' });
    await qi.addIndex('transaction_attachments', ['incomeId'],    { name: 'idx_ta_income_id' });
    await qi.addIndex('transaction_attachments', ['householdId'], { name: 'idx_ta_household_id' });
  },

  down: async (sequelize, qi) => {
    await qi.dropTable('transaction_attachments');
  }
};
