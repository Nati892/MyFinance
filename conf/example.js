module.exports = {
    env: process.env.ENV || 'development',
    port: process.env.PORT || 3000,
    baseAddress: process.env.BASE_ADDRESS || '0.0.0.0',

    database: {
        host: process.env.DB_HOST || 'localhost',
        port: process.env.DB_PORT || 3307,
        database: process.env.DB_NAME || 'app_database',
        username: process.env.DB_USER || 'app_user',
        password: process.env.DB_PASSWORD || 'app_password',
        dialect: 'mariadb',
        logging: process.env.ENV === 'development' ? console.log : false,
        pool: {
            max: 5,
            min: 0,
            acquire: 30000,
            idle: 10000
        }
    },

    jwt: {
        secret: process.env.JWT_SECRET || 'your-secret-key',
        expiresIn: process.env.JWT_EXPIRES_IN || '24h'
    },

    bcrypt: {
        saltRounds: parseInt(process.env.BCRYPT_SALT_ROUNDS) || 10
    },

    cors: {
        origin: ['http://localhost:4200', '*'], // Add Angular's default port
        credentials: true
    }
};