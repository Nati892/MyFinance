import 'package:intl/intl.dart';

// ─── Data classes ─────────────────────────────────────────────────────────────

class FinancialPeriod {
  final DateTime start;
  final DateTime end;
  final String label;
  const FinancialPeriod({required this.start, required this.end, required this.label});
}

class FinancialWeek {
  final int weekNumber;
  final DateTime? start;
  final DateTime? end;
  final String label;
  const FinancialWeek({required this.weekNumber, this.start, this.end, required this.label});
}

// ─── Hebrew month names ───────────────────────────────────────────────────────

const _heMonths = [
  'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני',
  'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר',
];

// index 0 = Monday (weekday 1) … index 6 = Sunday (weekday 7)
const _heDays = ['שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת', 'ראשון'];

// ─── Period / weeks ───────────────────────────────────────────────────────────

/// Returns a calendar-month period shifted by [offset] months from today.
FinancialPeriod getFinancialPeriod(int offset, {String locale = 'en'}) {
  final now = DateTime.now();
  final year  = now.year  + ((now.month - 1 + offset) ~/ 12);
  final month = ((now.month - 1 + offset) % 12) + 1;
  final start = DateTime(year, month, 1);
  final end   = DateTime(year, month + 1, 1).subtract(const Duration(seconds: 1));
  final label = locale == 'he'
      ? '${_heMonths[month - 1]} $year'
      : DateFormat('MMMM yyyy').format(start);
  return FinancialPeriod(start: start, end: end, label: label);
}

/// Splits [period] into ISO weeks (Mon–Sun), trimmed to the period boundaries.
List<FinancialWeek> getFinancialWeeks(FinancialPeriod period, {String locale = 'en'}) {
  final weeks = <FinancialWeek>[];
  var cursor = period.start;
  int weekNum = 1;

  while (cursor.isBefore(period.end) || _sameDay(cursor, period.end)) {
    // Week starts on Monday
    final weekStart = cursor;
    // End of ISO week = next Sunday (or period end, whichever comes first)
    final daysToSunday = (7 - cursor.weekday) % 7; // 0 if already Sunday
    var weekEnd = cursor.add(Duration(days: daysToSunday == 0 ? 0 : daysToSunday));
    if (weekEnd.isAfter(period.end)) weekEnd = period.end;

    final weekEndEod = DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59);
    weeks.add(FinancialWeek(
      weekNumber: weekNum,
      start: weekStart,
      end: weekEndEod,
      label: _weekRangeLabel(weekStart, weekEnd, locale: locale),
    ));

    cursor = weekEnd.add(const Duration(days: 1));
    cursor = DateTime(cursor.year, cursor.month, cursor.day); // midnight
    weekNum++;
  }
  return weeks;
}

// ─── Formatters ───────────────────────────────────────────────────────────────

String buildWeekLabel(FinancialWeek week, {String locale = 'en'}) {
  final wk = locale == 'he' ? "שב׳" : 'Week';
  if (week.start == null || week.end == null) return '$wk ${week.weekNumber}';
  return '$wk ${week.weekNumber} · ${_weekRangeLabel(week.start!, week.end!, locale: locale)}';
}

String buildDayLabel(DateTime date, {String locale = 'en'}) {
  if (locale == 'he') {
    return '${_heDays[date.weekday - 1]}, ${_heMonths[date.month - 1]} ${date.day}';
  }
  return DateFormat('EEE, MMM d').format(date);
}

String buildTimeLabel(DateTime dt) => DateFormat('HH:mm').format(dt);

String formatNIS(double amount) {
  final f = NumberFormat('#,##0.00', 'en_US');
  return '₪${f.format(amount)}';
}

String formatPaymentMethod(String method) {
  switch (method) {
    case 'card':
    case 'credit_card':   return 'Card';
    case 'debit_card':    return 'Card';
    case 'cash':          return 'Cash';
    case 'bank_transfer': return 'Bank transfer';
    default:              return method;
  }
}

double sumAmounts(List<dynamic> items) =>
    items.fold(0.0, (sum, t) => sum + (t.amount as num).toDouble());

// ─── Helpers ─────────────────────────────────────────────────────────────────

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _weekRangeLabel(DateTime s, DateTime e, {String locale = 'en'}) {
  if (locale == 'he') {
    final start = '${_heMonths[s.month - 1]} ${s.day}';
    final end = s.month == e.month ? '${e.day}' : '${_heMonths[e.month - 1]} ${e.day}';
    return '$start–$end';
  }
  final sf = DateFormat('MMM d');
  final ef = DateFormat('d');
  return '${sf.format(s)}–${ef.format(e)}';
}
