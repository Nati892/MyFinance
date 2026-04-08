const { QueryTypes } = require('sequelize');

module.exports = {
  up: async (sequelize) => {
    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS budget_plan_items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        householdId INT NOT NULL,
        expenseCategoryId INT NOT NULL,
        year INT NOT NULL,
        month INT NOT NULL,
        description VARCHAR(255) NULL,
        amount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        createdAt DATETIME NOT NULL,
        updatedAt DATETIME NOT NULL
      )
    `, { type: QueryTypes.RAW });

    await sequelize.query(`
      CREATE TABLE IF NOT EXISTS budget_month_configs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        householdId INT NOT NULL,
        year INT NOT NULL,
        month INT NOT NULL,
        startAmount DECIMAL(15,2) NULL,
        createdAt DATETIME NOT NULL,
        updatedAt DATETIME NOT NULL,
        UNIQUE KEY uq_bmc (householdId, year, month)
      )
    `, { type: QueryTypes.RAW });
  }
};
