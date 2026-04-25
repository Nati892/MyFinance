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
const Card = require('./card')(sequelize, Sequelize.DataTypes);
const CategoryBudgetOverride = require('./categoryBudgetOverride')(sequelize, Sequelize.DataTypes);
const BudgetPlanItem = require('./budgetPlanItem')(sequelize, Sequelize.DataTypes);
const BudgetMonthConfig = require('./budgetMonthConfig')(sequelize, Sequelize.DataTypes);
const ShoppingCategory = require('./shopping-category')(sequelize, Sequelize.DataTypes);
const ShoppingStore = require('./shopping-store')(sequelize, Sequelize.DataTypes);
const ShoppingItem = require('./shopping-item')(sequelize, Sequelize.DataTypes);
const ShoppingList = require('./shopping-list')(sequelize, Sequelize.DataTypes);
const ShoppingListItem = require('./shopping-list-item')(sequelize, Sequelize.DataTypes);
const ShoppingSession = require('./shopping-session')(sequelize, Sequelize.DataTypes);
const ShoppingSessionItem = require('./shopping-session-item')(sequelize, Sequelize.DataTypes);
const ApkRelease = require('./apkRelease')(sequelize, Sequelize.DataTypes);
const RecurringExpense = require('./recurringExpense')(sequelize, Sequelize.DataTypes);
const ExpenseSchedule = require('./expenseSchedule')(sequelize, Sequelize.DataTypes);
const TransactionAttachment = require('./transactionAttachment')(sequelize, Sequelize.DataTypes);

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

// Household <-> Card
Household.hasMany(Card, { foreignKey: 'householdId', onDelete: 'CASCADE' });
Card.belongsTo(Household, { foreignKey: 'householdId' });

// Card <-> Expense
Card.hasMany(Expense, { foreignKey: 'cardId' });
Expense.belongsTo(Card, { foreignKey: 'cardId', as: 'card' });

// Card <-> Income
Card.hasMany(Income, { foreignKey: 'cardId' });
Income.belongsTo(Card, { foreignKey: 'cardId', as: 'card' });

// Household <-> CategoryBudgetOverride
Household.hasMany(CategoryBudgetOverride, { foreignKey: 'householdId', onDelete: 'CASCADE' });
CategoryBudgetOverride.belongsTo(Household, { foreignKey: 'householdId' });

// ExpenseCategory <-> CategoryBudgetOverride
ExpenseCategory.hasMany(CategoryBudgetOverride, { foreignKey: 'expenseCategoryId', onDelete: 'CASCADE' });
CategoryBudgetOverride.belongsTo(ExpenseCategory, { foreignKey: 'expenseCategoryId' });

// ShoppingCategory <-> ShoppingItem
ShoppingCategory.hasMany(ShoppingItem, { foreignKey: 'categoryId', as: 'items' });
ShoppingItem.belongsTo(ShoppingCategory, { foreignKey: 'categoryId', as: 'category' });

// Household <-> ShoppingCategory
Household.hasMany(ShoppingCategory, { foreignKey: 'householdId', onDelete: 'CASCADE' });
ShoppingCategory.belongsTo(Household, { foreignKey: 'householdId' });

// Household <-> ShoppingStore
Household.hasMany(ShoppingStore, { foreignKey: 'householdId', onDelete: 'CASCADE' });
ShoppingStore.belongsTo(Household, { foreignKey: 'householdId' });

// Household <-> ShoppingItem
Household.hasMany(ShoppingItem, { foreignKey: 'householdId', onDelete: 'CASCADE' });
ShoppingItem.belongsTo(Household, { foreignKey: 'householdId' });

// AppUser <-> ShoppingItem (creator)
AppUser.hasMany(ShoppingItem, { foreignKey: 'createdBy' });
ShoppingItem.belongsTo(AppUser, { foreignKey: 'createdBy', as: 'creator' });

// Household <-> ShoppingList
Household.hasMany(ShoppingList, { foreignKey: 'householdId', onDelete: 'CASCADE' });
ShoppingList.belongsTo(Household, { foreignKey: 'householdId' });

// AppUser <-> ShoppingList
AppUser.hasMany(ShoppingList, { foreignKey: 'createdBy' });
ShoppingList.belongsTo(AppUser, { foreignKey: 'createdBy', as: 'creator' });

// ShoppingList <-> ShoppingListItem
ShoppingList.hasMany(ShoppingListItem, { foreignKey: 'listId', as: 'listItems', onDelete: 'CASCADE' });
ShoppingListItem.belongsTo(ShoppingList, { foreignKey: 'listId' });

// ShoppingItem <-> ShoppingListItem
ShoppingItem.hasMany(ShoppingListItem, { foreignKey: 'itemId' });
ShoppingListItem.belongsTo(ShoppingItem, { foreignKey: 'itemId', as: 'item' });

// Household <-> ShoppingSession
Household.hasMany(ShoppingSession, { foreignKey: 'householdId', onDelete: 'CASCADE' });
ShoppingSession.belongsTo(Household, { foreignKey: 'householdId' });

// AppUser <-> ShoppingSession
AppUser.hasMany(ShoppingSession, { foreignKey: 'createdBy' });
ShoppingSession.belongsTo(AppUser, { foreignKey: 'createdBy', as: 'creator' });

// ShoppingList <-> ShoppingSession (optional template source)
ShoppingList.hasMany(ShoppingSession, { foreignKey: 'listId' });
ShoppingSession.belongsTo(ShoppingList, { foreignKey: 'listId', as: 'sourceList' });

// ExpenseCategory <-> ShoppingSession (default category for completion / plan link)
ExpenseCategory.hasMany(ShoppingSession, { foreignKey: 'expenseCategoryId' });
ShoppingSession.belongsTo(ExpenseCategory, { foreignKey: 'expenseCategoryId', as: 'expenseCategory' });

// Expense <-> ShoppingSession (the expense created when session is completed)
Expense.hasMany(ShoppingSession, { foreignKey: 'linkedExpenseId' });
ShoppingSession.belongsTo(Expense, { foreignKey: 'linkedExpenseId', as: 'linkedExpense' });

// BudgetPlanItem <-> ShoppingSession (plan row this session feeds into)
BudgetPlanItem.hasMany(ShoppingSession, { foreignKey: 'linkedBudgetPlanItemId' });
ShoppingSession.belongsTo(BudgetPlanItem, { foreignKey: 'linkedBudgetPlanItemId', as: 'linkedBudgetPlanItem' });

// ShoppingSession <-> ShoppingSessionItem
ShoppingSession.hasMany(ShoppingSessionItem, { foreignKey: 'sessionId', as: 'sessionItems', onDelete: 'CASCADE' });
ShoppingSessionItem.belongsTo(ShoppingSession, { foreignKey: 'sessionId' });

// ShoppingItem <-> ShoppingSessionItem
ShoppingItem.hasMany(ShoppingSessionItem, { foreignKey: 'itemId' });
ShoppingSessionItem.belongsTo(ShoppingItem, { foreignKey: 'itemId', as: 'item' });

// ShoppingStore <-> ShoppingSessionItem
ShoppingStore.hasMany(ShoppingSessionItem, { foreignKey: 'storeId' });
ShoppingSessionItem.belongsTo(ShoppingStore, { foreignKey: 'storeId', as: 'store' });

// Household <-> RecurringExpense
Household.hasMany(RecurringExpense, { foreignKey: 'householdId', onDelete: 'CASCADE' });
RecurringExpense.belongsTo(Household, { foreignKey: 'householdId' });

// AppUser <-> RecurringExpense
AppUser.hasMany(RecurringExpense, { foreignKey: 'appUserId' });
RecurringExpense.belongsTo(AppUser, { foreignKey: 'appUserId' });

// ExpenseCategory <-> RecurringExpense
ExpenseCategory.hasMany(RecurringExpense, { foreignKey: 'expenseCategoryId' });
RecurringExpense.belongsTo(ExpenseCategory, { foreignKey: 'expenseCategoryId' });

// Household <-> ExpenseSchedule
Household.hasMany(ExpenseSchedule, { foreignKey: 'householdId', onDelete: 'CASCADE' });
ExpenseSchedule.belongsTo(Household, { foreignKey: 'householdId' });

// AppUser <-> ExpenseSchedule
AppUser.hasMany(ExpenseSchedule, { foreignKey: 'appUserId' });
ExpenseSchedule.belongsTo(AppUser, { foreignKey: 'appUserId' });

// ExpenseCategory <-> ExpenseSchedule
ExpenseCategory.hasMany(ExpenseSchedule, { foreignKey: 'expenseCategoryId' });
ExpenseSchedule.belongsTo(ExpenseCategory, { foreignKey: 'expenseCategoryId' });

// Expense <-> TransactionAttachment
Expense.hasMany(TransactionAttachment, { foreignKey: 'expenseId', as: 'attachments', onDelete: 'CASCADE' });
TransactionAttachment.belongsTo(Expense, { foreignKey: 'expenseId' });

// Income <-> TransactionAttachment
Income.hasMany(TransactionAttachment, { foreignKey: 'incomeId', as: 'attachments', onDelete: 'CASCADE' });
TransactionAttachment.belongsTo(Income, { foreignKey: 'incomeId' });

// Household <-> TransactionAttachment
Household.hasMany(TransactionAttachment, { foreignKey: 'householdId', as: 'attachments', onDelete: 'CASCADE' });
TransactionAttachment.belongsTo(Household, { foreignKey: 'householdId' });

// AppUser <-> TransactionAttachment
AppUser.hasMany(TransactionAttachment, { foreignKey: 'appUserId', as: 'attachments' });
TransactionAttachment.belongsTo(AppUser, { foreignKey: 'appUserId' });

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
  Card,
  CategoryBudgetOverride,
  BudgetPlanItem,
  BudgetMonthConfig,
  ShoppingCategory,
  ShoppingStore,
  ShoppingItem,
  ShoppingList,
  ShoppingListItem,
  ShoppingSession,
  ShoppingSessionItem,
  ApkRelease,
  RecurringExpense,
  ExpenseSchedule,
  TransactionAttachment
};

module.exports = db;