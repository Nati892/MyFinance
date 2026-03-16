/**
 * Create category_budget_overrides table.
 */
const { QueryTypes } = require('sequelize');

module.exports = {
  async up(sequelize) {
    await sequelize.query(
      `CREATE TABLE IF NOT EXISTS category_budget_overrides (
        id INT NOT NULL AUTO_INCREMENT,
        expenseCategoryId INT NOT NULL,
        householdId INT NOT NULL,
        year INT NOT NULL,
        month INT NOT NULL,
        amount DECIMAL(15,2) NOT NULL,
        createdAt DATETIME NOT NULL,
        updatedAt DATETIME NOT NULL,
        PRIMARY KEY (id),
        UNIQUE KEY uq_category_budget_overrides_category_year_month (expenseCategoryId, year, month)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
      { type: QueryTypes.RAW }
    );
  }
};
