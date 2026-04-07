module.exports = (sequelize, DataTypes) => {
  const ShoppingSessionItem = sequelize.define('ShoppingSessionItem', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    sessionId: {
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
    status: {
      type: DataTypes.ENUM('pending', 'got', 'not_got', 'partial'),
      allowNull: false,
      defaultValue: 'pending'
    },
    price: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: true,
      defaultValue: null
    },
    storeId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: null
    },
    note: {
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
    tableName: 'shopping_session_items'
  });

  return ShoppingSessionItem;
};
