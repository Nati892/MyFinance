module.exports = (sequelize, DataTypes) => {
  const AppUserToken = sequelize.define('AppUserToken', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    token: {
      type: DataTypes.STRING(512),
      allowNull: false
    },
    expiresAt: {
      type: DataTypes.DATE,
      allowNull: false
    },
    appUserId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'app_users',
        key: 'id'
      }
    }
  }, {
    timestamps: true,
    tableName: 'app_user_tokens'
  });

  return AppUserToken;
};
