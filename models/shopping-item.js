module.exports = (sequelize, DataTypes) => {
  const ShoppingItem = sequelize.define('ShoppingItem', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    name: {
      type: DataTypes.STRING(100),
      allowNull: false
    },
    nameHe: {
      type: DataTypes.STRING(100),
      allowNull: true,
      defaultValue: null
    },
    icon: {
      type: DataTypes.STRING(50),
      allowNull: true,
      defaultValue: null
    },
    defaultUnit: {
      type: DataTypes.ENUM('kg', 'lbs', 'pcs', 'g', 'L', 'ml'),
      allowNull: false,
      defaultValue: 'pcs'
    },
    categoryId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: null
    },
    householdId: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    createdBy: {
      type: DataTypes.INTEGER,
      allowNull: false
    }
  }, {
    timestamps: true,
    tableName: 'shopping_items'
  });

  return ShoppingItem;
};
