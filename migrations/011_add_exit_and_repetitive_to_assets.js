const { QueryTypes } = require('sequelize');

module.exports = {
  async up(sequelize) {
    const cols = await sequelize.query(
      "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'assets' AND TABLE_SCHEMA = DATABASE()",
      { type: QueryTypes.SELECT }
    );
    const existing = new Set(cols.map(c => c.COLUMN_NAME));

    const add = async (sql) => sequelize.query(sql, { type: QueryTypes.RAW });

    if (!existing.has('exitType'))
      await add("ALTER TABLE assets ADD COLUMN `exitType` ENUM('none','single','series') NOT NULL DEFAULT 'none'");

    if (!existing.has('exitDate'))
      await add("ALTER TABLE assets ADD COLUMN `exitDate` DATE NULL DEFAULT NULL");

    if (!existing.has('exitSeriesStart'))
      await add("ALTER TABLE assets ADD COLUMN `exitSeriesStart` DATE NULL DEFAULT NULL");

    if (!existing.has('exitSeriesInterval'))
      await add("ALTER TABLE assets ADD COLUMN `exitSeriesInterval` INT NULL DEFAULT NULL");

    if (!existing.has('exitSeriesUnit'))
      await add("ALTER TABLE assets ADD COLUMN `exitSeriesUnit` ENUM('days','weeks','months','years') NULL DEFAULT NULL");

    if (!existing.has('isRepetitive'))
      await add("ALTER TABLE assets ADD COLUMN `isRepetitive` TINYINT(1) NOT NULL DEFAULT 0");

    if (!existing.has('repetitiveAmount'))
      await add("ALTER TABLE assets ADD COLUMN `repetitiveAmount` DECIMAL(15,2) NULL DEFAULT NULL");

    if (!existing.has('repetitiveInterval'))
      await add("ALTER TABLE assets ADD COLUMN `repetitiveInterval` INT NULL DEFAULT NULL");

    if (!existing.has('repetitiveUnit'))
      await add("ALTER TABLE assets ADD COLUMN `repetitiveUnit` ENUM('days','weeks','months','years') NULL DEFAULT NULL");
  }
};
