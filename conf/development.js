module.exports = {
    env: process.env.ENV || 'development',
    port: process.env.PORT || 1234,
    baseAddress: process.env.BASE_ADDRESS || '0.0.0.0',

    database: {
        host: process.env.DB_HOST || 'localhost',
        port: process.env.DB_PORT || 3307,
        database: process.env.DB_NAME || 'base_db',
        username: process.env.DB_USER || 'root',
        password: process.env.DB_PASSWORD || '12345678',
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
        origin: '*',
        credentials: true,
        allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
        allowHeaders: ['Content-Type', 'Authorization', 'Accept', 'X-Requested-With', 'Origin'],
        exposeHeaders: ['Content-Length', 'Date', 'X-Request-Id'],
        maxAge: 86400
    }
};