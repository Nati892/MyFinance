import 'package:flutter/material.dart';
import 'package:household/l10n/app_localizations.dart';
import 'package:household/models/expense.dart';
import 'package:household/models/income.dart';
import 'package:household/utils/financial_calendar.dart';
import 'package:household/utils/icon_helper.dart';

// ─── Unified transaction type ─────────────────────────────────────────────────

class TimelineTx {
  final int id;
  final double amount;
  final String dateTime;
  final String? description;
  final String? note;
  final String paymentMethod;
  final String? categoryName;
  final String? categoryColor;
  final String? categoryIcon;
  final String? username;
  /// 'expense' or 'income'
  final String txType;

  const TimelineTx({
    required this.id,
    required this.amount,
    required this.dateTime,
    this.description,
    this.note,
    required this.paymentMethod,
    this.categoryName,
    this.categoryColor,
    this.categoryIcon,
    this.username,
    this.txType = 'expense',
  });

  static TimelineTx fromExpense(Expense e) => TimelineTx(
    id: e.id,
    amount: e.amount,
    dateTime: e.dateTime,
    description: e.description,
    note: e.note,
    paymentMethod: e.paymentMethod,
    categoryName: e.category?.name,
    categoryColor: e.category?.color,
    categoryIcon: e.category?.icon,
    username: e.appUser?.username,
    txType: 'expense',
  );

  static TimelineTx fromIncome(Income i) => TimelineTx(
    id: i.id,
    amount: i.amount,
    dateTime: i.dateTime,
    description: i.description,
    note: i.note,
    paymentMethod: i.paymentMethod,
    categoryName: i.category?.name,
    categoryColor: i.category?.color,
    categoryIcon: i.category?.icon,
    username: i.appUser?.username,
    txType: 'income',
  );
}

// ─── Grouping helpers ─────────────────────────────────────────────────────────

class DayGroup {
  final String label;
  final String dateKey;
  final double total;
  final List<TimelineTx> transactions;
  bool collapsed;
  DayGroup({required this.label, required this.dateKey, required this.total, required this.transactions, this.collapsed = false});
}

class WeekGroup {
  final int weekNumber;
  final String label;
  final double total;
  final List<DayGroup> dayGroups;
  bool collapsed;
  WeekGroup({required this.weekNumber, required this.label, required this.total, required this.dayGroups, this.collapsed = false});
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

  const TransactionTimeline({
    super.key,
    required this.transactions,
    required this.loading,
    required this.onViewChanged,
    required this.onEdit,
    required this.onDelete,
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

  void _rebuild() {
    _period = getFinancialPeriod(_offset, locale: _locale);
    _weeks  = getFinancialWeeks(_period, locale: _locale);
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
      _rebuild(); // must be before _currentWeekNumber so _weeks is fresh
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
      case 'monthly': return _period.label;
      case 'weekly':
        final w = _weeks.firstWhere((x) => x.weekNumber == _activeWeek, orElse: () => _weeks.first);
        return buildWeekLabel(w, locale: _locale);
      case 'daily': return buildDayLabel(_activeDate, locale: _locale);
      default: return '';
    }
  }

  // ── Build grouped data ─────────────────────────────────────────────────────

  List<WeekGroup> _buildMonthlyGroups() {
    return _weeks.map((week) {
      if (week.start == null || week.end == null) {
        final wk = _locale == 'he' ? "שב׳" : 'Week';
        return WeekGroup(weekNumber: week.weekNumber, label: '$wk ${week.weekNumber}', total: 0, dayGroups: []);
      }
      final txs = widget.transactions.where((t) {
        final d = DateTime.parse(t.dateTime).toLocal();
        return !d.isBefore(week.start!) && !d.isAfter(week.end!);
      }).toList();
      final days = _groupByDay(txs);
      final total = txs.fold(0.0, (s, t) => s + t.amount);
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
      final d = DateTime.parse(t.dateTime).toLocal();
      return !d.isBefore(activeWeek.start!) && !d.isAfter(activeWeek.end!);
    }).toList();
    return _groupByDay(txs);
  }

  List<TimelineTx> _buildDailyList() {
    return [...widget.transactions]
      ..sort((a, b) => DateTime.parse(a.dateTime).compareTo(DateTime.parse(b.dateTime)));
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
      final total = e.value.fold(0.0, (s, t) => s + t.amount);
      return DayGroup(
        label: '${buildDayLabel(date, locale: _locale)} · ${formatNIS(total)}',
        dateKey: e.key,
        total: total,
        transactions: e.value..sort((a, b) => DateTime.parse(a.dateTime).compareTo(DateTime.parse(b.dateTime))),
      );
    }).toList()
      ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final grandTotal = widget.transactions.fold(0.0, (s, t) => s + t.amount);

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
                Text(_navLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(formatNIS(total),
                    style: const TextStyle(fontSize: 12, color: _textDim)),
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
        child: Text(AppLocalizations.of(context)!.timelineNoTransactions,
            style: const TextStyle(color: Color(0xFFAAAAAA))),
      );
    }
    switch (_view) {
      case 'monthly': return _buildMonthly();
      case 'weekly':  return _buildWeekly();
      case 'daily':   return _buildDaily();
      default:        return const SizedBox();
    }
  }

  Widget _buildMonthly() {
    final groups = _buildMonthlyGroups().where((g) => g.total > 0).toList();
    if (groups.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.timelineNoTransactionsMonth,
          style: const TextStyle(color: Color(0xFFAAAAAA))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: groups.length,
      itemBuilder: (_, i) => _WeekGroupTile(group: groups[i], onEdit: widget.onEdit, onDelete: widget.onDelete),
    );
  }

  Widget _buildWeekly() {
    final days = _buildWeeklyGroups();
    if (days.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.timelineNoTransactionsWeek,
          style: const TextStyle(color: Color(0xFFAAAAAA))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: days.length,
      itemBuilder: (_, i) => _DayGroupTile(group: days[i], onEdit: widget.onEdit, onDelete: widget.onDelete),
    );
  }

  Widget _buildDaily() {
    final txs = _buildDailyList();
    if (txs.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.timelineNoTransactionsDay,
          style: const TextStyle(color: Color(0xFFAAAAAA))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: txs.length,
      itemBuilder: (_, i) => _TxTile(tx: txs[i], onEdit: widget.onEdit, onDelete: widget.onDelete),
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
  const _WeekGroupTile({required this.group, required this.onEdit, required this.onDelete});
  @override State<_WeekGroupTile> createState() => _WeekGroupTileState();
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
          ...widget.group.dayGroups.map((d) =>
              _DayGroupTile(group: d, onEdit: widget.onEdit, onDelete: widget.onDelete)),
      ],
    );
  }
}

class _DayGroupTile extends StatelessWidget {
  final DayGroup group;
  final ValueChanged<TimelineTx> onEdit;
  final ValueChanged<TimelineTx> onDelete;
  const _DayGroupTile({required this.group, required this.onEdit, required this.onDelete});

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
        ...group.transactions.map((tx) => _TxTile(tx: tx, onEdit: onEdit, onDelete: onDelete)),
      ],
    );
  }
}

class _TxTile extends StatelessWidget {
  final TimelineTx tx;
  final ValueChanged<TimelineTx> onEdit;
  final ValueChanged<TimelineTx> onDelete;
  const _TxTile({required this.tx, required this.onEdit, required this.onDelete});

  String _localizedPaymentMethod(String method, AppLocalizations l10n) {
    switch (method) {
      case 'credit_card':   return l10n.paymentCard;
      case 'debit_card':    return l10n.paymentDebit;
      case 'cash':          return l10n.paymentCash;
      case 'bank_transfer': return l10n.paymentTransfer;
      default:              return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = _hexColor(tx.categoryColor ?? '#888888');
    final time = buildTimeLabel(DateTime.parse(tx.dateTime).toLocal());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(iconDataFromName(tx.categoryIcon), size: 18, color: color),
          ),
        ),
        title: Text(
          tx.description?.isNotEmpty == true ? tx.description! : (tx.categoryName ?? '—'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$time · ${_localizedPaymentMethod(tx.paymentMethod, l10n)}'
          '${tx.username != null ? ' · ${tx.username}' : ''}',
          style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatNIS(tx.amount),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFFAAAAAA)),
              onSelected: (v) => v == 'edit' ? onEdit(tx) : onDelete(tx),
              itemBuilder: (ctx) {
                final l10n = AppLocalizations.of(ctx)!;
                return [
                  PopupMenuItem(value: 'edit',   child: Text(l10n.timelineEdit)),
                  PopupMenuItem(value: 'delete', child: Text(l10n.timelineDelete, style: const TextStyle(color: Colors.red))),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }
}
