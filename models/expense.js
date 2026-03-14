module.exports = (sequelize, DataTypes) => {
  const Expense = sequelize.define('Expense', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    amount: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false
    },
    dateTime: {
      type: DataTypes.DATE,
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
      type: DataTypes.ENUM('credit_card', 'debit_card', 'cash', 'bank_transfer'),
      defaultValue: 'credit_card'
    },
    expenseCategoryId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'expense_categories',
        key: 'id'
      }
    },
    appUserId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'app_users',
        key: 'id'
      }
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
    tableName: 'expenses'
  });

  return Expense;
};
