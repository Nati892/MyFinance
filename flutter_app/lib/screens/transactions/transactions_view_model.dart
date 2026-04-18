import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/models/category.dart';
import 'package:household/models/credit_card.dart';
import 'package:household/models/expense.dart';
import 'package:household/models/income.dart';
import 'package:household/models/recurring_expense.dart';
import 'package:household/models/expense_schedule.dart';
import 'package:household/repositories/category_repository.dart';
import 'package:household/services/credit_card_service.dart';
import 'package:household/services/household_service.dart';
import 'package:household/services/transaction_service.dart';
import 'package:household/widgets/transaction_timeline.dart';

final transactionsViewModelProvider =
    ChangeNotifierProvider.autoDispose<TransactionsViewModel>((ref) {
  return TransactionsViewModel(
    ref.read(transactionServiceProvider),
    ref.read(categoryRepositoryProvider),
    ref.read(householdServiceProvider),
    ref.read(creditCardServiceProvider),
  );
});

enum TransactionsLoadState { idle, loading, error }

class TransactionsViewModel extends ChangeNotifier {
  final TransactionService _txService;
  final CategoryRepository _categoryRepo;
  final HouseholdService _householdService;
  final CreditCardService _cardService;

  TransactionsViewModel(
      this._txService, this._categoryRepo, this._householdService, this._cardService) {
    load();
    loadCards();
  }

  List<CreditCard> get cards => _cardService.cards;

  // ── Data ───────────────────────────────────────────────────────────────────
  List<Expense> expenses = [];
  List<Income> incomes = [];
  List<RecurringExpense> recurringExpenses = [];
  List<Category> expenseCategories = [];
  List<Category> incomeCategories = [];
  List<Category> expenseFavoriteCategories = [];

  // Today's schedule suggestions (loaded on init, dismissed per session)
  List<ExpenseSchedule> todayScheduleSuggestions = [];
  final Set<int> _dismissedSuggestionIds = {};
  List<ExpenseSchedule> get visibleSuggestions => todayScheduleSuggestions
      .where((s) => !_dismissedSuggestionIds.contains(s.id))
      .toList();

  // ── State ──────────────────────────────────────────────────────────────────
  TransactionsLoadState state = TransactionsLoadState.loading;
  String? errorMessage;

  // ── View config ────────────────────────────────────────────────────────────
  String viewType = 'monthly'; // 'monthly' | 'weekly' | 'daily'
  int periodOffset = 0;
  int? weekNumber;
  String? date;

  /// 'all' | 'expenses' | 'incomes'
  String viewMode = 'all';

  /// Category filter (applies to combined list by category id)
  int? filterCategoryId;

  /// Optional price range filter
  double? priceMin;
  double? priceMax;

  /// When true, only show expenses that have multiple installments
  bool filterInstallmentsOnly = false;

  bool get noHousehold => _householdService.currentHouseholdId == null;
  int get householdId => _householdService.currentHouseholdId ?? 0;

  // Sidebar shows combined deduped categories
  List<Category> get allCategories {
    final seen = <int>{};
    final combined = <Category>[];
    for (final c in [...expenseCategories, ...incomeCategories]) {
      if (seen.add(c.id)) combined.add(c);
    }
    return combined;
  }

  List<Category> get favoriteCategories => expenseFavoriteCategories;

  /// The filtered + combined list of TimelineTx items to show.
  List<TimelineTx> get filteredTransactions {
    final List<TimelineTx> all = [];

    // Build parent lookup: subcategoryId → parent Category
    final parentLookup = <int, Category>{};
    for (final cat in [...expenseCategories, ...incomeCategories]) {
      for (final sub in cat.subCategories) {
        parentLookup[sub.id] = cat;
      }
    }

    if (viewMode != 'incomes') {
      all.addAll(expenses.map((e) => TimelineTx.fromExpense(e, parentLookup: parentLookup)));
    }
    if (viewMode != 'expenses') {
      all.addAll(incomes.map((i) => TimelineTx.fromIncome(i, parentLookup: parentLookup)));
    }

    return all.where((tx) {
      if (filterCategoryId != null) {
        // look up the category id from the original objects
        if (tx.txType == 'expense') {
          final e = expenses.firstWhere((x) => x.id == tx.id,
              orElse: () => expenses.first);
          if (e.category?.id != filterCategoryId) return false;
        } else {
          final i = incomes.firstWhere((x) => x.id == tx.id,
              orElse: () => incomes.first);
          if (i.category?.id != filterCategoryId) return false;
        }
      }
      if (filterInstallmentsOnly) {
        if (tx.txType != 'expense') return false;
        final e = expenses.firstWhere((x) => x.id == tx.id,
            orElse: () => expenses.first);
        if ((e.installmentTotal ?? 1) <= 1) return false;
      }
      if (priceMin != null && tx.amount < priceMin!) return false;
      if (priceMax != null && tx.amount > priceMax!) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  // ── Modal state ────────────────────────────────────────────────────────────
  bool modalOpen = false;
  bool modalSaving = false;
  String? modalError;
  bool isEditMode = false;
  int? editingId;
  /// true = expense form, false = income form
  bool isExpenseMode = true;

  // Form fields (shared between expense/income forms)
  double? formAmount;
  double? _originalAmount; // tracks amount at edit-open time for installment change detection
  int? formCategoryId;
  DateTime formDateTime = DateTime.now();
  String formPaymentMethod = 'card';
  int? formCardId;
  String formDescription = '';
  String formNote = '';
  int formInstallmentTotal = 1;
  int formInstallmentCurrent = 1;

  // Recurring fields (used when formIsRecurring == true)
  bool formIsRecurring = false;
  int formDayOfMonth = 10;
  int formDayOfMonthStartYear = DateTime.now().year;
  int formDayOfMonthStartMonth = DateTime.now().month;

  // ── Load ───────────────────────────────────────────────────────────────────

  void load() {
    loadCategories();
    loadTransactions();
    loadTodaySuggestions();
  }

  Future<void> loadCategories() async {
    final hid = _householdService.currentHouseholdId;
    if (hid == null) return;
    try {
      final results = await Future.wait([
        _categoryRepo.getExpenseCategories(hid),
        _categoryRepo.getIncomeCategories(hid),
        _categoryRepo.getExpenseFavorites(hid),
      ]);
      expenseCategories = results[0];
      incomeCategories = results[1];
      expenseFavoriteCategories = results[2];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadTransactions() async {
    state = TransactionsLoadState.loading;
    notifyListeners();
    try {
      final results = await Future.wait([
        _txService.getExpenses(
          view: viewType,
          periodOffset: periodOffset,
          weekNumber: weekNumber,
          date: date,
        ),
        _txService.getIncomes(
          view: viewType,
          periodOffset: periodOffset,
          weekNumber: weekNumber,
          date: date,
        ),
        _txService.getRecurringExpenses(),
      ]);
      expenses          = results[0] as List<Expense>;
      incomes           = results[1] as List<Income>;
      recurringExpenses = results[2] as List<RecurringExpense>;
      state = TransactionsLoadState.idle;
    } catch (e) {
      state = TransactionsLoadState.error;
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> loadTodaySuggestions() async {
    final hid = _householdService.currentHouseholdId;
    if (hid == null) return;
    try {
      todayScheduleSuggestions = await _txService.getTodayScheduleSuggestions();
      notifyListeners();
    } catch (_) {
      // Suggestions are non-critical — silently ignore errors
    }
  }

  void dismissSuggestion(int scheduleId) {
    _dismissedSuggestionIds.add(scheduleId);
    notifyListeners();
  }

  /// Pre-fills the expense form from a schedule suggestion and opens it.
  void openQuickAddFromSchedule(ExpenseSchedule schedule) {
    isExpenseMode = true;
    isEditMode = false;
    editingId = null;
    modalError = null;
    formAmount = schedule.amount;
    formCategoryId = schedule.expenseCategoryId;
    formDateTime = DateTime.now();
    formPaymentMethod = schedule.paymentMethod ?? 'card';
    formCardId = null;
    formDescription = schedule.description;
    formNote = '';
    formInstallmentTotal = 1;
    formInstallmentCurrent = 1;
    formIsRecurring = false;
    modalOpen = true;
    notifyListeners();
  }

  // ── View config changes ────────────────────────────────────────────────────

  void onViewChanged({
    required String view,
    required int offset,
    int? week,
    String? dayDate,
  }) {
    viewType = view;
    periodOffset = offset;
    weekNumber = week;
    date = dayDate;
    loadTransactions();
  }

  void onCategorySelected(int? categoryId) {
    filterCategoryId = categoryId;
    notifyListeners();
  }

  void onCategoryQuickAdd(int categoryId) {
    // Determine if this category belongs to expense or income
    final isExpense = expenseCategories
        .expand((c) => c.flatList)
        .any((c) => c.id == categoryId);
    if (isExpense) {
      openAddExpenseModal(categoryId: categoryId);
    } else {
      openAddIncomeModal(categoryId: categoryId);
    }
  }

  void setViewMode(String mode) {
    viewMode = mode;
    notifyListeners();
  }

  void setPriceMin(double? v) {
    priceMin = v;
    notifyListeners();
  }

  void setPriceMax(double? v) {
    priceMax = v;
    notifyListeners();
  }

  void setInstallmentsFilter(bool v) {
    filterInstallmentsOnly = v;
    notifyListeners();
  }

  /// True when saving an edited installment expense where the amount changed.
  /// In this case the UI must ask the user which records to update.
  bool get shouldAskInstallmentScope =>
      isEditMode &&
      isExpenseMode &&
      formInstallmentTotal > 1 &&
      formAmount != null &&
      _originalAmount != null &&
      formAmount != _originalAmount;

  // ── Modal open/close ───────────────────────────────────────────────────────

  void openAddExpenseModal({int? categoryId}) {
    isExpenseMode = true;
    isEditMode = false;
    editingId = null;
    modalError = null;
    formAmount = null;
    formCategoryId = categoryId ?? filterCategoryId;
    formDateTime = DateTime.now();
    formPaymentMethod = 'card';
    formCardId = null;
    formDescription = '';
    formNote = '';
    formInstallmentTotal = 1;
    formInstallmentCurrent = 1;
    formIsRecurring = false;
    formDayOfMonth = 10;
    formDayOfMonthStartYear = DateTime.now().year;
    formDayOfMonthStartMonth = DateTime.now().month;
    modalOpen = true;
    notifyListeners();
  }

  void openAddIncomeModal({int? categoryId}) {
    isExpenseMode = false;
    isEditMode = false;
    editingId = null;
    modalError = null;
    formAmount = null;
    formCategoryId = categoryId ?? filterCategoryId;
    formDateTime = DateTime.now();
    formPaymentMethod = 'card';
    formCardId = null;
    formDescription = '';
    formNote = '';
    modalOpen = true;
    notifyListeners();
  }

  void openEditExpenseModal(Expense expense) {
    isExpenseMode = true;
    isEditMode = true;
    editingId = expense.id;
    modalError = null;
    formAmount = expense.amount;
    _originalAmount = expense.amount;
    formCategoryId = expense.category?.id;
    formDateTime = DateTime.parse(expense.dateTime).toLocal();
    final pm = expense.paymentMethod;
    formPaymentMethod = (pm == 'credit_card' || pm == 'debit_card') ? 'card' : pm;
    formCardId = expense.cardId;
    formDescription = expense.description ?? '';
    formNote = expense.note ?? '';
    formInstallmentTotal = expense.installmentTotal ?? 1;
    formInstallmentCurrent = expense.installmentCurrent ?? 1;
    formIsRecurring = false;
    modalOpen = true;
    notifyListeners();
  }

  void openEditRecurringAsExpenseModal(RecurringExpense rec) {
    isExpenseMode = true;
    isEditMode = true;
    editingId = rec.id;
    modalError = null;
    formIsRecurring = true;
    formAmount = rec.amount;
    formCategoryId = rec.category?.id ?? rec.expenseCategoryId;
    formPaymentMethod = rec.paymentMethod;
    formCardId = null;
    formDescription = rec.description ?? '';
    formNote = rec.note ?? '';
    formDayOfMonth = rec.dayOfMonth;
    formDayOfMonthStartYear = rec.startYear;
    formDayOfMonthStartMonth = rec.startMonth;
    modalOpen = true;
    notifyListeners();
  }

  void openEditIncomeModal(Income income) {
    isExpenseMode = false;
    isEditMode = true;
    editingId = income.id;
    modalError = null;
    formAmount = income.amount;
    formCategoryId = income.category?.id;
    formDateTime = DateTime.parse(income.dateTime).toLocal();
    final pm = income.paymentMethod;
    formPaymentMethod = (pm == 'credit_card' || pm == 'debit_card') ? 'card' : pm;
    formCardId = income.cardId;
    formDescription = income.description ?? '';
    formNote = income.note ?? '';
    modalOpen = true;
    notifyListeners();
  }

  void closeModal() {
    modalOpen = false;
    modalError = null;
    notifyListeners();
  }

  void setFormAmount(double? v) { formAmount = v; notifyListeners(); }
  void setFormCategory(int? id)  { formCategoryId = id; notifyListeners(); }
  void setFormDateTime(DateTime dt) { formDateTime = dt; notifyListeners(); }
  void setFormPayment(String method) {
    formPaymentMethod = method;
    if (method != 'card') formCardId = null;
    notifyListeners();
  }
  void setFormCardId(int? id) { formCardId = id; notifyListeners(); }
  void setFormDescription(String v) { formDescription = v; notifyListeners(); }
  void setFormNote(String v) { formNote = v; notifyListeners(); }
  void setFormInstallmentTotal(int v) { formInstallmentTotal = v.clamp(1, 99); notifyListeners(); }
  void setFormInstallmentCurrent(int v) { formInstallmentCurrent = v.clamp(1, formInstallmentTotal); notifyListeners(); }
  void setFormIsRecurring(bool v) { formIsRecurring = v; notifyListeners(); }
  void setFormDayOfMonth(int v) { formDayOfMonth = v.clamp(1, 28); notifyListeners(); }
  void setFormDayOfMonthStartYear(int v) { formDayOfMonthStartYear = v; notifyListeners(); }
  void setFormDayOfMonthStartMonth(int v) { formDayOfMonthStartMonth = v.clamp(1, 12); notifyListeners(); }

  // ── Recurring expense form state (for RecurringExpenseFormSheet) ───────────
  double? recurringFormAmount;
  int? recurringFormCategoryId;
  String recurringFormDescription = '';
  String recurringFormNote = '';
  int recurringFormDayOfMonth = 10;
  int recurringFormStartMonth = DateTime.now().month;
  int recurringFormStartYear = DateTime.now().year;
  String recurringFormPaymentMethod = 'bank_transfer';
  bool recurringIsEditMode = false;
  int? recurringEditingId;
  String? recurringModalError;
  bool recurringModalSaving = false;

  void setRecurringFormAmount(double? v) { recurringFormAmount = v; notifyListeners(); }
  void setRecurringFormCategory(int? id) { recurringFormCategoryId = id; notifyListeners(); }
  void setRecurringFormDescription(String v) { recurringFormDescription = v; notifyListeners(); }
  void setRecurringFormNote(String v) { recurringFormNote = v; notifyListeners(); }
  void setRecurringFormDay(int v) { recurringFormDayOfMonth = v.clamp(1, 28); notifyListeners(); }
  void setRecurringFormStartMonth(int v) { recurringFormStartMonth = v.clamp(1, 12); notifyListeners(); }
  void setRecurringFormStartYear(int v) { recurringFormStartYear = v; notifyListeners(); }
  void setRecurringFormPayment(String v) { recurringFormPaymentMethod = v; notifyListeners(); }

  void openAddRecurringModal() {
    recurringIsEditMode = false;
    recurringEditingId = null;
    recurringFormAmount = null;
    recurringFormCategoryId = null;
    recurringFormDescription = '';
    recurringFormNote = '';
    recurringFormDayOfMonth = 10;
    recurringFormStartMonth = DateTime.now().month;
    recurringFormStartYear = DateTime.now().year;
    recurringFormPaymentMethod = 'bank_transfer';
    recurringModalError = null;
    notifyListeners();
  }

  void openEditRecurringModal(RecurringExpense rec) {
    recurringIsEditMode = true;
    recurringEditingId = rec.id;
    recurringFormAmount = rec.amount;
    recurringFormCategoryId = rec.expenseCategoryId;
    recurringFormDescription = rec.description ?? '';
    recurringFormNote = rec.note ?? '';
    recurringFormDayOfMonth = rec.dayOfMonth;
    recurringFormStartMonth = rec.startMonth;
    recurringFormStartYear = rec.startYear;
    recurringFormPaymentMethod = rec.paymentMethod;
    recurringModalError = null;
    notifyListeners();
  }

  Future<void> saveRecurring() async {
    if (recurringFormAmount == null || recurringFormAmount! <= 0) {
      recurringModalError = 'Please enter a valid amount.';
      notifyListeners();
      return;
    }
    if (recurringFormCategoryId == null) {
      recurringModalError = 'Please select a category.';
      notifyListeners();
      return;
    }
    recurringModalSaving = true;
    recurringModalError = null;
    notifyListeners();
    try {
      if (!recurringIsEditMode) {
        await _txService.createRecurringExpense(
          amount: recurringFormAmount!,
          expenseCategoryId: recurringFormCategoryId!,
          paymentMethod: recurringFormPaymentMethod,
          dayOfMonth: recurringFormDayOfMonth,
          startYear: recurringFormStartYear,
          startMonth: recurringFormStartMonth,
          description: recurringFormDescription.isNotEmpty ? recurringFormDescription : null,
          note: recurringFormNote.isNotEmpty ? recurringFormNote : null,
        );
      } else {
        await _txService.updateRecurringExpense(recurringEditingId!, {
          'amount': recurringFormAmount,
          'expenseCategoryId': recurringFormCategoryId,
          'paymentMethod': recurringFormPaymentMethod,
          'dayOfMonth': recurringFormDayOfMonth,
          'startYear': recurringFormStartYear,
          'startMonth': recurringFormStartMonth,
          'description': recurringFormDescription,
          'note': recurringFormNote,
        });
      }
      recurringModalSaving = false;
      notifyListeners();
      loadTransactions();
    } catch (_) {
      recurringModalSaving = false;
      recurringModalError = 'Failed to save. Please try again.';
      notifyListeners();
    }
  }

  Future<void> deleteRecurring(int id) async {
    try {
      await _txService.deleteRecurringExpense(id);
      loadTransactions();
    } catch (_) {}
  }

  // ── Save / Delete ──────────────────────────────────────────────────────────

  /// Called when the user has chosen a scope for an installment amount update.
  /// Handles the amount-only update for the chosen scope, then saves the rest
  /// of the fields via the normal update path.
  Future<void> saveExpenseWithScope(String scope) async {
    if (formAmount == null || formAmount! <= 0 || editingId == null) return;

    modalSaving = true;
    modalError = null;
    notifyListeners();

    try {
      // Update amount across the installment group according to scope
      await _txService.updateExpenseInstallmentAmount(editingId!, formAmount!, scope);

      // Update the remaining non-amount fields via the normal endpoint
      final isoDateTime = formDateTime.toUtc().toIso8601String();
      await _txService.updateExpense(editingId!, {
        'dateTime': isoDateTime,
        'paymentMethod': formPaymentMethod,
        'cardId': formPaymentMethod == 'card' ? formCardId : null,
        'expenseCategoryId': formCategoryId,
        'description': formDescription,
        'note': formNote,
        if (formInstallmentTotal > 1) 'installmentTotal': formInstallmentTotal,
        if (formInstallmentTotal > 1) 'installmentCurrent': formInstallmentCurrent,
        if (formInstallmentTotal == 1) 'installmentTotal': null,
        if (formInstallmentTotal == 1) 'installmentCurrent': null,
      });

      modalSaving = false;
      modalOpen = false;
      notifyListeners();
      load();
    } catch (e) {
      modalSaving = false;
      modalError = 'Failed to save. Please try again.';
      notifyListeners();
    }
  }

  Future<void> saveExpense() async {
    if (formAmount == null || formAmount! <= 0) {
      modalError = 'Please enter a valid amount.';
      notifyListeners();
      return;
    }
    if (formCategoryId == null) {
      modalError = 'Please select a category.';
      notifyListeners();
      return;
    }

    modalSaving = true;
    modalError = null;
    notifyListeners();

    try {
      if (formIsRecurring && !isEditMode) {
        await _txService.createRecurringExpense(
          amount: formAmount!,
          expenseCategoryId: formCategoryId!,
          paymentMethod: formPaymentMethod,
          dayOfMonth: formDayOfMonth,
          startYear: formDayOfMonthStartYear,
          startMonth: formDayOfMonthStartMonth,
          description: formDescription.isNotEmpty ? formDescription : null,
          note: formNote.isNotEmpty ? formNote : null,
        );
      } else if (formIsRecurring && isEditMode) {
        await _txService.updateRecurringExpense(editingId!, {
          'amount': formAmount,
          'expenseCategoryId': formCategoryId,
          'paymentMethod': formPaymentMethod,
          'dayOfMonth': formDayOfMonth,
          'startYear': formDayOfMonthStartYear,
          'startMonth': formDayOfMonthStartMonth,
          'description': formDescription,
          'note': formNote,
        });
      } else {
        final isoDateTime = formDateTime.toUtc().toIso8601String();

        if (!isEditMode) {
          final splitAmount = formInstallmentTotal > 1
              ? formAmount! / formInstallmentTotal
              : formAmount!;
          await _txService.createExpense(
            amount: splitAmount,
            dateTime: isoDateTime,
            paymentMethod: formPaymentMethod,
            expenseCategoryId: formCategoryId!,
            description: formDescription.isNotEmpty ? formDescription : null,
            note: formNote.isNotEmpty ? formNote : null,
            cardId: formPaymentMethod == 'card' ? formCardId : null,
            installmentTotal: formInstallmentTotal > 1 ? formInstallmentTotal : null,
            installmentCurrent: formInstallmentTotal > 1 ? formInstallmentCurrent : null,
          );
        } else {
          await _txService.updateExpense(editingId!, {
            'amount': formAmount,
            'dateTime': isoDateTime,
            'paymentMethod': formPaymentMethod,
            'cardId': formPaymentMethod == 'card' ? formCardId : null,
            'expenseCategoryId': formCategoryId,
            'description': formDescription,
            'note': formNote,
            if (formInstallmentTotal > 1) 'installmentTotal': formInstallmentTotal,
            if (formInstallmentTotal > 1) 'installmentCurrent': formInstallmentCurrent,
            if (formInstallmentTotal == 1) 'installmentTotal': null,
            if (formInstallmentTotal == 1) 'installmentCurrent': null,
          });
        }
      }

      modalSaving = false;
      modalOpen = false;
      notifyListeners();
      load();
    } catch (e) {
      modalSaving = false;
      modalError = 'Failed to save. Please try again.';
      notifyListeners();
    }
  }

  Future<void> deleteRecurringFromExpenseForm() async {
    if (editingId == null) return;
    try {
      await _txService.deleteRecurringExpense(editingId!);
      modalOpen = false;
      notifyListeners();
      loadTransactions();
    } catch (_) {}
  }

  Future<void> saveIncome() async {
    if (formAmount == null || formAmount! <= 0) {
      modalError = 'Please enter a valid amount.';
      notifyListeners();
      return;
    }
    if (formCategoryId == null) {
      modalError = 'Please select a category.';
      notifyListeners();
      return;
    }

    modalSaving = true;
    modalError = null;
    notifyListeners();

    try {
      final isoDateTime = formDateTime.toUtc().toIso8601String();

      if (!isEditMode) {
        await _txService.createIncome(
          amount: formAmount!,
          dateTime: isoDateTime,
          paymentMethod: formPaymentMethod,
          incomeCategoryId: formCategoryId!,
          description: formDescription.isNotEmpty ? formDescription : null,
          note: formNote.isNotEmpty ? formNote : null,
          cardId: formPaymentMethod == 'card' ? formCardId : null,
        );
      } else {
        await _txService.updateIncome(editingId!, {
          'amount': formAmount,
          'dateTime': isoDateTime,
          'paymentMethod': formPaymentMethod,
          'cardId': formPaymentMethod == 'card' ? formCardId : null,
          'incomeCategoryId': formCategoryId,
          'description': formDescription,
          'note': formNote,
        });
      }

      modalSaving = false;
      modalOpen = false;
      notifyListeners();
      load();
    } catch (e) {
      modalSaving = false;
      modalError = 'Failed to save. Please try again.';
      notifyListeners();
    }
  }

  // ── Frequent amounts helper ────────────────────────────────────────────────

  /// Returns the top 5–7 most-used amounts for the given category id,
  /// computed from already-loaded transactions for the current period.
  List<double> getTopAmountsForCategory(int? categoryId, {bool isExpense = true}) {
    if (categoryId == null) return [];
    final freq = <double, int>{};
    if (isExpense) {
      for (final e in expenses) {
        if (e.category?.id == categoryId) {
          freq[e.amount] = (freq[e.amount] ?? 0) + 1;
        }
      }
    } else {
      for (final i in incomes) {
        if (i.category?.id == categoryId) {
          freq[i.amount] = (freq[i.amount] ?? 0) + 1;
        }
      }
    }
    return (freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .take(7)
        .map((e) => e.key)
        .toList();
  }

  // ── Card management ───────────────────────────────────────────────────────

  Future<void> loadCards() async {
    final hid = _householdService.currentHouseholdId;
    if (hid == null) return;
    await _cardService.load(hid);
    notifyListeners();
  }

  Future<void> createCard(Map<String, dynamic> body) async {
    await _cardService.create(body);
    notifyListeners();
  }

  Future<void> updateCard(int id, Map<String, dynamic> body) async {
    await _cardService.update(id, body);
    notifyListeners();
  }

  // ── Add / edit / delete category ──────────────────────────────────────────

  void addExpenseCategory(Category cat) {
    expenseCategories = [...expenseCategories, cat];
    notifyListeners();
  }

  void addIncomeCategory(Category cat) {
    incomeCategories = [...incomeCategories, cat];
    notifyListeners();
  }

  void updateExpenseCategoryInList(Category updated) {
    expenseCategories = expenseCategories.map((c) => c.id == updated.id ? updated : c).toList();
    notifyListeners();
  }

  void updateIncomeCategoryInList(Category updated) {
    incomeCategories = incomeCategories.map((c) => c.id == updated.id ? updated : c).toList();
    notifyListeners();
  }

  Future<void> deleteExpenseCategory(int id, {bool deleteRefs = false}) async {
    try {
      await _categoryRepo.deleteExpenseCategory(id, deleteRefs: deleteRefs);
      expenseCategories = expenseCategories.where((c) => c.id != id).toList();
      if (filterCategoryId == id) filterCategoryId = null;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> deleteIncomeCategory(int id, {bool deleteRefs = false}) async {
    try {
      await _categoryRepo.deleteIncomeCategory(id, deleteRefs: deleteRefs);
      incomeCategories = incomeCategories.where((c) => c.id != id).toList();
      if (filterCategoryId == id) filterCategoryId = null;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> deleteExpense(Expense expense) async {
    try {
      await _txService.deleteExpense(expense.id);
      load();
    } catch (_) {}
  }

  Future<void> deleteIncome(Income income) async {
    try {
      await _txService.deleteIncome(income.id);
      load();
    } catch (_) {}
  }
}
