import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household/core/network/dio_provider.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/category.dart';
import 'package:household/models/expense.dart';
import 'package:household/models/income.dart';
import 'package:household/models/transaction_attachment.dart';
import 'package:household/services/auth_service.dart';
import 'package:household/utils/financial_calendar.dart';
import 'package:household/utils/icon_helper.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

Color _hexColor(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return const Color(0xFF888888);
  }
}

String _paymentMethodText(TimelineTx tx, AppLocalizations l10n) {
  if (tx.paymentMethod == 'card' ||
      tx.paymentMethod == 'credit_card' ||
      tx.paymentMethod == 'debit_card') {
    return tx.cardLabel ?? l10n.paymentCard;
  }
  switch (tx.paymentMethod) {
    case 'cash':
      return l10n.paymentCash;
    case 'bank_transfer':
      return l10n.paymentTransfer;
    default:
      return tx.paymentMethod;
  }
}

String _monthAbbr(int month, bool isHe) {
  const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const he = ['ינו', 'פבר', 'מרץ', 'אפר', 'מאי', 'יונ', 'יול', 'אוג', 'ספט', 'אוק', 'נוב', 'דצמ'];
  return (isHe ? he : en)[(month - 1).clamp(0, 11)];
}

String _formatFullDate(DateTime dt, bool isHe) {
  const enMonths = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  const heMonths = [
    'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני',
    'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר'
  ];
  final m = (isHe ? heMonths : enMonths)[dt.month - 1];
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$m ${dt.day}, ${dt.year}  $h:$min';
}

// ─── Unified transaction type ─────────────────────────────────────────────────

class TimelineTx {
  final int id;
  final double amount;
  final String dateTime;
  final String? description;
  final String? note;
  final String paymentMethod;
  final String? cardLabel;
  final String? categoryName;
  final String? categoryNameHe;
  final String? categoryColor;
  final String? categoryIcon;
  final String? parentCategoryName;
  final String? parentCategoryNameHe;
  final String? parentCategoryColor;
  final String? parentCategoryIcon;
  final String? username;
  final String txType;
  final int? installmentCurrent;
  final int? installmentTotal;
  final bool isRecurring;
  final int? recurringExpenseId;
  final int attachmentCount;
  final List<TransactionAttachment> attachments;

  const TimelineTx({
    required this.id,
    required this.amount,
    required this.dateTime,
    this.description,
    this.note,
    required this.paymentMethod,
    this.cardLabel,
    this.categoryName,
    this.categoryNameHe,
    this.categoryColor,
    this.categoryIcon,
    this.parentCategoryName,
    this.parentCategoryNameHe,
    this.parentCategoryColor,
    this.parentCategoryIcon,
    this.username,
    this.txType = 'expense',
    this.installmentCurrent,
    this.installmentTotal,
    this.isRecurring = false,
    this.recurringExpenseId,
    this.attachmentCount = 0,
    this.attachments = const [],
  });

  static TimelineTx fromExpense(Expense e, {Map<int, Category>? parentLookup}) {
    final catId = e.category?.id;
    final parent = (catId != null && parentLookup != null) ? parentLookup[catId] : null;
    return TimelineTx(
      id: e.id,
      amount: e.amount,
      dateTime: e.dateTime,
      description: e.description,
      note: e.note,
      paymentMethod: e.paymentMethod,
      cardLabel: e.card?.displayLabel,
      categoryName: e.category?.name,
      categoryNameHe: e.category?.nameHe,
      categoryColor: e.category?.color,
      categoryIcon: e.category?.icon,
      parentCategoryName: parent?.name,
      parentCategoryNameHe: parent?.nameHe,
      parentCategoryColor: parent?.color,
      parentCategoryIcon: parent?.icon,
      username: e.appUser?.name,
      txType: 'expense',
      installmentCurrent: e.installmentCurrent,
      installmentTotal: e.installmentTotal,
      isRecurring: e.isRecurring,
      recurringExpenseId: e.recurringExpenseId,
      attachmentCount: e.attachmentCount,
      attachments: e.attachments,
    );
  }

  static TimelineTx fromIncome(Income i, {Map<int, Category>? parentLookup}) {
    final catId = i.category?.id;
    final parent = (catId != null && parentLookup != null) ? parentLookup[catId] : null;
    return TimelineTx(
      id: i.id,
      amount: i.amount,
      dateTime: i.dateTime,
      description: i.description,
      note: i.note,
      paymentMethod: i.paymentMethod,
      cardLabel: i.card?.displayLabel,
      categoryName: i.category?.name,
      categoryNameHe: i.category?.nameHe,
      categoryColor: i.category?.color,
      categoryIcon: i.category?.icon,
      parentCategoryName: parent?.name,
      parentCategoryNameHe: parent?.nameHe,
      parentCategoryColor: parent?.color,
      parentCategoryIcon: parent?.icon,
      username: i.appUser?.name,
      txType: 'income',
      attachmentCount: i.attachmentCount,
      attachments: i.attachments,
    );
  }
}

// ─── Grouping helpers ─────────────────────────────────────────────────────────

class DayGroup {
  final String label;
  final String dateKey;
  final double total;
  final List<TimelineTx> transactions;
  bool collapsed;
  DayGroup({
    required this.label,
    required this.dateKey,
    required this.total,
    required this.transactions,
    this.collapsed = false,
  });
}

class WeekGroup {
  final int weekNumber;
  final String label;
  final double total;
  final List<DayGroup> dayGroups;
  bool collapsed;
  WeekGroup({
    required this.weekNumber,
    required this.label,
    required this.total,
    required this.dayGroups,
    this.collapsed = false,
  });
}

// ─── Timeline widget ──────────────────────────────────────────────────────────

typedef ViewChangedCallback = void Function({
  required String view,
  required int offset,
  int? week,
  String? dayDate,
});

class TransactionTimeline extends StatefulWidget {
  final List<TimelineTx> transactions;
  final bool loading;
  final ViewChangedCallback onViewChanged;
  final ValueChanged<TimelineTx> onEdit;
  final ValueChanged<TimelineTx> onDelete;
  /// Optional per-category monthly history for the bar chart in the detail sheet.
  /// Key: category name, value: list of monthly totals oldest→newest.
  final Map<String, List<double>>? categoryMonthHistory;
  /// First day of the household's financial month (1..28). Default 10.
  final int financialMonthStartDay;

  const TransactionTimeline({
    super.key,
    required this.transactions,
    required this.loading,
    required this.onViewChanged,
    required this.onEdit,
    required this.onDelete,
    this.categoryMonthHistory,
    this.financialMonthStartDay = 10,
  });

  @override
  State<TransactionTimeline> createState() => _TransactionTimelineState();
}

class _TransactionTimelineState extends State<TransactionTimeline> {
  String _view = 'monthly';
  int _offset = 0;
  int _activeWeek = 1;
  DateTime _activeDate = DateTime.now();
  String _locale = 'en';

  static const _purple = Color(0xFF667EEA);
  static const _textDim = Color(0xFF888888);

  late FinancialPeriod _period;
  late List<FinancialWeek> _weeks;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newLocale = Localizations.localeOf(context).languageCode;
    if (newLocale != _locale) {
      setState(() {
        _locale = newLocale;
        _rebuild();
      });
    }
  }

  @override
  void didUpdateWidget(covariant TransactionTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.financialMonthStartDay != widget.financialMonthStartDay) {
      setState(_rebuild);
    }
  }

  void _rebuild() {
    _period = getFinancialPeriod(
      _offset,
      locale: _locale,
      startDay: widget.financialMonthStartDay,
    );
    _weeks = getFinancialWeeks(_period, locale: _locale);
  }

  void _emit() {
    widget.onViewChanged(
      view: _view,
      offset: _offset,
      week: _view == 'weekly' ? _activeWeek : null,
      dayDate: _view == 'daily' ? _activeDate.toUtc().toIso8601String() : null,
    );
  }

  void _selectView(String v) {
    setState(() {
      if (v == 'daily') _activeDate = DateTime.now();
      _view = v;
      _rebuild();
      if (v == 'weekly') _activeWeek = _currentWeekNumber();
    });
    _emit();
  }

  int _currentWeekNumber() {
    final today = DateTime.now();
    for (final w in _weeks) {
      if (w.start != null && w.end != null) {
        if (!today.isBefore(w.start!) && !today.isAfter(w.end!)) {
          return w.weekNumber;
        }
      }
    }
    return _weeks.isNotEmpty ? _weeks.last.weekNumber : 1;
  }

  void _prev() {
    setState(() {
      if (_view == 'monthly') {
        _offset--;
        _rebuild();
      } else if (_view == 'weekly') {
        _stepWeek(-1);
      } else {
        _activeDate = _activeDate.subtract(const Duration(days: 1));
      }
    });
    _emit();
  }

  void _next() {
    setState(() {
      if (_view == 'monthly') {
        _offset++;
        _rebuild();
      } else if (_view == 'weekly') {
        _stepWeek(1);
      } else {
        _activeDate = _activeDate.add(const Duration(days: 1));
      }
    });
    _emit();
  }

  void _stepWeek(int delta) {
    final valid = _weeks.where((w) => w.start != null && w.end != null).toList();
    final maxNum = valid.isEmpty ? 1 : valid.last.weekNumber;
    final next = _activeWeek + delta;
    if (next < 1) {
      _offset--;
      _rebuild();
      final newValid = _weeks.where((w) => w.start != null && w.end != null).toList();
      _activeWeek = newValid.isEmpty ? 1 : newValid.last.weekNumber;
    } else if (next > maxNum) {
      _offset++;
      _rebuild();
      _activeWeek = 1;
    } else {
      _activeWeek = next;
    }
  }

  String get _navLabel {
    switch (_view) {
      case 'monthly':
        return _period.label;
      case 'weekly':
        final w = _weeks.firstWhere((x) => x.weekNumber == _activeWeek, orElse: () => _weeks.first);
        return buildWeekLabel(w, locale: _locale);
      case 'daily':
        return buildDayLabel(_activeDate, locale: _locale);
      default:
        return '';
    }
  }

  // ── Category totals for current period ────────────────────────────────────

  Map<String, double> _computeCategoryTotals() {
    final map = <String, double>{};
    for (final tx in widget.transactions) {
      if (tx.txType != 'expense') continue;
      if (tx.categoryName != null) {
        map[tx.categoryName!] = (map[tx.categoryName!] ?? 0) + tx.amount;
      }
      if (tx.parentCategoryName != null) {
        map[tx.parentCategoryName!] = (map[tx.parentCategoryName!] ?? 0) + tx.amount;
      }
    }
    return map;
  }

  // ── Build grouped data ─────────────────────────────────────────────────────

  List<WeekGroup> _buildMonthlyGroups() {
    return _weeks.reversed.map((week) {
      if (week.start == null || week.end == null) {
        final wk = _locale == 'he' ? "שב׳" : 'Week';
        return WeekGroup(weekNumber: week.weekNumber, label: '$wk ${week.weekNumber}', total: 0, dayGroups: []);
      }
      final txs = widget.transactions.where((t) {
        if (t.isRecurring) return false;
        final d = DateTime.parse(t.dateTime).toLocal();
        return !d.isBefore(week.start!) && !d.isAfter(week.end!);
      }).toList();
      final days = _groupByDay(txs);
      final total = txs.fold(0.0, (s, t) => s + (t.txType == 'expense' ? -t.amount : t.amount));
      final wk = _locale == 'he' ? "שב׳" : 'Week';
      return WeekGroup(
        weekNumber: week.weekNumber,
        label: '$wk ${week.weekNumber} · ${week.label} · ${formatNIS(total)}',
        total: total,
        dayGroups: days,
      );
    }).toList();
  }

  List<DayGroup> _buildWeeklyGroups() {
    var activeWeek = _weeks.firstWhere(
      (w) => w.weekNumber == _activeWeek && w.start != null,
      orElse: () => _weeks.firstWhere((w) => w.start != null, orElse: () => _weeks.first),
    );
    if (activeWeek.start == null) return [];
    final txs = widget.transactions.where((t) {
      if (t.isRecurring) return false;
      final d = DateTime.parse(t.dateTime).toLocal();
      return !d.isBefore(activeWeek.start!) && !d.isAfter(activeWeek.end!);
    }).toList();
    return _groupByDay(txs);
  }

  List<TimelineTx> _buildDailyList() {
    return widget.transactions.where((t) => !t.isRecurring).toList()
      ..sort((a, b) => DateTime.parse(b.dateTime).compareTo(DateTime.parse(a.dateTime)));
  }

  List<DayGroup> _groupByDay(List<TimelineTx> txs) {
    final map = <String, List<TimelineTx>>{};
    for (final tx in txs) {
      final d = DateTime.parse(tx.dateTime).toLocal();
      final key = '${d.year}-${d.month}-${d.day}';
      (map[key] ??= []).add(tx);
    }
    return map.entries.map((e) {
      final parts = e.key.split('-').map(int.parse).toList();
      final date = DateTime(parts[0], parts[1], parts[2]);
      final total = e.value.fold(0.0, (s, t) => s + (t.txType == 'expense' ? -t.amount : t.amount));
      return DayGroup(
        label: '${buildDayLabel(date, locale: _locale)} · ${formatNIS(total)}',
        dateKey: e.key,
        total: total,
        transactions: e.value..sort((a, b) => DateTime.parse(b.dateTime).compareTo(DateTime.parse(a.dateTime))),
      );
    }).toList()
      ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final grandTotal = widget.transactions.fold(0.0, (s, t) => s + (t.txType == 'expense' ? -t.amount : t.amount));

    return Column(
      children: [
        _buildViewSelector(),
        _buildNavRow(grandTotal),
        Expanded(child: widget.loading ? _buildSkeleton() : _buildContent()),
      ],
    );
  }

  Widget _buildViewSelector() {
    final l10n = AppLocalizations.of(context)!;
    final views = [
      ('monthly', l10n.timelineMonthly),
      ('weekly', l10n.timelineWeekly),
      ('daily', l10n.timelineDaily),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: views.map((v) {
          final active = _view == v.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => _selectView(v.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: active ? _purple : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  v.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : _textDim,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNavRow(double total) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _prev,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: _textDim,
          ),
          Expanded(
            child: Column(
              children: [
                Text(_navLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  formatNIS(total),
                  style: TextStyle(
                    fontSize: 12,
                    color: total >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _next,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: _textDim,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (widget.transactions.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.timelineNoTransactions,
          style: const TextStyle(color: Color(0xFFAAAAAA)),
        ),
      );
    }
    final recurring = widget.transactions.where((t) => t.isRecurring).toList();
    final catTotals = _computeCategoryTotals();
    final history = widget.categoryMonthHistory;

    Widget view;
    switch (_view) {
      case 'monthly':
        view = _buildMonthly(catTotals, history);
        break;
      case 'weekly':
        view = _buildWeekly(catTotals, history);
        break;
      case 'daily':
        view = _buildDaily(catTotals, history);
        break;
      default:
        view = const SizedBox();
    }
    return Column(
      children: [
        if (recurring.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: _RecurringGroupTile(
              transactions: recurring,
              onEdit: widget.onEdit,
              onDelete: widget.onDelete,
              categoryCurrentTotals: catTotals,
              categoryMonthHistory: history,
            ),
          ),
        Expanded(child: view),
      ],
    );
  }

  Widget _buildMonthly(Map<String, double> catTotals, Map<String, List<double>>? history) {
    final groups = _buildMonthlyGroups().where((g) => g.dayGroups.isNotEmpty).toList();
    if (groups.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.timelineNoTransactionsMonth,
          style: const TextStyle(color: Color(0xFFAAAAAA)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: groups.length,
      itemBuilder: (_, i) => _WeekGroupTile(
        group: groups[i],
        onEdit: widget.onEdit,
        onDelete: widget.onDelete,
        categoryCurrentTotals: catTotals,
        categoryMonthHistory: history,
      ),
    );
  }

  Widget _buildWeekly(Map<String, double> catTotals, Map<String, List<double>>? history) {
    final days = _buildWeeklyGroups();
    if (days.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.timelineNoTransactionsWeek,
          style: const TextStyle(color: Color(0xFFAAAAAA)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: days.length,
      itemBuilder: (_, i) => _DayGroupTile(
        group: days[i],
        onEdit: widget.onEdit,
        onDelete: widget.onDelete,
        categoryCurrentTotals: catTotals,
        categoryMonthHistory: history,
      ),
    );
  }

  Widget _buildDaily(Map<String, double> catTotals, Map<String, List<double>>? history) {
    final txs = _buildDailyList();
    if (txs.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.timelineNoTransactionsDay,
          style: const TextStyle(color: Color(0xFFAAAAAA)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: txs.length,
      itemBuilder: (_, i) => _TxTile(
        tx: txs[i],
        onEdit: widget.onEdit,
        onDelete: widget.onDelete,
        categoryCurrentTotals: catTotals,
        categoryMonthHistory: history,
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _WeekGroupTile extends StatefulWidget {
  final WeekGroup group;
  final ValueChanged<TimelineTx> onEdit;
  final ValueChanged<TimelineTx> onDelete;
  final Map<String, double> categoryCurrentTotals;
  final Map<String, List<double>>? categoryMonthHistory;

  const _WeekGroupTile({
    required this.group,
    required this.onEdit,
    required this.onDelete,
    required this.categoryCurrentTotals,
    this.categoryMonthHistory,
  });

  @override
  State<_WeekGroupTile> createState() => _WeekGroupTileState();
}

class _WeekGroupTileState extends State<_WeekGroupTile> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _collapsed = !_collapsed),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(children: [
              Icon(_collapsed ? Icons.expand_more : Icons.expand_less, size: 16, color: const Color(0xFF888888)),
              const SizedBox(width: 4),
              Text(widget.group.label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF555555))),
            ]),
          ),
        ),
        if (!_collapsed)
          ...widget.group.dayGroups.map((d) => _DayGroupTile(
                group: d,
                onEdit: widget.onEdit,
                onDelete: widget.onDelete,
                categoryCurrentTotals: widget.categoryCurrentTotals,
                categoryMonthHistory: widget.categoryMonthHistory,
              )),
      ],
    );
  }
}

class _DayGroupTile extends StatelessWidget {
  final DayGroup group;
  final ValueChanged<TimelineTx> onEdit;
  final ValueChanged<TimelineTx> onDelete;
  final Map<String, double> categoryCurrentTotals;
  final Map<String, List<double>>? categoryMonthHistory;

  const _DayGroupTile({
    required this.group,
    required this.onEdit,
    required this.onDelete,
    required this.categoryCurrentTotals,
    this.categoryMonthHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Text(group.label,
              style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w500)),
        ),
        ...group.transactions.map((tx) => _TxTile(
              tx: tx,
              onEdit: onEdit,
              onDelete: onDelete,
              categoryCurrentTotals: categoryCurrentTotals,
              categoryMonthHistory: categoryMonthHistory,
            )),
      ],
    );
  }
}

class _RecurringGroupTile extends StatefulWidget {
  final List<TimelineTx> transactions;
  final ValueChanged<TimelineTx> onEdit;
  final ValueChanged<TimelineTx> onDelete;
  final Map<String, double> categoryCurrentTotals;
  final Map<String, List<double>>? categoryMonthHistory;

  const _RecurringGroupTile({
    required this.transactions,
    required this.onEdit,
    required this.onDelete,
    required this.categoryCurrentTotals,
    this.categoryMonthHistory,
  });

  @override
  State<_RecurringGroupTile> createState() => _RecurringGroupTileState();
}

class _RecurringGroupTileState extends State<_RecurringGroupTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final total = widget.transactions.fold(0.0, (s, t) => s + t.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.25), width: 0.8),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.repeat, size: 18, color: Color(0xFF9C27B0)),
                ),
              ),
              title: Text(
                l10n.recurringGroupLabel,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF222222)),
              ),
              subtitle: Text(
                '${widget.transactions.length} items',
                style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatNIS(total),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFFC62828)),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: const Color(0xFF9C27B0),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          ...widget.transactions.map((tx) => _TxTile(
                tx: tx,
                onEdit: widget.onEdit,
                onDelete: widget.onDelete,
                categoryCurrentTotals: widget.categoryCurrentTotals,
                categoryMonthHistory: widget.categoryMonthHistory,
              )),
      ],
    );
  }
}

// ─── Transaction tile ─────────────────────────────────────────────────────────

class _TxTile extends StatelessWidget {
  final TimelineTx tx;
  final ValueChanged<TimelineTx> onEdit;
  final ValueChanged<TimelineTx> onDelete;
  final Map<String, double> categoryCurrentTotals;
  final Map<String, List<double>>? categoryMonthHistory;

  const _TxTile({
    required this.tx,
    required this.onEdit,
    required this.onDelete,
    required this.categoryCurrentTotals,
    this.categoryMonthHistory,
  });

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _TxDetailSheet(
        tx: tx,
        onEdit: () {
          Navigator.pop(ctx);
          onEdit(tx);
        },
        onDelete: () {
          Navigator.pop(ctx);
          onDelete(tx);
        },
        categoryCurrentTotals: categoryCurrentTotals,
        categoryMonthHistory: categoryMonthHistory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final color = _hexColor(tx.categoryColor ?? '#888888');
    final time = buildTimeLabel(DateTime.parse(tx.dateTime).toLocal());

    final displayCategoryName = isHe
        ? (tx.categoryNameHe?.isNotEmpty == true ? tx.categoryNameHe! : tx.categoryName)
        : tx.categoryName;
    final displayParentName = isHe
        ? (tx.parentCategoryNameHe?.isNotEmpty == true ? tx.parentCategoryNameHe! : tx.parentCategoryName)
        : tx.parentCategoryName;

    final amountColor = tx.txType == 'income'
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC62828);

    return GestureDetector(
      onTap: () => _openSheet(context),
      onLongPress: () => _openSheet(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          leading: SizedBox(
            width: 34,
            height: 34,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Icon(iconDataFromName(tx.categoryIcon), size: 16, color: color),
                  ),
                ),
                if (tx.parentCategoryName != null)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _hexColor(tx.parentCategoryColor ?? '#888888'),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Icon(
                          iconDataFromName(tx.parentCategoryIcon),
                          size: 7,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          title: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                if (displayParentName != null) ...[
                  TextSpan(
                    text: '$displayParentName › ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _hexColor(tx.parentCategoryColor ?? tx.categoryColor ?? '#888888')
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
                TextSpan(
                  text: tx.description?.isNotEmpty == true
                      ? tx.description!
                      : (displayCategoryName ?? '—'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF222222),
                  ),
                ),
              ],
            ),
          ),
          subtitle: Text(
            '$time${tx.username != null ? " · ${tx.username}" : ""}',
            style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatNIS(tx.amount),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: amountColor),
              ),
              if (tx.installmentTotal != null && tx.installmentTotal! > 1)
                Text(
                  '${tx.installmentCurrent ?? 1}/${tx.installmentTotal}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: amountColor.withValues(alpha: 0.7),
                  ),
                ),
              if (tx.attachmentCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.attach_file, size: 11, color: Color(0xFF888888)),
                      const SizedBox(width: 1),
                      Text(
                        '${tx.attachmentCount}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF888888)),
                      ),
                    ],
                  ),
                ),
              if (tx.isRecurring)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.4), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.repeat, size: 8, color: Color(0xFF9C27B0)),
                      const SizedBox(width: 2),
                      Text(
                        AppLocalizations.of(context)!.recurringBadge,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9C27B0),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Auth-aware image widget ──────────────────────────────────────────────────

class AuthImage extends ConsumerWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? loadingBg;
  final Widget? errorWidget;

  const AuthImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.loadingBg,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = ref.watch(authServiceProvider).accessToken;
    final headers = token != null ? {'Authorization': 'Bearer $token'} : <String, String>{};
    return Image.network(
      url,
      headers: headers,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: loadingBg ?? const Color(0xFFEEEEEE),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) =>
          errorWidget ??
          Container(
            width: width,
            height: height,
            color: const Color(0xFFEEEEEE),
            child: const Icon(Icons.broken_image, size: 24, color: Color(0xFFAAAAAA)),
          ),
    );
  }
}

// ─── Auth-aware file attachment tile ─────────────────────────────────────────

class _FileAttachmentTile extends ConsumerStatefulWidget {
  final TransactionAttachment att;
  const _FileAttachmentTile({required this.att});

  @override
  ConsumerState<_FileAttachmentTile> createState() => _FileAttachmentTileState();
}

class _FileAttachmentTileState extends ConsumerState<_FileAttachmentTile> {
  bool _downloading = false;

  Future<void> _open() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/${widget.att.filename}';
      final dio = ref.read(dioProvider);
      await dio.download(
        '/app/attachments/${widget.att.id}/file',
        filePath,
        options: Options(responseType: ResponseType.bytes),
      );
      await OpenFile.open(filePath);
    } catch (_) {
      // silent — broken icon serves as feedback
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDDDDDD)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _downloading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF667EEA)))
                : const Icon(Icons.insert_drive_file, size: 16, color: Color(0xFF667EEA)),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                widget.att.filename,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF333333)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Full-screen image viewer ─────────────────────────────────────────────────

void _openImageViewer(
  BuildContext context,
  TransactionAttachment att,
  List<TransactionAttachment> allImages,
) {
  final initialIndex = allImages.indexWhere((a) => a.id == att.id);
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => _ImageViewerScreen(
      images: allImages,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
    ),
  ));
}

class _ImageViewerScreen extends StatefulWidget {
  final List<TransactionAttachment> images;
  final int initialIndex;

  const _ImageViewerScreen({required this.images, required this.initialIndex});

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
  late final PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final att = widget.images[_current];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(att.filename, style: const TextStyle(fontSize: 14)),
      ),
      body: Column(
        children: [
          // Main swipeable image area
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (context, i) {
                final img = widget.images[i];
                return InteractiveViewer(
                  child: Center(
                    child: AuthImage(
                      url: '$kBaseUrl/app/attachments/${img.id}/file',
                      fit: BoxFit.contain,
                      loadingBg: Colors.black,
                      errorWidget: const Icon(Icons.broken_image, color: Colors.white, size: 48),
                    ),
                  ),
                );
              },
            ),
          ),
          // Thumbnail strip
          if (widget.images.length > 1)
            Container(
              color: Colors.black,
              height: 72,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: widget.images.length,
                itemBuilder: (context, i) {
                  final img = widget.images[i];
                  final isSelected = i == _current;
                  return GestureDetector(
                    onTap: () => _pageCtrl.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: AuthImage(
                          url: '$kBaseUrl/app/attachments/${img.id}/thumb',
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Transaction detail bottom sheet ─────────────────────────────────────────

class _TxDetailSheet extends StatelessWidget {
  final TimelineTx tx;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Map<String, double> categoryCurrentTotals;
  final Map<String, List<double>>? categoryMonthHistory;

  const _TxDetailSheet({
    required this.tx,
    required this.onEdit,
    required this.onDelete,
    required this.categoryCurrentTotals,
    this.categoryMonthHistory,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final color = _hexColor(tx.categoryColor ?? '#888888');
    final parentColor = _hexColor(tx.parentCategoryColor ?? '#888888');
    final amtColor = tx.txType == 'income' ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    final displayCategoryName = isHe
        ? (tx.categoryNameHe?.isNotEmpty == true ? tx.categoryNameHe! : tx.categoryName)
        : tx.categoryName;
    final displayParentName = isHe
        ? (tx.parentCategoryNameHe?.isNotEmpty == true ? tx.parentCategoryNameHe! : tx.parentCategoryName)
        : tx.parentCategoryName;

    final parsedDate = DateTime.parse(tx.dateTime).toLocal();

    final catTotal = categoryCurrentTotals[tx.categoryName];
    final parentTotal =
        tx.parentCategoryName != null ? categoryCurrentTotals[tx.parentCategoryName] : null;
    final catHistory = categoryMonthHistory?[tx.categoryName ?? ''];
    final parentHistoryKey = tx.parentCategoryName;
    final parentHistory = (parentHistoryKey != null) ? (categoryMonthHistory?[parentHistoryKey]) : null;

    final periodLabel = isHe ? 'סה״כ בתקופה' : 'total this period';

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Header ──────────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: Icon(iconDataFromName(tx.categoryIcon), size: 22, color: color),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (displayParentName != null)
                          Text(
                            displayParentName,
                            style: TextStyle(
                              fontSize: 11,
                              color: parentColor.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        Text(
                          tx.description?.isNotEmpty == true
                              ? tx.description!
                              : (displayCategoryName ?? '—'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatNIS(tx.amount),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: amtColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 12),

              // ── Details ──────────────────────────────────────────────────────
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                text: _formatFullDate(parsedDate, isHe),
              ),
              _DetailRow(
                icon: Icons.payment_outlined,
                text: _paymentMethodText(tx, l10n),
              ),
              if (tx.note?.isNotEmpty == true)
                _DetailRow(icon: Icons.notes_outlined, text: tx.note!),
              if (tx.installmentTotal != null && tx.installmentTotal! > 1)
                _DetailRow(
                  icon: Icons.credit_score_outlined,
                  text: isHe
                      ? '${tx.installmentCurrent ?? 1} / ${tx.installmentTotal} תשלומים'
                      : '${tx.installmentCurrent ?? 1} / ${tx.installmentTotal} installments',
                ),
              if (tx.username != null)
                _DetailRow(icon: Icons.person_outline, text: tx.username!),
              if (tx.isRecurring)
                _DetailRow(
                  icon: Icons.repeat,
                  text: isHe ? 'הוצאה קבועה' : 'Recurring expense',
                  iconColor: const Color(0xFF9C27B0),
                  textColor: const Color(0xFF9C27B0),
                ),

              // ── Category totals ──────────────────────────────────────────────
              if (catTotal != null || parentTotal != null) ...[
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 12),

                if (catTotal != null)
                  _CategoryTotalRow(
                    icon: iconDataFromName(tx.categoryIcon),
                    name: displayCategoryName ?? '',
                    total: catTotal,
                    color: color,
                    periodLabel: periodLabel,
                  ),

                if (parentTotal != null && displayParentName != null) ...[
                  const SizedBox(height: 6),
                  _CategoryTotalRow(
                    icon: iconDataFromName(tx.parentCategoryIcon),
                    name: displayParentName,
                    total: parentTotal,
                    color: parentColor,
                    periodLabel: periodLabel,
                  ),
                ],

                // ── Bar charts ────────────────────────────────────────────────
                if (catHistory != null && catHistory.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _MiniBarChart(
                    values: catHistory,
                    color: color,
                    label: displayCategoryName ?? '',
                    isHe: isHe,
                  ),
                ] else if (parentHistory != null && parentHistory.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _MiniBarChart(
                    values: parentHistory,
                    color: parentColor,
                    label: displayParentName ?? '',
                    isHe: isHe,
                  ),
                ],
              ],

              // ── Attachments section ───────────────────────────────────────
              if (tx.attachments.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 12),
                Text(
                  l10n.attachments,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF555555),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tx.attachments.map((att) {
                    if (att.isImage) {
                      final imageAttachments = tx.attachments.where((a) => a.isImage).toList();
                      return GestureDetector(
                        onTap: () => _openImageViewer(context, att, imageAttachments),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: AuthImage(
                            url: '$kBaseUrl/app/attachments/${att.id}/thumb',
                            width: 60,
                            height: 60,
                          ),
                        ),
                      );
                    } else {
                      return _FileAttachmentTile(att: att);
                    }
                  }).toList(),
                ),
              ],

              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 12),

              // ── Actions ──────────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.edit_outlined,
                      label: l10n.timelineEdit,
                      color: const Color(0xFF667EEA),
                      onTap: onEdit,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.delete_outline,
                      label: l10n.timelineDelete,
                      color: const Color(0xFFE53935),
                      onTap: onDelete,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;
  final Color? textColor;

  const _DetailRow({
    required this.icon,
    required this.text,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: iconColor ?? const Color(0xFF999999)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: textColor ?? const Color(0xFF444444),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTotalRow extends StatelessWidget {
  final IconData? icon;
  final String name;
  final double total;
  final Color color;
  final String periodLabel;

  const _CategoryTotalRow({
    required this.icon,
    required this.name,
    required this.total,
    required this.color,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Center(
            child: Icon(icon, size: 12, color: color),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$name — $periodLabel',
            style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
          ),
        ),
        Text(
          formatNIS(total),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final String label;
  final bool isHe;

  const _MiniBarChart({
    required this.values,
    required this.color,
    required this.label,
    required this.isHe,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final maxVal = values.fold(0.0, (m, v) => v > m ? v : m);
    if (maxVal == 0) return const SizedBox.shrink();

    final now = DateTime.now();
    final labels = List.generate(values.length, (i) {
      final month = DateTime(now.year, now.month - (values.length - 1 - i));
      return _monthAbbr(((month.month - 1) % 12) + 1, isHe);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isHe ? 'חודשים אחרונים — $label' : 'Last months — $label',
          style: const TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 70,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(values.length, (i) {
              final frac = values[i] / maxVal;
              final isLast = i == values.length - 1;
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: frac.clamp(0.03, 1.0),
                          child: Container(
                            width: 16,
                            decoration: BoxDecoration(
                              color: isLast ? color : color.withValues(alpha: 0.35),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 9,
                        color: isLast ? color : const Color(0xFFAAAAAA),
                        fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
