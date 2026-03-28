/**
 * Creates all base tables for a fresh deployment.
 * Every subsequent migration only ALTERs these tables, so this must run first.
 */
const { QueryTypes } = require('sequelize');

module.exports = {
  async up(sequelize) {
    const raw = (sql) => sequelize.query(sql, { type: QueryTypes.RAW });

    // ── Admin/system tables ───────────────────────────────────────────────────

    await raw(`
      CREATE TABLE IF NOT EXISTS users (
        id          INT NOT NULL AUTO_INCREMENT,
        username    VARCHAR(255) NOT NULL UNIQUE,
        email       VARCHAR(255) NOT NULL UNIQUE,
        password    VARCHAR(255) NOT NULL,
        isActive    TINYINT(1) NOT NULL DEFAULT 1,
        lastLogin   DATETIME NULL,
        createdAt   DATETIME NOT NULL,
        updatedAt   DATETIME NOT NULL,
        PRIMARY KEY (id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    await raw(`
      CREATE TABLE IF NOT EXISTS server_settings (
        id            INT NOT NULL AUTO_INCREMENT,
        \`key\`        VARCHAR(255) NOT NULL UNIQUE,
        value         TEXT NULL,
        description   TEXT NULL,
        core_setting  TINYINT(1) NOT NULL DEFAULT 0,
        sendWithConfig TINYINT(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    await raw(`
      CREATE TABLE IF NOT EXISTS logs (
        id          INT NOT NULL AUTO_INCREMENT,
        action      VARCHAR(255) NOT NULL,
        description TEXT NULL,
        level       ENUM('debug','info','warn','err') NOT NULL DEFAULT 'info',
        source      ENUM('frontend','backend') NOT NULL DEFAULT 'backend',
        data        JSON NULL,
        method      VARCHAR(10) NULL,
        path        VARCHAR(255) NULL,
        statusCode  INT NULL,
        duration    INT NULL,
        errorStack  TEXT NULL,
        userId      INT NULL,
        ipAddress   VARCHAR(255) NULL,
        userAgent   VARCHAR(255) NULL,
        metadata    JSON NULL,
        createdAt   DATETIME NOT NULL,
        updatedAt   DATETIME NOT NULL,
        PRIMARY KEY (id),
        KEY idx_level (level),
        KEY idx_source (source),
        KEY idx_userId (userId),
        KEY idx_createdAt (createdAt),
        KEY idx_action (action)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    // ── App-user tables ───────────────────────────────────────────────────────

    await raw(`
      CREATE TABLE IF NOT EXISTS app_users (
        id        INT NOT NULL AUTO_INCREMENT,
        username  VARCHAR(50) NOT NULL UNIQUE,
        password  VARCHAR(255) NOT NULL,
        isActive  TINYINT(1) NOT NULL DEFAULT 1,
        lastLogin DATETIME NULL,
        createdAt DATETIME NOT NULL,
        updatedAt DATETIME NOT NULL,
        PRIMARY KEY (id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    await raw(`
      CREATE TABLE IF NOT EXISTS app_user_tokens (
        id        INT NOT NULL AUTO_INCREMENT,
        token     VARCHAR(512) NOT NULL,
        expiresAt DATETIME NOT NULL,
        appUserId INT NOT NULL,
        createdAt DATETIME NOT NULL,
        updatedAt DATETIME NOT NULL,
        PRIMARY KEY (id),
        KEY fk_aut_appUser (appUserId),
        CONSTRAINT fk_aut_appUser FOREIGN KEY (appUserId) REFERENCES app_users (id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    // ── Household tables ──────────────────────────────────────────────────────

    await raw(`
      CREATE TABLE IF NOT EXISTS households (
        id          INT NOT NULL AUTO_INCREMENT,
        name        VARCHAR(100) NOT NULL,
        description VARCHAR(255) NULL,
        createdAt   DATETIME NOT NULL,
        updatedAt   DATETIME NOT NULL,
        PRIMARY KEY (id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    await raw(`
      CREATE TABLE IF NOT EXISTS household_members (
        id                          INT NOT NULL AUTO_INCREMENT,
        householdId                 INT NOT NULL,
        appUserId                   INT NOT NULL,
        role                        ENUM('owner','member') NOT NULL DEFAULT 'member',
        favoriteExpenseCategoryIds  JSON NOT NULL DEFAULT ('[]'),
        favoritesLastCalculatedAt   DATETIME NULL,
        createdAt                   DATETIME NOT NULL,
        updatedAt                   DATETIME NOT NULL,
        PRIMARY KEY (id),
        UNIQUE KEY uq_hm_household_user (householdId, appUserId),
        CONSTRAINT fk_hm_household FOREIGN KEY (householdId) REFERENCES households (id) ON DELETE CASCADE,
        CONSTRAINT fk_hm_appUser   FOREIGN KEY (appUserId)   REFERENCES app_users (id)  ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    // ── Category tables ───────────────────────────────────────────────────────

    await raw(`
      CREATE TABLE IF NOT EXISTS expense_categories (
        id            INT NOT NULL AUTO_INCREMENT,
        name          VARCHAR(100) NOT NULL,
        nameHe        VARCHAR(100) NULL,
        icon          VARCHAR(100) NOT NULL,
        color         VARCHAR(20) NOT NULL DEFAULT '#607D8B',
        sortOrder     INT NOT NULL DEFAULT 0,
        monthlyBudget DECIMAL(10,2) NULL,
        householdId   INT NOT NULL,
        createdAt     DATETIME NOT NULL,
        updatedAt     DATETIME NOT NULL,
        PRIMARY KEY (id),
        CONSTRAINT fk_ec_household FOREIGN KEY (householdId) REFERENCES households (id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    await raw(`
      CREATE TABLE IF NOT EXISTS income_categories (
        id          INT NOT NULL AUTO_INCREMENT,
        name        VARCHAR(100) NOT NULL,
        nameHe      VARCHAR(100) NULL,
        icon        VARCHAR(100) NOT NULL,
        color       VARCHAR(20) NOT NULL DEFAULT '#607D8B',
        sortOrder   INT NOT NULL DEFAULT 0,
        householdId INT NOT NULL,
        createdAt   DATETIME NOT NULL,
        updatedAt   DATETIME NOT NULL,
        PRIMARY KEY (id),
        CONSTRAINT fk_ic_household FOREIGN KEY (householdId) REFERENCES households (id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    // ── Transaction tables ────────────────────────────────────────────────────

    await raw(`
      CREATE TABLE IF NOT EXISTS expenses (
        id                INT NOT NULL AUTO_INCREMENT,
        amount            DECIMAL(10,2) NOT NULL,
        dateTime          DATETIME NOT NULL,
        description       VARCHAR(255) NULL,
        note              TEXT NULL,
        paymentMethod     ENUM('credit_card','debit_card','cash','bank_transfer') NOT NULL DEFAULT 'credit_card',
        expenseCategoryId INT NOT NULL,
        appUserId         INT NOT NULL,
        householdId       INT NOT NULL,
        createdAt         DATETIME NOT NULL,
        updatedAt         DATETIME NOT NULL,
        PRIMARY KEY (id),
        CONSTRAINT fk_exp_category  FOREIGN KEY (expenseCategoryId) REFERENCES expense_categories (id),
        CONSTRAINT fk_exp_appUser   FOREIGN KEY (appUserId)         REFERENCES app_users (id),
        CONSTRAINT fk_exp_household FOREIGN KEY (householdId)       REFERENCES households (id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    await raw(`
      CREATE TABLE IF NOT EXISTS incomes (
        id               INT NOT NULL AUTO_INCREMENT,
        amount           DECIMAL(10,2) NOT NULL,
        dateTime         DATETIME NOT NULL,
        description      VARCHAR(255) NULL,
        note             TEXT NULL,
        paymentMethod    ENUM('credit_card','debit_card','cash','bank_transfer') NOT NULL DEFAULT 'credit_card',
        incomeCategoryId INT NOT NULL,
        appUserId        INT NOT NULL,
        householdId      INT NOT NULL,
        createdAt        DATETIME NOT NULL,
        updatedAt        DATETIME NOT NULL,
        PRIMARY KEY (id),
        CONSTRAINT fk_inc_category  FOREIGN KEY (incomeCategoryId) REFERENCES income_categories (id),
        CONSTRAINT fk_inc_appUser   FOREIGN KEY (appUserId)        REFERENCES app_users (id),
        CONSTRAINT fk_inc_household FOREIGN KEY (householdId)      REFERENCES households (id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    // ── Notes table ───────────────────────────────────────────────────────────

    await raw(`
      CREATE TABLE IF NOT EXISTS notes (
        id            INT NOT NULL AUTO_INCREMENT,
        content       MEDIUMTEXT NOT NULL DEFAULT '',
        posX          FLOAT NOT NULL DEFAULT 0,
        posY          FLOAT NOT NULL DEFAULT 0,
        zIndex        INT NOT NULL DEFAULT 1,
        householdId   INT NOT NULL,
        appUserId     INT NOT NULL,
        noteColor     VARCHAR(20) NOT NULL DEFAULT '#fff9c4',
        textDirection ENUM('ltr','rtl','auto') NOT NULL DEFAULT 'auto',
        textSize      INT NOT NULL DEFAULT 14,
        isBold        TINYINT(1) NOT NULL DEFAULT 0,
        isUnderline   TINYINT(1) NOT NULL DEFAULT 0,
        textColor     VARCHAR(20) NOT NULL DEFAULT '#333333',
        headerColor   VARCHAR(20) NULL DEFAULT NULL,
        type          ENUM('text','heart','image') NOT NULL DEFAULT 'text',
        heartColor    VARCHAR(20) NULL DEFAULT NULL,
        width         INT NULL DEFAULT NULL,
        height        INT NULL DEFAULT NULL,
        rotation      FLOAT NULL DEFAULT 0,
        createdAt     DATETIME NOT NULL,
        updatedAt     DATETIME NOT NULL,
        PRIMARY KEY (id),
        CONSTRAINT fk_note_household FOREIGN KEY (householdId) REFERENCES households (id) ON DELETE CASCADE,
        CONSTRAINT fk_note_appUser   FOREIGN KEY (appUserId)   REFERENCES app_users (id)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    // ── Assets table ──────────────────────────────────────────────────────────

    await raw(`
      CREATE TABLE IF NOT EXISTS assets (
        id                  INT NOT NULL AUTO_INCREMENT,
        name                VARCHAR(255) NOT NULL,
        value               DECIMAL(15,2) NOT NULL DEFAULT 0,
        liquidity           ENUM('high','medium','low') NOT NULL DEFAULT 'medium',
        description         TEXT NULL,
        householdId         INT NOT NULL,
        sortOrder           INT NOT NULL DEFAULT 0,
        \`date\`            DATE NULL DEFAULT NULL,
        exitType            ENUM('none','single','series') NOT NULL DEFAULT 'none',
        exitDate            DATE NULL DEFAULT NULL,
        exitSeriesStart     DATE NULL DEFAULT NULL,
        exitSeriesInterval  INT NULL DEFAULT NULL,
        exitSeriesUnit      ENUM('days','weeks','months','years') NULL DEFAULT NULL,
        isRepetitive        TINYINT(1) NOT NULL DEFAULT 0,
        repetitiveAmount    DECIMAL(15,2) NULL DEFAULT NULL,
        repetitiveInterval  INT NULL DEFAULT NULL,
        repetitiveUnit      ENUM('days','weeks','months','years') NULL DEFAULT NULL,
        createdAt           DATETIME NOT NULL,
        updatedAt           DATETIME NOT NULL,
        PRIMARY KEY (id),
        CONSTRAINT fk_asset_household FOREIGN KEY (householdId) REFERENCES households (id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);

    // ── Budget override table ─────────────────────────────────────────────────

    await raw(`
      CREATE TABLE IF NOT EXISTS category_budget_overrides (
        id                INT NOT NULL AUTO_INCREMENT,
        expenseCategoryId INT NOT NULL,
        householdId       INT NOT NULL,
        year              INT NOT NULL,
        month             INT NOT NULL,
        amount            DECIMAL(15,2) NOT NULL,
        createdAt         DATETIME NOT NULL,
        updatedAt         DATETIME NOT NULL,
        PRIMARY KEY (id),
        UNIQUE KEY uq_cbo (expenseCategoryId, year, month),
        CONSTRAINT fk_cbo_category  FOREIGN KEY (expenseCategoryId) REFERENCES expense_categories (id) ON DELETE CASCADE,
        CONSTRAINT fk_cbo_household FOREIGN KEY (householdId)       REFERENCES households (id) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    `);
  }
};
