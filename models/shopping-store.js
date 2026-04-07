module.exports = (sequelize, DataTypes) => {
  const ShoppingStore = sequelize.define('ShoppingStore', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    name: {
      type: DataTypes.STRING(100),
      allowNull: false
    },
    householdId: {
      type: DataTypes.INTEGER,
      allowNull: false
    }
  }, {
    timestamps: true,
    tableName: 'shopping_stores'
  });

  return ShoppingStore;
};
