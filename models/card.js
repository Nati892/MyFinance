module.exports = (sequelize, DataTypes) => {
  const Card = sequelize.define('Card', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    lastFourDigits: {
      type: DataTypes.STRING(4),
      allowNull: false
    },
    nickname: {
      type: DataTypes.STRING(255),
      allowNull: true,
      defaultValue: null
    },
    bankName: {
      type: DataTypes.STRING(255),
      allowNull: true,
      defaultValue: null
    },
    cardType: {
      type: DataTypes.ENUM('credit', 'debit'),
      allowNull: true,
      defaultValue: null
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
    tableName: 'cards'
  });

  return Card;
};
