module.exports = (sequelize, DataTypes) => {
  const TransactionAttachment = sequelize.define('TransactionAttachment', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    expenseId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: null,
      references: { model: 'expenses', key: 'id' }
    },
    incomeId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: null,
      references: { model: 'incomes', key: 'id' }
    },
    householdId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: { model: 'households', key: 'id' }
    },
    appUserId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: { model: 'app_users', key: 'id' }
    },
    filename: {
      type: DataTypes.STRING(255),
      allowNull: true
    },
    originalFilename: {
      type: DataTypes.STRING(255),
      allowNull: true
    },
    mimeType: {
      type: DataTypes.STRING(100),
      allowNull: true
    },
    size: {
      type: DataTypes.INTEGER,
      allowNull: true
    },
    storagePath: {
      type: DataTypes.STRING(500),
      allowNull: true
    },
    thumbnailPath: {
      type: DataTypes.STRING(500),
      allowNull: true
    },
    isImage: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false
    }
  }, {
    timestamps: true,
    tableName: 'transaction_attachments'
  });

  return TransactionAttachment;
};
