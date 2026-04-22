const { QueryTypes } = require('sequelize');

module.exports = {
  up: async (sequelize) => {
    // Convert integer version column to VARCHAR and migrate old rows (e.g. 31 → "1.0.31")
    const [cols] = await sequelize.query(
      "SELECT DATA_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'apk_releases' AND COLUMN_NAME = 'version'",
      { type: QueryTypes.SELECT }
    );
    if (!cols) {
      console.log('[Migration] apk_releases.version column not found, skipping');
      return;
    }
    if (cols.DATA_TYPE !== 'int') {
      console.log('[Migration] apk_releases.version is already a string type, skipping');
      return;
    }

    await sequelize.query(`ALTER TABLE apk_releases MODIFY COLUMN version VARCHAR(20) NOT NULL`);
    await sequelize.query(`UPDATE apk_releases SET version = CONCAT('1.0.', version) WHERE version REGEXP '^[0-9]+$'`);
    console.log('[Migration] Converted apk_releases.version from INT to VARCHAR and prefixed old rows with 1.0.');
  }
};
