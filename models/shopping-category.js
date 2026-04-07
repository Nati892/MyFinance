module.exports = (sequelize, DataTypes) => {
  const ShoppingCategory = sequelize.define('ShoppingCategory', {
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
    householdId: {
      type: DataTypes.INTEGER,
      allowNull: false
    }
  }, {
    timestamps: true,
    tableName: 'shopping_categories'
  });

  return ShoppingCategory;
};
