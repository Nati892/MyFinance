module.exports = (sequelize, DataTypes) => {
  const IncomeCategory = sequelize.define('IncomeCategory', {
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
      allowNull: true
    },
    icon: {
      type: DataTypes.STRING(100),
      allowNull: false
    },
    color: {
      type: DataTypes.STRING(20),
      defaultValue: '#607D8B'
    },
    sortOrder: {
      type: DataTypes.INTEGER,
      defaultValue: 0
    },
    householdId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'households',
        key: 'id'
      }
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      defaultValue: true
    },
    parentCategoryId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: null
    }
  }, {
    timestamps: true,
    tableName: 'income_categories'
  });

  return IncomeCategory;
};
