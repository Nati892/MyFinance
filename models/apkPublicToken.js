module.exports = (sequelize, DataTypes) => {
  return sequelize.define('ApkPublicToken', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    token: {
      type: DataTypes.STRING(64),
      allowNull: false,
      unique: true
    },
    expiresAt: {
      type: DataTypes.DATE,
      allowNull: false
    }
  }, {
    timestamps: true,
    updatedAt: false,
    tableName: 'apk_public_tokens'
  });
};
