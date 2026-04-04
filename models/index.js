const { Sequelize } = require('sequelize');
const config = global.cfg;

// Initialize Sequelize
const sequelize = new Sequelize(
  config.database.database,
  config.database.username,
  config.database.password,
  {
    host: config.database.host,
    port: config.database.port,
    dialect: config.database.dialect,
    logging: config.database.logging,
    pool: config.database.pool
  }
);

// Import models
const User = require('./user')(sequelize, Sequelize.DataTypes);
const Log = require('./log')(sequelize, Sequelize.DataTypes);
const Setting = require('./setting')(sequelize, Sequelize.DataTypes);
const AppUser = require('./appUser')(sequelize, Sequelize.DataTypes);
const AppUserToken = require('./appUserToken')(sequelize, Sequelize.DataTypes);
const Household = require('./household')(sequelize, Sequelize.DataTypes);
const HouseholdMember = require('./householdMember')(sequelize, Sequelize.DataTypes);
const ExpenseCategory = require('./expenseCategory')(sequelize, Sequelize.DataTypes);
const IncomeCategory = require('./incomeCategory')(sequelize, Sequelize.DataTypes);
const Expense = require('./expense')(sequelize, Sequelize.DataTypes);
const Income = require('./income')(sequelize, Sequelize.DataTypes);
const Note = require('./note')(sequelize, Sequelize.DataTypes);
const Asset = require('./asset')(sequelize, Sequelize.DataTypes);
const CategoryBudgetOverride = require('./categoryBudgetOverride')(sequelize, Sequelize.DataTypes);

// Define associations
User.hasMany(Log, {
  foreignKey: 'userId',
  as: 'logs'
});

Log.belongsTo(User, {
  foreignKey: 'userId',
  as: 'user'
});

// AppUser <-> AppUserToken
AppUser.hasMany(AppUserToken, { foreignKey: 'appUserId', onDelete: 'CASCADE' });
AppUserToken.belongsTo(AppUser, { foreignKey: 'appUserId' });

// AppUser <-> HouseholdMember
AppUser.hasMany(HouseholdMember, { foreignKey: 'appUserId', onDelete: 'CASCADE' });
HouseholdMember.belongsTo(AppUser, { foreignKey: 'appUserId' });

// Household <-> HouseholdMember
Household.hasMany(HouseholdMember, { foreignKey: 'householdId', onDelete: 'CASCADE' });
HouseholdMember.belongsTo(Household, { foreignKey: 'householdId' });

// Household <-> ExpenseCategory
Household.hasMany(ExpenseCategory, { foreignKey: 'householdId', onDelete: 'CASCADE' });
ExpenseCategory.belongsTo(Household, { foreignKey: 'householdId' });

// Household <-> IncomeCategory
Household.hasMany(IncomeCategory, { foreignKey: 'householdId', onDelete: 'CASCADE' });
IncomeCategory.belongsTo(Household, { foreignKey: 'householdId' });

// ExpenseCategory <-> Expense
ExpenseCategory.hasMany(Expense, { foreignKey: 'expenseCategoryId' });
Expense.belongsTo(ExpenseCategory, { foreignKey: 'expenseCategoryId' });

// IncomeCategory <-> Income
IncomeCategory.hasMany(Income, { foreignKey: 'incomeCategoryId' });
Income.belongsTo(IncomeCategory, { foreignKey: 'incomeCategoryId' });

// AppUser <-> Expense
AppUser.hasMany(Expense, { foreignKey: 'appUserId' });
Expense.belongsTo(AppUser, { foreignKey: 'appUserId' });

// AppUser <-> Income
AppUser.hasMany(Income, { foreignKey: 'appUserId' });
Income.belongsTo(AppUser, { foreignKey: 'appUserId' });

// Household <-> Expense
Household.hasMany(Expense, { foreignKey: 'householdId', onDelete: 'CASCADE' });
Expense.belongsTo(Household, { foreignKey: 'householdId' });

// Household <-> Income
Household.hasMany(Income, { foreignKey: 'householdId', onDelete: 'CASCADE' });
Income.belongsTo(Household, { foreignKey: 'householdId' });

// Household <-> Note
Household.hasMany(Note, { foreignKey: 'householdId', onDelete: 'CASCADE' });
Note.belongsTo(Household, { foreignKey: 'householdId' });

// AppUser <-> Note
AppUser.hasMany(Note, { foreignKey: 'appUserId' });
Note.belongsTo(AppUser, { foreignKey: 'appUserId' });

// Household <-> Asset
Household.hasMany(Asset, { foreignKey: 'householdId', onDelete: 'CASCADE' });
Asset.belongsTo(Household, { foreignKey: 'householdId' });

// Household <-> CategoryBudgetOverride
Household.hasMany(CategoryBudgetOverride, { foreignKey: 'householdId', onDelete: 'CASCADE' });
CategoryBudgetOverride.belongsTo(Household, { foreignKey: 'householdId' });

// ExpenseCategory <-> CategoryBudgetOverride
ExpenseCategory.hasMany(CategoryBudgetOverride, { foreignKey: 'expenseCategoryId', onDelete: 'CASCADE' });
CategoryBudgetOverride.belongsTo(ExpenseCategory, { foreignKey: 'expenseCategoryId' });

// ExpenseCategory self-referential (sub-categories)
ExpenseCategory.hasMany(ExpenseCategory, { as: 'subCategories', foreignKey: 'parentCategoryId' });
ExpenseCategory.belongsTo(ExpenseCategory, { as: 'parentCategory', foreignKey: 'parentCategoryId' });

// IncomeCategory self-referential (sub-categories)
IncomeCategory.hasMany(IncomeCategory, { as: 'subCategories', foreignKey: 'parentCategoryId' });
IncomeCategory.belongsTo(IncomeCategory, { as: 'parentCategory', foreignKey: 'parentCategoryId' });

// AppUser <-> Household (many-to-many through HouseholdMember)
AppUser.belongsToMany(Household, { through: HouseholdMember, foreignKey: 'appUserId' });
Household.belongsToMany(AppUser, { through: HouseholdMember, foreignKey: 'householdId' });

const db = {
  sequelize,
  Sequelize,
  User,
  Log,
  Setting,
  AppUser,
  AppUserToken,
  Household,
  HouseholdMember,
  ExpenseCategory,
  IncomeCategory,
  Expense,
  Income,
  Note,
  Asset,
  CategoryBudgetOverride
};

module.exports = db;