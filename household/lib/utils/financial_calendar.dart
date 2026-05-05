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

/// Returns the financial period for [offset] months from today.
/// The period runs from [startDay] of one month to ([startDay] - 1) of the next.
/// When [startDay] is 1, the period equals the calendar month.
FinancialPeriod getFinancialPeriod(
  int offset, {
  String locale = 'en',
  int startDay = 10,
}) {
  final now = DateTime.now();

  // Anchor month = month in which the period starts (on `startDay`).
  int anchorYear  = now.year;
  int anchorMonth = now.month; // 1-based
  if (now.day < startDay) {
    anchorMonth -= 1;
    if (anchorMonth < 1) {
      anchorMonth = 12;
      anchorYear -= 1;
    }
  }
  // Apply offset.
  anchorMonth += offset;
  while (anchorMonth > 12) { anchorMonth -= 12; anchorYear += 1; }
  while (anchorMonth < 1)  { anchorMonth += 12; anchorYear -= 1; }

  final start = DateTime(anchorYear, anchorMonth, startDay);
  final DateTime end;
  final String label;

  if (startDay == 1) {
    end = DateTime(anchorYear, anchorMonth + 1, 1)
        .subtract(const Duration(seconds: 1));
    label = locale == 'he'
        ? '${_heMonths[anchorMonth - 1]} $anchorYear'
        : DateFormat('MMMM yyyy').format(start);
  } else {
    // End: (startDay - 1) of the next month at 23:59:59.
    end = DateTime(anchorYear, anchorMonth + 1, startDay)
        .subtract(const Duration(seconds: 1));
    final endDate = end;
    if (locale == 'he') {
      final s = '$startDay ${_heMonths[anchorMonth - 1]}';
      final e = '${endDate.day} ${_heMonths[endDate.month - 1]} ${endDate.year}';
      label = '$s – $e';
    } else {
      final monthShort = DateFormat('MMM');
      final s = '$startDay ${monthShort.format(start)}';
      final e = '${endDate.day} ${monthShort.format(endDate)} ${endDate.year}';
      label = '$s – $e';
    }
  }

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
