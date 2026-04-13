module.exports = (sequelize, DataTypes) => {
  const RecurringExpense = sequelize.define('RecurringExpense', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
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
    expenseCategoryId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: { model: 'expense_categories', key: 'id' }
    },
    appUserId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: { model: 'app_users', key: 'id' }
    },
    householdId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: { model: 'households', key: 'id' }
    }
  }, {
    timestamps: true,
    tableName: 'recurring_expenses'
  });

  return RecurringExpense;
};
