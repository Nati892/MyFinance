module.exports = (sequelize, DataTypes) => {
  const ExpenseSchedule = sequelize.define('ExpenseSchedule', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
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
    tableName: 'expense_schedules'
  });

  return ExpenseSchedule;
};
