/**
 * Add styling fields to notes table:
 * noteColor, textDirection, textSize, isBold, isUnderline, textColor
 */
const { QueryTypes } = require('sequelize');

module.exports = {
  async up(sequelize) {
    const cols = await sequelize.query(
      "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'notes' AND TABLE_SCHEMA = DATABASE()",
      { type: QueryTypes.SELECT }
    );
    const existing = new Set(cols.map(c => c.COLUMN_NAME));

    if (!existing.has('noteColor')) {
      await sequelize.query(
        "ALTER TABLE notes ADD COLUMN noteColor VARCHAR(20) NOT NULL DEFAULT '#fff9c4'",
        { type: QueryTypes.RAW }
      );
    }

    if (!existing.has('textDirection')) {
      await sequelize.query(
        "ALTER TABLE notes ADD COLUMN textDirection ENUM('ltr','rtl','auto') NOT NULL DEFAULT 'auto'",
        { type: QueryTypes.RAW }
      );
    }

    if (!existing.has('textSize')) {
      await sequelize.query(
        'ALTER TABLE notes ADD COLUMN textSize INT NOT NULL DEFAULT 14',
        { type: QueryTypes.RAW }
      );
    }

    if (!existing.has('isBold')) {
      await sequelize.query(
        'ALTER TABLE notes ADD COLUMN isBold TINYINT(1) NOT NULL DEFAULT 0',
        { type: QueryTypes.RAW }
      );
    }

    if (!existing.has('isUnderline')) {
      await sequelize.query(
        'ALTER TABLE notes ADD COLUMN isUnderline TINYINT(1) NOT NULL DEFAULT 0',
        { type: QueryTypes.RAW }
      );
    }

    if (!existing.has('textColor')) {
      await sequelize.query(
        "ALTER TABLE notes ADD COLUMN textColor VARCHAR(20) NOT NULL DEFAULT '#333333'",
        { type: QueryTypes.RAW }
      );
    }
  }
};
