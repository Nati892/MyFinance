module.exports = (sequelize, DataTypes) => {
  const Log = sequelize.define('Log', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    action: {
      type: DataTypes.STRING,
      allowNull: false
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    level: {
      type: DataTypes.ENUM('debug', 'info', 'warn', 'err'),
      allowNull: false,
      defaultValue: 'info'
    },
    source: {
      type: DataTypes.ENUM('frontend', 'backend'),
      allowNull: false,
      defaultValue: 'backend'
    },
    data: {
      type: DataTypes.JSON,
      allowNull: true,
      defaultValue: {}
    },
    method: {
      type: DataTypes.STRING(10),
      allowNull: true
    },
    path: {
      type: DataTypes.STRING,
      allowNull: true
    },
    statusCode: {
      type: DataTypes.INTEGER,
      allowNull: true
    },
    duration: {
      type: DataTypes.INTEGER,
      allowNull: true,
      comment: 'Request duration in milliseconds'
    },
    errorStack: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    userId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'users',
        key: 'id'
      }
    },
    ipAddress: {
      type: DataTypes.STRING,
      allowNull: true
    },
    userAgent: {
      type: DataTypes.STRING,
      allowNull: true
    },
    metadata: {
      type: DataTypes.JSON,
      allowNull: true,
      defaultValue: {}
    }
  }, {
    timestamps: true,
    tableName: 'logs',
    indexes: [
      {
        fields: ['level']
      },
      {
        fields: ['source']
      },
      {
        fields: ['userId']
      },
      {
        fields: ['createdAt']
      },
      {
        fields: ['action']
      }
    ]
  });

  return Log;
};