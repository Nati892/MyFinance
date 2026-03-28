module.exports = (sequelize, DataTypes) => {
  const Asset = sequelize.define('Asset', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    name: {
      type: DataTypes.STRING(255),
      allowNull: false
    },
    value: {
      type: DataTypes.DECIMAL(15, 2),
      defaultValue: 0
    },
    liquidity: {
      type: DataTypes.ENUM('high', 'medium', 'low'),
      defaultValue: 'medium'
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    householdId: {
      type: DataTypes.INTEGER,
      allowNull: false
    },
    sortOrder: {
      type: DataTypes.INTEGER,
      defaultValue: 0
    },
    date: {
      type: DataTypes.DATEONLY,
      allowNull: true,
      defaultValue: null
    },
    // ── Exit dates ───────────────────────────────────────────────────────────
    exitType: {
      type: DataTypes.ENUM('none', 'single', 'series'),
      defaultValue: 'none'
    },
    exitDate: {
      type: DataTypes.DATEONLY,
      allowNull: true,
      defaultValue: null
    },
    exitSeriesStart: {
      type: DataTypes.DATEONLY,
      allowNull: true,
      defaultValue: null
    },
    exitSeriesInterval: {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: null
    },
    exitSeriesUnit: {
      type: DataTypes.ENUM('days', 'weeks', 'months', 'years'),
      allowNull: true,
      defaultValue: null
    },
    // ── Repetitive income ────────────────────────────────────────────────────
    isRepetitive: {
      type: DataTypes.BOOLEAN,
      defaultValue: false
    },
    repetitiveAmount: {
      type: DataTypes.DECIMAL(15, 2),
      allowNull: true,
      defaultValue: null
    },
    repetitiveInterval: {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: null
    },
    repetitiveUnit: {
      type: DataTypes.ENUM('days', 'weeks', 'months', 'years'),
      allowNull: true,
      defaultValue: null
    },
  }, {
    timestamps: true,
    tableName: 'assets'
  });

  return Asset;
};
