module.exports = (sequelize, DataTypes) => {
  const BudgetPlanItem = sequelize.define('BudgetPlanItem', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    householdId: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    expenseCategoryId: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    year: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    month: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    description: {
      type: DataTypes.STRING(255),
      allowNull: true
    },
    minAmount: {
      type: DataTypes.DECIMAL(15, 2),
      allowNull: false,
      defaultValue: 0
    },
    maxAmount: {
      type: DataTypes.DECIMAL(15, 2),
      allowNull: false,
      defaultValue: 0
    }
  }, {
    timestamps: true,
    tableName: 'budget_plan_items'
  });

  return BudgetPlanItem;
};
