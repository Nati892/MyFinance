module.exports = (sequelize, DataTypes) => {

    const Setting = sequelize.define('Setting', {
        id: {
            type: DataTypes.INTEGER,
            autoIncrement: true,
            primaryKey: true
        },
        key: {
            type: DataTypes.STRING,
            allowNull: false,
            unique: true,
            validate: {
                notEmpty: true
            }
        },
        value: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        description: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        core_setting: {
            type: DataTypes.BOOLEAN,
            defaultValue: false,
            allowNull: false
        },
        sendWithConfig: {
            type: DataTypes.BOOLEAN,
            defaultValue: false,
            allowNull: false
        }
    }, {
        tableName: 'server_settings',
        timestamps: false
    });

    return Setting;
};