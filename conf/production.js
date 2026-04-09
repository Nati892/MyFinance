module.exports = {
    env: 'production',
    port: process.env.PORT || 1234,
    baseAddress: process.env.BASE_ADDRESS || '0.0.0.0',

    database: {
        host: process.env.DB_HOST || 'localhost',
        port: process.env.DB_PORT || 3306,
        database: process.env.DB_NAME || 'app_db',
        username: process.env.DB_USER || 'user',
        password: process.env.DB_PASSWORD || '12345678',
        dialect: 'mariadb',
        logging: false,
        pool: {
            max: 5,
            min: 0,
            acquire: 30000,
            idle: 10000
        }
    },

    jwt: {
        secret: process.env.JWT_SECRET || 'change-me-in-production',
        expiresIn: process.env.JWT_EXPIRES_IN || '1h'
    },

    bcrypt: {
        saltRounds: parseInt(process.env.BCRYPT_SALT_ROUNDS) || 10
    },

    cors: {
        origin: process.env.CORS_ORIGIN || '*',
        credentials: true
    },

    managerApiToken: process.env.MANAGER_API_TOKEN || 'household-manager-api-token'
};
