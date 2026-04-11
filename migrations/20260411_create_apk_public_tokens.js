const { DataTypes } = require('sequelize');

module.exports = {
  up: async (sequelize, qi) => {
    const tableDesc = await qi.showAllTables();
    if (tableDesc.includes('apk_public_tokens')) return;

    await qi.createTable('apk_public_tokens', {
      id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false
      },
      token: {
        type: DataTypes.STRING(64),
        allowNull: false,
        unique: true
      },
      expiresAt: {
        type: DataTypes.DATE,
        allowNull: false
      },
      createdAt: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW
      }
    });

    console.log('[Migration] Created apk_public_tokens table');
  }
};
