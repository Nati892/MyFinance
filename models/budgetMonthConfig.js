module.exports = (sequelize, DataTypes) => {
  const BudgetMonthConfig = sequelize.define('BudgetMonthConfig', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    householdId: {
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
    startAmount: {
      type: DataTypes.DECIMAL(15, 2),
      allowNull: true
    },
    expectedIncome: {
      type: DataTypes.DECIMAL(15, 2),
      allowNull: true
    }
  }, {
    timestamps: true,
    tableName: 'budget_month_configs',
    indexes: [
      {
        unique: true,
        fields: ['householdId', 'year', 'month']
      }
    ]
  });

  return BudgetMonthConfig;
};
