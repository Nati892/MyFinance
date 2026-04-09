module.exports = {
  up: async (sequelize) => {
    // If the table doesn't exist yet, skip — sequelize.sync() will create it
    // with the column already defined in the model.
    const [tables] = await sequelize.query("SHOW TABLES LIKE 'household_members'");
    if (tables.length === 0) {
      console.log('[Migration 001] household_members table not yet created, skipping ALTER');
      return;
    }

    // If column already exists (prior successful run), skip.
    const [cols] = await sequelize.query(
      "SHOW COLUMNS FROM household_members LIKE 'favoriteExpenseCategoryIds'"
    );
    if (cols.length > 0) {
      return;
    }

    await sequelize.query(
      "ALTER TABLE household_members ADD COLUMN favoriteExpenseCategoryIds JSON NOT NULL DEFAULT ('[]')"
    );
  }
};
