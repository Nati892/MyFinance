const { Sequelize } = require('sequelize');
const config = global.cfg;

// Initialize Sequelize
const sequelize = new Sequelize(
  config.database.database,
  config.database.username,
  config.database.password,
  {
    host: config.database.host,
    port: config.database.port,
    dialect: config.database.dialect,
    logging: config.database.logging,
    pool: config.database.pool
  }
);

// Import models
const User = require('./user')(sequelize, Sequelize.DataTypes);
const Log = require('./log')(sequelize, Sequelize.DataTypes);
const Setting = require('./setting')(sequelize, Sequelize.DataTypes);
// Define associations
User.hasMany(Log, {
  foreignKey: 'userId',
  as: 'logs'
});

Log.belongsTo(User, {
  foreignKey: 'userId',
  as: 'user'
});

const db = {
  sequelize,
  Sequelize,
  User,
  Log,
  Setting
};

module.exports = db;