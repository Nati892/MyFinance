module.exports = (sequelize, DataTypes) => {
  const ShoppingListItem = sequelize.define('ShoppingListItem', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    listId: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    itemId: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    amount: {
      type: DataTypes.DECIMAL(10, 3),
      allowNull: false,
      defaultValue: 1
    },
    unit: {
      type: DataTypes.ENUM('kg', 'lbs', 'pcs', 'g', 'L', 'ml'),
      allowNull: false,
      defaultValue: 'pcs'
    },
    extraData: {
      type: DataTypes.STRING(255),
      allowNull: true,
      defaultValue: null
    },
    sortOrder: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0
    }
  }, {
    timestamps: true,
    tableName: 'shopping_list_items'
  });

  return ShoppingListItem;
};
