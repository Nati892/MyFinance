module.exports = (sequelize, DataTypes) => {
  const HouseholdMember = sequelize.define('HouseholdMember', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    householdId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'households',
        key: 'id'
      }
    },
    appUserId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'app_users',
        key: 'id'
      }
    },
    role: {
      type: DataTypes.ENUM('owner', 'member'),
      defaultValue: 'member'
    }
  }, {
    timestamps: true,
    tableName: 'household_members',
    indexes: [
      {
        unique: true,
        fields: ['householdId', 'appUserId']
      }
    ]
  });

  return HouseholdMember;
};
