/**
 * Create assets table.
 */
const { QueryTypes } = require('sequelize');

module.exports = {
  async up(sequelize) {
    await sequelize.query(
      `CREATE TABLE IF NOT EXISTS assets (
        id INT NOT NULL AUTO_INCREMENT,
        name VARCHAR(255) NOT NULL,
        value DECIMAL(15,2) NOT NULL DEFAULT 0,
        liquidity ENUM('high','medium','low') NOT NULL DEFAULT 'medium',
        description TEXT NULL,
        householdId INT NOT NULL,
        sortOrder INT NOT NULL DEFAULT 0,
        createdAt DATETIME NOT NULL,
        updatedAt DATETIME NOT NULL,
        PRIMARY KEY (id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
      { type: QueryTypes.RAW }
    );
  }
};
