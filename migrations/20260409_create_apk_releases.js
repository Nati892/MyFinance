const { QueryTypes } = require('sequelize');

module.exports = {
  up: async (sequelize) => {
    const tables = await sequelize.query(
      "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'apk_releases'",
      { type: QueryTypes.SELECT }
    );
    if (tables.length) return;

    await sequelize.query(`
      CREATE TABLE apk_releases (
        id INT AUTO_INCREMENT PRIMARY KEY,
        version INT NOT NULL,
        filename VARCHAR(255) NOT NULL,
        uploadedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('[Migration] Created apk_releases table');
  }
};
