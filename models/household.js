module.exports = (sequelize, DataTypes) => {
  const Household = sequelize.define('Household', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    name: {
      type: DataTypes.STRING(100),
      allowNull: false
    },
    description: {
      type: DataTypes.STRING(255),
      allowNull: true
    },
    financialMonthStartDay: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 10,
      validate: { min: 1, max: 28 }
    }
  }, {
    timestamps: true,
    tableName: 'households'
  });

  return Household;
};
