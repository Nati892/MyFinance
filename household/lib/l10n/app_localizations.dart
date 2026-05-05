import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  /// No description provided for @navAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get navAssets;

  /// No description provided for @navBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get navBudget;

  /// No description provided for @navTransactions.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get navTransactions;

  /// No description provided for @navStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get navStatistics;

  /// No description provided for @navBoard.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get navBoard;

  /// No description provided for @navExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get navExpenses;

  /// No description provided for @navIncomes.
  ///
  /// In en, this message translates to:
  /// **'Incomes'**
  String get navIncomes;

  /// No description provided for @headerSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get headerSignOut;

  /// No description provided for @headerBrand.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get headerBrand;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your household finances'**
  String get loginSubtitle;

  /// No description provided for @loginUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get loginUsername;

  /// No description provided for @loginUsernamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter your username'**
  String get loginUsernamePlaceholder;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginPasswordPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get loginPasswordPlaceholder;

  /// No description provided for @loginSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginSignIn;

  /// No description provided for @loginSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get loginSigningIn;

  /// No description provided for @loginNoHousehold.
  ///
  /// In en, this message translates to:
  /// **'No household assigned yet. Contact your admin.'**
  String get loginNoHousehold;

  /// No description provided for @expensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesTitle;

  /// No description provided for @expensesNew.
  ///
  /// In en, this message translates to:
  /// **'New Expense'**
  String get expensesNew;

  /// No description provided for @expensesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Expense'**
  String get expensesEdit;

  /// No description provided for @expensesCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get expensesCategory;

  /// No description provided for @expensesDate.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get expensesDate;

  /// No description provided for @expensesPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get expensesPaymentMethod;

  /// No description provided for @expensesDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get expensesDescription;

  /// No description provided for @expensesDescriptionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. Groceries at Shufersal'**
  String get expensesDescriptionPlaceholder;

  /// No description provided for @expensesNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get expensesNote;

  /// No description provided for @expensesNotePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Add a note…'**
  String get expensesNotePlaceholder;

  /// No description provided for @expensesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Expense'**
  String get expensesAdd;

  /// No description provided for @expensesSave.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get expensesSave;

  /// No description provided for @expensesSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get expensesSaving;

  /// No description provided for @expensesNoCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories'**
  String get expensesNoCategories;

  /// No description provided for @expensesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load expenses. Please try again.'**
  String get expensesLoadFailed;

  /// No description provided for @incomesTitle.
  ///
  /// In en, this message translates to:
  /// **'Incomes'**
  String get incomesTitle;

  /// No description provided for @incomesNew.
  ///
  /// In en, this message translates to:
  /// **'New Income'**
  String get incomesNew;

  /// No description provided for @incomesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Income'**
  String get incomesEdit;

  /// No description provided for @incomesCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get incomesCategory;

  /// No description provided for @incomesDate.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get incomesDate;

  /// No description provided for @incomesPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get incomesPaymentMethod;

  /// No description provided for @incomesDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get incomesDescription;

  /// No description provided for @incomesDescriptionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. Monthly salary'**
  String get incomesDescriptionPlaceholder;

  /// No description provided for @incomesNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get incomesNote;

  /// No description provided for @incomesNotePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Add a note…'**
  String get incomesNotePlaceholder;

  /// No description provided for @incomesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Income'**
  String get incomesAdd;

  /// No description provided for @incomesSave.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get incomesSave;

  /// No description provided for @incomesSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get incomesSaving;

  /// No description provided for @incomesNoCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories'**
  String get incomesNoCategories;

  /// No description provided for @incomesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load incomes.'**
  String get incomesLoadFailed;

  /// No description provided for @transactionsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get transactionsAll;

  /// No description provided for @transactionsExpensesOnly.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get transactionsExpensesOnly;

  /// No description provided for @transactionsIncomesOnly.
  ///
  /// In en, this message translates to:
  /// **'Incomes'**
  String get transactionsIncomesOnly;

  /// No description provided for @transactionsFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get transactionsFilters;

  /// No description provided for @transactionsMinAmount.
  ///
  /// In en, this message translates to:
  /// **'Min Amount'**
  String get transactionsMinAmount;

  /// No description provided for @transactionsMaxAmount.
  ///
  /// In en, this message translates to:
  /// **'Max Amount'**
  String get transactionsMaxAmount;

  /// No description provided for @transactionsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get transactionsReset;

  /// No description provided for @transactionsApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get transactionsApply;

  /// No description provided for @transactionsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load transactions. Please try again.'**
  String get transactionsLoadFailed;

  /// No description provided for @transactionsShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get transactionsShow;

  /// No description provided for @transactionsPriceRange.
  ///
  /// In en, this message translates to:
  /// **'Price range'**
  String get transactionsPriceRange;

  /// No description provided for @transactionsMinUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Min (unlimited)'**
  String get transactionsMinUnlimited;

  /// No description provided for @transactionsMaxUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Max (unlimited)'**
  String get transactionsMaxUnlimited;

  /// No description provided for @transactionsCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get transactionsCategory;

  /// No description provided for @transactionsExpenseLabel.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get transactionsExpenseLabel;

  /// No description provided for @transactionsIncomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get transactionsIncomeLabel;

  /// No description provided for @paymentCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get paymentCard;

  /// No description provided for @paymentDebit.
  ///
  /// In en, this message translates to:
  /// **'Debit'**
  String get paymentDebit;

  /// No description provided for @paymentCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentCash;

  /// No description provided for @paymentTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get paymentTransfer;

  /// No description provided for @budgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budgetTitle;

  /// No description provided for @budgetMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get budgetMonth;

  /// No description provided for @budgetSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get budgetSpent;

  /// No description provided for @budgetLeft.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get budgetLeft;

  /// No description provided for @budgetOf.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budgetOf;

  /// No description provided for @budgetSetBudget.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get budgetSetBudget;

  /// No description provided for @budgetSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get budgetSave;

  /// No description provided for @budgetCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get budgetCancel;

  /// No description provided for @budgetNoBudget.
  ///
  /// In en, this message translates to:
  /// **'No budget categories found.'**
  String get budgetNoBudget;

  /// No description provided for @budgetOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get budgetOnTrack;

  /// No description provided for @budgetWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get budgetWarning;

  /// No description provided for @budgetOverBudget.
  ///
  /// In en, this message translates to:
  /// **'Over budget'**
  String get budgetOverBudget;

  /// No description provided for @budgetLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load budget'**
  String get budgetLoadFailed;

  /// No description provided for @budgetNoCategories.
  ///
  /// In en, this message translates to:
  /// **'No expense categories found.'**
  String get budgetNoCategories;

  /// No description provided for @budgetTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get budgetTable;

  /// No description provided for @budgetGraph.
  ///
  /// In en, this message translates to:
  /// **'Graph'**
  String get budgetGraph;

  /// No description provided for @budgetCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get budgetCategory;

  /// No description provided for @budgetEveryMonth.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get budgetEveryMonth;

  /// No description provided for @budgetTapToSet.
  ///
  /// In en, this message translates to:
  /// **'Tap a row to set budget'**
  String get budgetTapToSet;

  /// No description provided for @budgetAllCategories.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get budgetAllCategories;

  /// No description provided for @budgetByWeek.
  ///
  /// In en, this message translates to:
  /// **'By week'**
  String get budgetByWeek;

  /// No description provided for @budgetByMonth.
  ///
  /// In en, this message translates to:
  /// **'By month'**
  String get budgetByMonth;

  /// No description provided for @budgetNoData.
  ///
  /// In en, this message translates to:
  /// **'No data for this period.'**
  String get budgetNoData;

  /// No description provided for @budgetPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get budgetPlan;

  /// No description provided for @budgetPlanSave.
  ///
  /// In en, this message translates to:
  /// **'Save Month Budgets'**
  String get budgetPlanSave;

  /// No description provided for @budgetPlanHint.
  ///
  /// In en, this message translates to:
  /// **'Set budget for each category for this month'**
  String get budgetPlanHint;

  /// No description provided for @budgetPlanAddCategory.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get budgetPlanAddCategory;

  /// No description provided for @budgetPlanAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get budgetPlanAddItem;

  /// No description provided for @budgetPlanStartAmount.
  ///
  /// In en, this message translates to:
  /// **'Starting budget'**
  String get budgetPlanStartAmount;

  /// No description provided for @budgetPlanTotal.
  ///
  /// In en, this message translates to:
  /// **'Total planned'**
  String get budgetPlanTotal;

  /// No description provided for @budgetPlanBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get budgetPlanBalance;

  /// No description provided for @budgetPlanDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get budgetPlanDescriptionHint;

  /// No description provided for @budgetPlanNoCategories.
  ///
  /// In en, this message translates to:
  /// **'No expense categories. Tap + to add one.'**
  String get budgetPlanNoCategories;

  /// No description provided for @budgetPlanAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get budgetPlanAdvanced;

  /// No description provided for @budgetPlanDeleteItem.
  ///
  /// In en, this message translates to:
  /// **'Delete item'**
  String get budgetPlanDeleteItem;

  /// No description provided for @budgetPlanMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get budgetPlanMin;

  /// No description provided for @budgetPlanMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get budgetPlanMax;

  /// No description provided for @budgetPlanIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get budgetPlanIncome;

  /// No description provided for @budgetPlanPrediction.
  ///
  /// In en, this message translates to:
  /// **'Prediction'**
  String get budgetPlanPrediction;

  /// No description provided for @budgetPlanMonthPrediction.
  ///
  /// In en, this message translates to:
  /// **'Month Prediction'**
  String get budgetPlanMonthPrediction;

  /// No description provided for @budgetPlanTotalMin.
  ///
  /// In en, this message translates to:
  /// **'Total Planned (Min)'**
  String get budgetPlanTotalMin;

  /// No description provided for @budgetPlanTotalMax.
  ///
  /// In en, this message translates to:
  /// **'Total Planned (Max)'**
  String get budgetPlanTotalMax;

  /// No description provided for @budgetPlanRemainingMin.
  ///
  /// In en, this message translates to:
  /// **'Remaining (Min)'**
  String get budgetPlanRemainingMin;

  /// No description provided for @budgetPlanRemainingMax.
  ///
  /// In en, this message translates to:
  /// **'Remaining (Max)'**
  String get budgetPlanRemainingMax;

  /// No description provided for @assetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get assetsTitle;

  /// No description provided for @assetsNew.
  ///
  /// In en, this message translates to:
  /// **'New Asset'**
  String get assetsNew;

  /// No description provided for @assetsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Asset'**
  String get assetsEdit;

  /// No description provided for @assetsName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get assetsName;

  /// No description provided for @assetsValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get assetsValue;

  /// No description provided for @assetsLiquidity.
  ///
  /// In en, this message translates to:
  /// **'Liquidity'**
  String get assetsLiquidity;

  /// No description provided for @assetsLiquidityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get assetsLiquidityHigh;

  /// No description provided for @assetsLiquidityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get assetsLiquidityMedium;

  /// No description provided for @assetsLiquidityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get assetsLiquidityLow;

  /// No description provided for @assetsDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get assetsDescription;

  /// No description provided for @assetsDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get assetsDate;

  /// No description provided for @assetsSave.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get assetsSave;

  /// No description provided for @assetsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Asset'**
  String get assetsAdd;

  /// No description provided for @assetsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get assetsCancel;

  /// No description provided for @assetsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get assetsDelete;

  /// No description provided for @assetsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load assets'**
  String get assetsLoadFailed;

  /// No description provided for @assetsNoAssets.
  ///
  /// In en, this message translates to:
  /// **'No assets yet'**
  String get assetsNoAssets;

  /// No description provided for @assetsNoAssetsSub.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first asset.'**
  String get assetsNoAssetsSub;

  /// No description provided for @assetsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get assetsTotal;

  /// No description provided for @assetsLiquid.
  ///
  /// In en, this message translates to:
  /// **'Liquid'**
  String get assetsLiquid;

  /// No description provided for @assetsSemi.
  ///
  /// In en, this message translates to:
  /// **'Semi'**
  String get assetsSemi;

  /// No description provided for @assetsIlliquid.
  ///
  /// In en, this message translates to:
  /// **'Illiquid'**
  String get assetsIlliquid;

  /// No description provided for @assetsGroupTotal.
  ///
  /// In en, this message translates to:
  /// **'Group Total'**
  String get assetsGroupTotal;

  /// No description provided for @assetsSetLiquidity.
  ///
  /// In en, this message translates to:
  /// **'Set Liquidity'**
  String get assetsSetLiquidity;

  /// No description provided for @assetsExitDate.
  ///
  /// In en, this message translates to:
  /// **'Exit Date'**
  String get assetsExitDate;

  /// No description provided for @assetsExitType.
  ///
  /// In en, this message translates to:
  /// **'Exit Type'**
  String get assetsExitType;

  /// No description provided for @assetsExitNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get assetsExitNone;

  /// No description provided for @assetsExitSingle.
  ///
  /// In en, this message translates to:
  /// **'Single Date'**
  String get assetsExitSingle;

  /// No description provided for @assetsExitSeries.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get assetsExitSeries;

  /// No description provided for @assetsExitSeriesStart.
  ///
  /// In en, this message translates to:
  /// **'Series Start Date'**
  String get assetsExitSeriesStart;

  /// No description provided for @assetsRepeatEvery.
  ///
  /// In en, this message translates to:
  /// **'Repeat Every'**
  String get assetsRepeatEvery;

  /// No description provided for @assetsRecurringIncome.
  ///
  /// In en, this message translates to:
  /// **'Recurring Income'**
  String get assetsRecurringIncome;

  /// No description provided for @assetsAmountPerInterval.
  ///
  /// In en, this message translates to:
  /// **'Amount per interval'**
  String get assetsAmountPerInterval;

  /// No description provided for @assetsSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get assetsSelectDate;

  /// No description provided for @assetsSelectExitDate.
  ///
  /// In en, this message translates to:
  /// **'Select exit date'**
  String get assetsSelectExitDate;

  /// No description provided for @assetsSelectStartDate.
  ///
  /// In en, this message translates to:
  /// **'Select start date'**
  String get assetsSelectStartDate;

  /// No description provided for @assetsCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get assetsCompany;

  /// No description provided for @assetsCompanyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. Tesla, Apple…'**
  String get assetsCompanyPlaceholder;

  /// No description provided for @boardTitle.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get boardTitle;

  /// No description provided for @boardAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get boardAddNote;

  /// No description provided for @boardNewNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get boardNewNote;

  /// No description provided for @boardNoteType.
  ///
  /// In en, this message translates to:
  /// **'Note type'**
  String get boardNoteType;

  /// No description provided for @boardTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get boardTypeText;

  /// No description provided for @boardTypeHeart.
  ///
  /// In en, this message translates to:
  /// **'Heart'**
  String get boardTypeHeart;

  /// No description provided for @boardTypeImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get boardTypeImage;

  /// No description provided for @boardNoteColor.
  ///
  /// In en, this message translates to:
  /// **'Note color'**
  String get boardNoteColor;

  /// No description provided for @boardHeartColor.
  ///
  /// In en, this message translates to:
  /// **'Heart color'**
  String get boardHeartColor;

  /// No description provided for @boardPost.
  ///
  /// In en, this message translates to:
  /// **'Post note'**
  String get boardPost;

  /// No description provided for @boardEmpty.
  ///
  /// In en, this message translates to:
  /// **'The board is empty'**
  String get boardEmpty;

  /// No description provided for @boardEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Be the first to post!'**
  String get boardEmptySubtitle;

  /// No description provided for @boardDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get boardDelete;

  /// No description provided for @boardDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this note?'**
  String get boardDeleteConfirm;

  /// No description provided for @boardDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get boardDeleteMessage;

  /// No description provided for @boardCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get boardCancel;

  /// No description provided for @boardJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get boardJustNow;

  /// No description provided for @boardLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get boardLoadFailed;

  /// No description provided for @boardSelectHousehold.
  ///
  /// In en, this message translates to:
  /// **'Select a household first.'**
  String get boardSelectHousehold;

  /// No description provided for @boardWritePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Write your note…'**
  String get boardWritePlaceholder;

  /// No description provided for @boardImagePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Paste image URL here…'**
  String get boardImagePlaceholder;

  /// No description provided for @boardTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get boardTryAgain;

  /// No description provided for @shoppingTab.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get shoppingTab;

  /// No description provided for @shoppingNewList.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get shoppingNewList;

  /// No description provided for @shoppingPickTemplate.
  ///
  /// In en, this message translates to:
  /// **'Use existing list as template'**
  String get shoppingPickTemplate;

  /// No description provided for @shoppingAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get shoppingAddItem;

  /// No description provided for @shoppingItemName.
  ///
  /// In en, this message translates to:
  /// **'Item name (English)'**
  String get shoppingItemName;

  /// No description provided for @shoppingItemNameHe.
  ///
  /// In en, this message translates to:
  /// **'Item name (Hebrew)'**
  String get shoppingItemNameHe;

  /// No description provided for @shoppingUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get shoppingUnit;

  /// No description provided for @shoppingAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get shoppingAmount;

  /// No description provided for @shoppingCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get shoppingCategory;

  /// No description provided for @shoppingStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get shoppingStore;

  /// No description provided for @shoppingAddStore.
  ///
  /// In en, this message translates to:
  /// **'Add store'**
  String get shoppingAddStore;

  /// No description provided for @shoppingGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get shoppingGotIt;

  /// No description provided for @shoppingPartial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get shoppingPartial;

  /// No description provided for @shoppingNope.
  ///
  /// In en, this message translates to:
  /// **'Nope'**
  String get shoppingNope;

  /// No description provided for @shoppingPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get shoppingPrice;

  /// No description provided for @shoppingNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get shoppingNote;

  /// No description provided for @shoppingListName.
  ///
  /// In en, this message translates to:
  /// **'List name'**
  String get shoppingListName;

  /// No description provided for @shoppingSave.
  ///
  /// In en, this message translates to:
  /// **'Save list'**
  String get shoppingSave;

  /// No description provided for @shoppingSearchItems.
  ///
  /// In en, this message translates to:
  /// **'Search items…'**
  String get shoppingSearchItems;

  /// No description provided for @shoppingNewItemTitle.
  ///
  /// In en, this message translates to:
  /// **'New Shopping Item'**
  String get shoppingNewItemTitle;

  /// No description provided for @shoppingSelectItems.
  ///
  /// In en, this message translates to:
  /// **'Select items for this list'**
  String get shoppingSelectItems;

  /// No description provided for @shoppingNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items yet. Create one!'**
  String get shoppingNoItems;

  /// No description provided for @shoppingSessionCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Shopping List'**
  String get shoppingSessionCardTitle;

  /// No description provided for @shoppingDeleteSession.
  ///
  /// In en, this message translates to:
  /// **'Delete list'**
  String get shoppingDeleteSession;

  /// No description provided for @shoppingAddNewCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get shoppingAddNewCategory;

  /// No description provided for @shoppingPlanForLater.
  ///
  /// In en, this message translates to:
  /// **'Plan this for later'**
  String get shoppingPlanForLater;

  /// No description provided for @shoppingPlanCategory.
  ///
  /// In en, this message translates to:
  /// **'Expense category'**
  String get shoppingPlanCategory;

  /// No description provided for @shoppingPlanMinPrice.
  ///
  /// In en, this message translates to:
  /// **'Min price'**
  String get shoppingPlanMinPrice;

  /// No description provided for @shoppingPlanMaxPrice.
  ///
  /// In en, this message translates to:
  /// **'Max price'**
  String get shoppingPlanMaxPrice;

  /// No description provided for @shoppingPlanMonth.
  ///
  /// In en, this message translates to:
  /// **'Pick month'**
  String get shoppingPlanMonth;

  /// No description provided for @shoppingPlanPickMonth.
  ///
  /// In en, this message translates to:
  /// **'Pick month for this plan'**
  String get shoppingPlanPickMonth;

  /// No description provided for @shoppingPlanWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get shoppingPlanWeek;

  /// No description provided for @shoppingPlanWholeMonth.
  ///
  /// In en, this message translates to:
  /// **'Whole month'**
  String get shoppingPlanWholeMonth;

  /// No description provided for @shoppingPlanAddToBudget.
  ///
  /// In en, this message translates to:
  /// **'Add to budget plan'**
  String get shoppingPlanAddToBudget;

  /// No description provided for @shoppingTotalSoFar.
  ///
  /// In en, this message translates to:
  /// **'Total so far'**
  String get shoppingTotalSoFar;

  /// No description provided for @shoppingSaveAndExit.
  ///
  /// In en, this message translates to:
  /// **'Save & exit'**
  String get shoppingSaveAndExit;

  /// No description provided for @shoppingDoneCreateExpense.
  ///
  /// In en, this message translates to:
  /// **'Done → Create expense'**
  String get shoppingDoneCreateExpense;

  /// No description provided for @shoppingCreateExpense.
  ///
  /// In en, this message translates to:
  /// **'Create expense'**
  String get shoppingCreateExpense;

  /// No description provided for @shoppingConfirmCreateExpense.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get shoppingConfirmCreateExpense;

  /// No description provided for @shoppingExpenseCreated.
  ///
  /// In en, this message translates to:
  /// **'Expense created'**
  String get shoppingExpenseCreated;

  /// No description provided for @shoppingCompleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create expense'**
  String get shoppingCompleteFailed;

  /// No description provided for @shoppingNoTotalYet.
  ///
  /// In en, this message translates to:
  /// **'Enter prices on items first'**
  String get shoppingNoTotalYet;

  /// No description provided for @shoppingMissingFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in amount and category'**
  String get shoppingMissingFields;

  /// No description provided for @categoryNewExpense.
  ///
  /// In en, this message translates to:
  /// **'New Expense Category'**
  String get categoryNewExpense;

  /// No description provided for @categoryNewIncome.
  ///
  /// In en, this message translates to:
  /// **'New Income Category'**
  String get categoryNewIncome;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get categoryName;

  /// No description provided for @categoryNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. Groceries'**
  String get categoryNamePlaceholder;

  /// No description provided for @categoryNameHe.
  ///
  /// In en, this message translates to:
  /// **'Hebrew Name (optional)'**
  String get categoryNameHe;

  /// No description provided for @categoryNameHePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'מכולת'**
  String get categoryNameHePlaceholder;

  /// No description provided for @categoryColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get categoryColor;

  /// No description provided for @categoryIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon (optional)'**
  String get categoryIcon;

  /// No description provided for @categoryIconSearch.
  ///
  /// In en, this message translates to:
  /// **'Search icons...'**
  String get categoryIconSearch;

  /// No description provided for @categoryCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get categoryCancel;

  /// No description provided for @categorySave.
  ///
  /// In en, this message translates to:
  /// **'Create Category'**
  String get categorySave;

  /// No description provided for @categoryFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create category'**
  String get categoryFailed;

  /// No description provided for @categoryFilterByCategory.
  ///
  /// In en, this message translates to:
  /// **'Filter by category'**
  String get categoryFilterByCategory;

  /// No description provided for @categorySearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get categorySearch;

  /// No description provided for @categoryFavorites.
  ///
  /// In en, this message translates to:
  /// **'Fav'**
  String get categoryFavorites;

  /// No description provided for @categoryEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get categoryEdit;

  /// No description provided for @categoryDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get categoryDelete;

  /// No description provided for @categoryDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this category?'**
  String get categoryDeleteConfirm;

  /// No description provided for @categoryDeleteRefs.
  ///
  /// In en, this message translates to:
  /// **'Also remove from all past expenses/incomes'**
  String get categoryDeleteRefs;

  /// No description provided for @categoryParent.
  ///
  /// In en, this message translates to:
  /// **'Parent Category (optional)'**
  String get categoryParent;

  /// No description provided for @categorySubNew.
  ///
  /// In en, this message translates to:
  /// **'New Sub-category'**
  String get categorySubNew;

  /// No description provided for @categoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get categoryGeneral;

  /// No description provided for @timelineTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get timelineTotal;

  /// No description provided for @timelineMonthly.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get timelineMonthly;

  /// No description provided for @timelineWeekly.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get timelineWeekly;

  /// No description provided for @timelineDaily.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get timelineDaily;

  /// No description provided for @timelineNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get timelineNoTransactions;

  /// No description provided for @timelineNoTransactionsMonth.
  ///
  /// In en, this message translates to:
  /// **'No transactions this month'**
  String get timelineNoTransactionsMonth;

  /// No description provided for @timelineNoTransactionsWeek.
  ///
  /// In en, this message translates to:
  /// **'No transactions this week'**
  String get timelineNoTransactionsWeek;

  /// No description provided for @timelineNoTransactionsDay.
  ///
  /// In en, this message translates to:
  /// **'No transactions today'**
  String get timelineNoTransactionsDay;

  /// No description provided for @timelinePrev.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get timelinePrev;

  /// No description provided for @timelineNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get timelineNext;

  /// No description provided for @timelineActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get timelineActions;

  /// No description provided for @timelineEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get timelineEdit;

  /// No description provided for @timelineDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get timelineDelete;

  /// No description provided for @timelineWk.
  ///
  /// In en, this message translates to:
  /// **'Wk'**
  String get timelineWk;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get commonError;

  /// No description provided for @commonNoHousehold.
  ///
  /// In en, this message translates to:
  /// **'No household selected'**
  String get commonNoHousehold;

  /// No description provided for @commonNoHouseholdMsg.
  ///
  /// In en, this message translates to:
  /// **'Please contact an admin to be added to a household.'**
  String get commonNoHouseholdMsg;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'(optional)'**
  String get commonOptional;

  /// No description provided for @commonNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get commonNew;

  /// No description provided for @commonDeleteExpense.
  ///
  /// In en, this message translates to:
  /// **'Delete expense?'**
  String get commonDeleteExpense;

  /// No description provided for @commonDeleteIncome.
  ///
  /// In en, this message translates to:
  /// **'Delete income?'**
  String get commonDeleteIncome;

  /// No description provided for @commonDeleteAsset.
  ///
  /// In en, this message translates to:
  /// **'Delete asset?'**
  String get commonDeleteAsset;

  /// No description provided for @commonThisMonthSummary.
  ///
  /// In en, this message translates to:
  /// **'This month\'s summary'**
  String get commonThisMonthSummary;

  /// No description provided for @commonNetBalance.
  ///
  /// In en, this message translates to:
  /// **'Net Balance'**
  String get commonNetBalance;

  /// No description provided for @commonRecentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get commonRecentTransactions;

  /// No description provided for @commonNoTransactionsMonth.
  ///
  /// In en, this message translates to:
  /// **'No transactions this month'**
  String get commonNoTransactionsMonth;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get commonYesterday;

  /// No description provided for @commonExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get commonExpense;

  /// No description provided for @commonIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get commonIncome;

  /// No description provided for @homeStartBalance.
  ///
  /// In en, this message translates to:
  /// **'Starting Balance'**
  String get homeStartBalance;

  /// No description provided for @homePredicted.
  ///
  /// In en, this message translates to:
  /// **'Predicted'**
  String get homePredicted;

  /// No description provided for @homeConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get homeConfirmed;

  /// No description provided for @homePredictedEnd.
  ///
  /// In en, this message translates to:
  /// **'Predicted End'**
  String get homePredictedEnd;

  /// No description provided for @homeSetStartBalance.
  ///
  /// In en, this message translates to:
  /// **'Set Starting Balance'**
  String get homeSetStartBalance;

  /// No description provided for @cardsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get cardsPageTitle;

  /// No description provided for @cardsNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get cardsNone;

  /// No description provided for @cardsAddCard.
  ///
  /// In en, this message translates to:
  /// **'Add Card'**
  String get cardsAddCard;

  /// No description provided for @cardsEditCard.
  ///
  /// In en, this message translates to:
  /// **'Edit Card'**
  String get cardsEditCard;

  /// No description provided for @cardsLastFour.
  ///
  /// In en, this message translates to:
  /// **'Last 4 digits'**
  String get cardsLastFour;

  /// No description provided for @cardsNickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get cardsNickname;

  /// No description provided for @cardsBankName.
  ///
  /// In en, this message translates to:
  /// **'Bank name'**
  String get cardsBankName;

  /// No description provided for @cardsTypeCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit'**
  String get cardsTypeCredit;

  /// No description provided for @cardsTypeDebit.
  ///
  /// In en, this message translates to:
  /// **'Debit'**
  String get cardsTypeDebit;

  /// No description provided for @cardsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this card?'**
  String get cardsDeleteConfirm;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get settingsTextSize;

  /// No description provided for @settingsTextSizeHint.
  ///
  /// In en, this message translates to:
  /// **'Default follows your device setting'**
  String get settingsTextSizeHint;

  /// No description provided for @settingsTextSizePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview text'**
  String get settingsTextSizePreview;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Toggle between English and Hebrew'**
  String get settingsLanguageHint;

  /// No description provided for @settingsFinancialMonth.
  ///
  /// In en, this message translates to:
  /// **'Financial month'**
  String get settingsFinancialMonth;

  /// No description provided for @settingsFinancialMonthHint.
  ///
  /// In en, this message translates to:
  /// **'Pick the day each financial month starts. The month then runs until the day before, of the following month.'**
  String get settingsFinancialMonthHint;

  /// No description provided for @settingsFinancialMonthDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Starts on day'**
  String get settingsFinancialMonthDayLabel;

  /// No description provided for @settingsFinancialMonthRange.
  ///
  /// In en, this message translates to:
  /// **'Day {start} of one month – day {end} of the next'**
  String settingsFinancialMonthRange(Object end, Object start);

  /// No description provided for @settingsFinancialMonthCalendarRange.
  ///
  /// In en, this message translates to:
  /// **'1st – last day of each month'**
  String get settingsFinancialMonthCalendarRange;

  /// No description provided for @settingsFinancialMonthPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Start the financial month on…'**
  String get settingsFinancialMonthPickerTitle;

  /// No description provided for @settingsFinancialMonthSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Please try again.'**
  String get settingsFinancialMonthSaveError;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0'**
  String get settingsVersion;

  /// No description provided for @settingsAppName.
  ///
  /// In en, this message translates to:
  /// **'Household Finance Manager'**
  String get settingsAppName;

  /// No description provided for @drawerSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get drawerSettings;

  /// No description provided for @drawerSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get drawerSignOut;

  /// No description provided for @categoryTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get categoryTranslate;

  /// No description provided for @categoryTranslating.
  ///
  /// In en, this message translates to:
  /// **'Translating...'**
  String get categoryTranslating;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsTitle;

  /// No description provided for @statsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get statsThisMonth;

  /// No description provided for @statsSavingsRate.
  ///
  /// In en, this message translates to:
  /// **'Savings rate'**
  String get statsSavingsRate;

  /// No description provided for @statsTopCategories.
  ///
  /// In en, this message translates to:
  /// **'Top expense categories'**
  String get statsTopCategories;

  /// No description provided for @statsMonthlyTrend.
  ///
  /// In en, this message translates to:
  /// **'Monthly trend'**
  String get statsMonthlyTrend;

  /// No description provided for @statsBiggestExpense.
  ///
  /// In en, this message translates to:
  /// **'Biggest expense category'**
  String get statsBiggestExpense;

  /// No description provided for @statsPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'By payment method'**
  String get statsPaymentMethods;

  /// No description provided for @statsAvgMonthlyExpense.
  ///
  /// In en, this message translates to:
  /// **'Avg. monthly expense'**
  String get statsAvgMonthlyExpense;

  /// No description provided for @statsNoData.
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet'**
  String get statsNoData;

  /// No description provided for @statsLast4Months.
  ///
  /// In en, this message translates to:
  /// **'Last 4 months'**
  String get statsLast4Months;

  /// No description provided for @transactionsInstallmentsOnly.
  ///
  /// In en, this message translates to:
  /// **'Installments only'**
  String get transactionsInstallmentsOnly;

  /// No description provided for @recurringTitle.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurringTitle;

  /// No description provided for @recurringNew.
  ///
  /// In en, this message translates to:
  /// **'New Recurring Expense'**
  String get recurringNew;

  /// No description provided for @recurringEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Recurring Expense'**
  String get recurringEdit;

  /// No description provided for @recurringBadge.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurringBadge;

  /// No description provided for @recurringDayOfMonth.
  ///
  /// In en, this message translates to:
  /// **'Day of month'**
  String get recurringDayOfMonth;

  /// No description provided for @recurringAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Recurring'**
  String get recurringAdd;

  /// No description provided for @recurringSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get recurringSave;

  /// No description provided for @recurringDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get recurringDelete;

  /// No description provided for @recurringDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this recurring expense?'**
  String get recurringDeleteConfirm;

  /// No description provided for @recurringDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'It will stop appearing in future months.'**
  String get recurringDeleteMessage;

  /// No description provided for @recurringStartMonth.
  ///
  /// In en, this message translates to:
  /// **'Starting from'**
  String get recurringStartMonth;

  /// No description provided for @recurringNoItems.
  ///
  /// In en, this message translates to:
  /// **'No recurring expenses yet'**
  String get recurringNoItems;

  /// No description provided for @recurringGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Recurring Expenses'**
  String get recurringGroupLabel;

  /// No description provided for @scheduleSettingsSection.
  ///
  /// In en, this message translates to:
  /// **'Automation'**
  String get scheduleSettingsSection;

  /// No description provided for @scheduleSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Expense Schedules'**
  String get scheduleSettingsTitle;

  /// No description provided for @scheduleSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Define which expenses to expect on specific days'**
  String get scheduleSettingsSubtitle;

  /// No description provided for @schedulesScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Expense Schedules'**
  String get schedulesScreenTitle;

  /// No description provided for @scheduleNew.
  ///
  /// In en, this message translates to:
  /// **'New Schedule'**
  String get scheduleNew;

  /// No description provided for @scheduleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Schedule'**
  String get scheduleEdit;

  /// No description provided for @scheduleDescription.
  ///
  /// In en, this message translates to:
  /// **'Description *'**
  String get scheduleDescription;

  /// No description provided for @scheduleDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Office parking'**
  String get scheduleDescriptionHint;

  /// No description provided for @scheduleCategory.
  ///
  /// In en, this message translates to:
  /// **'Category *'**
  String get scheduleCategory;

  /// No description provided for @scheduleDays.
  ///
  /// In en, this message translates to:
  /// **'Active days *'**
  String get scheduleDays;

  /// No description provided for @scheduleDaysHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the days when this expense is expected.'**
  String get scheduleDaysHint;

  /// No description provided for @scheduleAmount.
  ///
  /// In en, this message translates to:
  /// **'Default amount (optional)'**
  String get scheduleAmount;

  /// No description provided for @scheduleAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to ask each time'**
  String get scheduleAmountHint;

  /// No description provided for @schedulePaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Default payment method (optional)'**
  String get schedulePaymentMethod;

  /// No description provided for @scheduleActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get scheduleActive;

  /// No description provided for @scheduleNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get scheduleNote;

  /// No description provided for @scheduleSave.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get scheduleSave;

  /// No description provided for @scheduleAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Schedule'**
  String get scheduleAdd;

  /// No description provided for @scheduleDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this schedule?'**
  String get scheduleDeleteConfirm;

  /// No description provided for @scheduleDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This will stop the daily suggestion.'**
  String get scheduleDeleteMessage;

  /// No description provided for @scheduleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No schedules yet'**
  String get scheduleEmpty;

  /// No description provided for @scheduleEmptySub.
  ///
  /// In en, this message translates to:
  /// **'Tap + to define when you expect an expense.\nThe app will remind you on those days.'**
  String get scheduleEmptySub;

  /// No description provided for @scheduleLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load schedules.'**
  String get scheduleLoadFailed;

  /// No description provided for @scheduleSuggestionLabel.
  ///
  /// In en, this message translates to:
  /// **'Expected today:'**
  String get scheduleSuggestionLabel;

  /// No description provided for @constantExpensesLabel.
  ///
  /// In en, this message translates to:
  /// **'Constant Expenses'**
  String get constantExpensesLabel;

  /// No description provided for @scheduleDaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get scheduleDaySun;

  /// No description provided for @scheduleDayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get scheduleDayMon;

  /// No description provided for @scheduleDayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get scheduleDayTue;

  /// No description provided for @scheduleDayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get scheduleDayWed;

  /// No description provided for @scheduleDayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get scheduleDayThu;

  /// No description provided for @scheduleDayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get scheduleDayFri;

  /// No description provided for @scheduleDaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get scheduleDaySat;

  /// No description provided for @attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachments;

  /// No description provided for @attachmentsAddCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get attachmentsAddCamera;

  /// No description provided for @attachmentsAddFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get attachmentsAddFiles;

  /// No description provided for @attachmentsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get attachmentsRemove;

  /// No description provided for @attachmentsName.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get attachmentsName;

  /// No description provided for @attachmentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 attachment} other{{count} attachments}}'**
  String attachmentsCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'he':
      return AppLocalizationsHe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
