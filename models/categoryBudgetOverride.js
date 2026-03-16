module.exports = (sequelize, DataTypes) => {
  const CategoryBudgetOverride = sequelize.define('CategoryBudgetOverride', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    expenseCategoryId: {
      type: DataTypes.INTEGER,
      allowNull: false
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
    amount: {
      type: DataTypes.DECIMAL(15, 2),
      allowNull: false
    }
  }, {
    timestamps: true,
    tableName: 'category_budget_overrides',
    indexes: [
      {
        unique: true,
        fields: ['expenseCategoryId', 'year', 'month']
      }
    ]
  });

  return CategoryBudgetOverride;
};
