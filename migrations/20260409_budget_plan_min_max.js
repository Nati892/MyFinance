const { QueryTypes } = require('sequelize');

module.exports = {
  up: async (sequelize) => {
    // budget_plan_items: replace amount with minAmount + maxAmount
    await sequelize.query(`
      ALTER TABLE budget_plan_items
        ADD COLUMN minAmount DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        ADD COLUMN maxAmount DECIMAL(15,2) NOT NULL DEFAULT 0.00
    `, { type: QueryTypes.RAW });

    // Copy existing amount into both columns so old rows aren't lost
    await sequelize.query(`
      UPDATE budget_plan_items SET minAmount = amount, maxAmount = amount
    `, { type: QueryTypes.RAW });

    await sequelize.query(`
      ALTER TABLE budget_plan_items DROP COLUMN amount
    `, { type: QueryTypes.RAW });

    // budget_month_configs: add expectedIncome
    await sequelize.query(`
      ALTER TABLE budget_month_configs
        ADD COLUMN expectedIncome DECIMAL(15,2) NULL
    `, { type: QueryTypes.RAW });
  }
};
