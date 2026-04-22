const { DataTypes } = require('sequelize');

module.exports = {
  up: async (sequelize, qi) => {
    const desc = await qi.describeTable('shopping_sessions');

    const addIfMissing = async (name, spec) => {
      if (!desc[name]) {
        await qi.addColumn('shopping_sessions', name, spec);
      }
    };

    await addIfMissing('mode', {
      type: DataTypes.ENUM('planned', 'active'),
      allowNull: false,
      defaultValue: 'active'
    });

    await addIfMissing('plannedMinPrice', {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: true,
      defaultValue: null
    });

    await addIfMissing('plannedMaxPrice', {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: true,
      defaultValue: null
    });

    await addIfMissing('plannedYear', {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: null
    });

    await addIfMissing('plannedMonth', {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: null
    });

    await addIfMissing('plannedWeekOfMonth', {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: null
    });

    await addIfMissing('expenseCategoryId', {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: null,
      references: { model: 'expense_categories', key: 'id' },
      onDelete: 'SET NULL'
    });

    await addIfMissing('completedAt', {
      type: DataTypes.DATE,
      allowNull: true,
      defaultValue: null
    });

    await addIfMissing('linkedExpenseId', {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: null,
      references: { model: 'expenses', key: 'id' },
      onDelete: 'SET NULL'
    });

    await addIfMissing('linkedBudgetPlanItemId', {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: null,
      references: { model: 'budget_plan_items', key: 'id' },
      onDelete: 'SET NULL'
    });
  }
};
