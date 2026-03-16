const { QueryTypes } = require('sequelize');

module.exports = {
  async up(sequelize) {
    const cols = await sequelize.query(
      "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'notes' AND TABLE_SCHEMA = DATABASE()",
      { type: QueryTypes.SELECT }
    );
    const existing = new Set(cols.map(c => c.COLUMN_NAME));

    if (!existing.has('type')) {
      await sequelize.query(
        "ALTER TABLE notes ADD COLUMN `type` ENUM('text','heart','image') NOT NULL DEFAULT 'text'",
        { type: QueryTypes.RAW }
      );
    }
    if (!existing.has('heartColor')) {
      await sequelize.query(
        'ALTER TABLE notes ADD COLUMN heartColor VARCHAR(20) NULL DEFAULT NULL',
        { type: QueryTypes.RAW }
      );
    }
    if (!existing.has('width')) {
      await sequelize.query(
        'ALTER TABLE notes ADD COLUMN width INT NULL DEFAULT NULL',
        { type: QueryTypes.RAW }
      );
    }
    if (!existing.has('height')) {
      await sequelize.query(
        'ALTER TABLE notes ADD COLUMN height INT NULL DEFAULT NULL',
        { type: QueryTypes.RAW }
      );
    }
  }
};
