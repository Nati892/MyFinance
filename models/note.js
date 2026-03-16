module.exports = (sequelize, DataTypes) => {
  const Note = sequelize.define('Note', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    content: {
      type: DataTypes.TEXT,
      allowNull: false,
      defaultValue: ''
    },
    posX: {
      type: DataTypes.FLOAT,
      allowNull: false,
      defaultValue: 0
    },
    posY: {
      type: DataTypes.FLOAT,
      allowNull: false,
      defaultValue: 0
    },
    zIndex: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 1
    },
    householdId: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    appUserId: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    noteColor: {
      type: DataTypes.STRING(20),
      defaultValue: '#fff9c4'
    },
    textDirection: {
      type: DataTypes.ENUM('ltr', 'rtl', 'auto'),
      defaultValue: 'auto'
    },
    textSize: {
      type: DataTypes.INTEGER,
      defaultValue: 14
    },
    isBold: {
      type: DataTypes.BOOLEAN,
      defaultValue: false
    },
    isUnderline: {
      type: DataTypes.BOOLEAN,
      defaultValue: false
    },
    textColor: {
      type: DataTypes.STRING(20),
      defaultValue: '#333333'
    },
    headerColor: {
      type: DataTypes.STRING(20),
      allowNull: true,
      defaultValue: null
    }
  }, {
    timestamps: true,
    tableName: 'notes'
  });

  return Note;
};
