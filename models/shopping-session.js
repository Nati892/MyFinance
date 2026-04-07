module.exports = (sequelize, DataTypes) => {
  const ShoppingSession = sequelize.define('ShoppingSession', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    name: {
      type: DataTypes.STRING(150),
      allowNull: false
    },
    listId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: null
    },
    posX: {
      type: DataTypes.FLOAT,
      allowNull: false,
      defaultValue: 50
    },
    posY: {
      type: DataTypes.FLOAT,
      allowNull: false,
      defaultValue: 50
    },
    zIndex: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 1
    },
    rotation: {
      type: DataTypes.FLOAT,
      allowNull: false,
      defaultValue: 0
    },
    width: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 220
    },
    height: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 300
    },
    noteColor: {
      type: DataTypes.STRING(20),
      allowNull: false,
      defaultValue: '#fff9c4'
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
    tableName: 'shopping_sessions'
  });

  return ShoppingSession;
};
