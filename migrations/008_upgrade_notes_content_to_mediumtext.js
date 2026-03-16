const { QueryTypes } = require('sequelize');

module.exports = {
  async up(sequelize) {
    await sequelize.query(
      'ALTER TABLE notes MODIFY COLUMN content MEDIUMTEXT NOT NULL DEFAULT ""',
      { type: QueryTypes.RAW }
    );
  }
};
