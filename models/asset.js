module.exports = (sequelize, DataTypes) => {
  const Asset = sequelize.define('Asset', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    name: {
      type: DataTypes.STRING(255),
      allowNull: false
    },
    value: {
      type: DataTypes.DECIMAL(15, 2),
      defaultValue: 0
    },
    liquidity: {
      type: DataTypes.ENUM('high', 'medium', 'low'),
      defaultValue: 'medium'
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    householdId: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    sortOrder: {
      type: DataTypes.INTEGER,
      defaultValue: 0
    }
  }, {
    timestamps: true,
    tableName: 'assets'
  });

  return Asset;
};
