module.exports = (sequelize, DataTypes) => {
  const Income = sequelize.define('Income', {
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
      type: DataTypes.ENUM('card', 'cash', 'bank_transfer'),
      defaultValue: 'card'
    },
    cardId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: null,
      references: { model: 'cards', key: 'id' }
    },
    incomeCategoryId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'income_categories',
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
    tableName: 'incomes'
  });

  return Income;
};
