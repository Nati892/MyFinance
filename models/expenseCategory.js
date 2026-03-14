module.exports = (sequelize, DataTypes) => {
  const ExpenseCategory = sequelize.define('ExpenseCategory', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    name: {
      type: DataTypes.STRING(100),
      allowNull: false
    },
    icon: {
      type: DataTypes.STRING(100),
      allowNull: false
    },
    color: {
      type: DataTypes.STRING(20),
      defaultValue: '#607D8B'
    },
    sortOrder: {
      type: DataTypes.INTEGER,
      defaultValue: 0
    },
    monthlyBudget: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: true
    },
    householdId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'households',
        key: 'id'
      }
    }
  }, {
    timestamps: true,
    tableName: 'expense_categories'
  });

  return ExpenseCategory;
};
