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

/// Returns the (year, month) anchor of the financial period that contains [now]
/// for a given [startDay]. The anchor month is the calendar month in which the
/// period begins. When `now.day < startDay`, the anchor is the previous month.
({int year, int month}) currentFinancialAnchor({DateTime? now, int startDay = 10}) {
  final n = now ?? DateTime.now();
  int year = n.year;
  int month = n.month;
  if (n.day < startDay) {
    month -= 1;
    if (month < 1) {
      month = 12;
      year -= 1;
    }
  }
  return (year: year, month: month);
}

/// Returns the offset (in months) from the current financial anchor to the
/// given (year, month) anchor.
int financialOffsetFromCurrent(int year, int month, {int startDay = 10, DateTime? now}) {
  final cur = currentFinancialAnchor(now: now, startDay: startDay);
  return (year - cur.year) * 12 + (month - cur.month);
}

/// Builds a [FinancialPeriod] for an explicit anchor (year, month) — i.e. the
/// period running from [startDay] of that month to ([startDay] - 1) of the next.
FinancialPeriod getFinancialPeriodForAnchor(
  int anchorYear,
  int anchorMonth, {
  String locale = 'en',
  int startDay = 10,
}) {
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
    end = DateTime(anchorYear, anchorMonth + 1, startDay)
        .subtract(const Duration(seconds: 1));
    if (locale == 'he') {
      final s = '$startDay ${_heMonths[anchorMonth - 1]}';
      final e = '${end.day} ${_heMonths[end.month - 1]} ${end.year}';
      label = '$s – $e';
    } else {
      final monthShort = DateFormat('MMM');
      final s = '$startDay ${monthShort.format(start)}';
      final e = '${end.day} ${monthShort.format(end)} ${end.year}';
      label = '$s – $e';
    }
  }

  return FinancialPeriod(start: start, end: end, label: label);
}

/// Returns the financial period for [offset] months from today.
/// The period runs from [startDay] of one month to ([startDay] - 1) of the next.
/// When [startDay] is 1, the period equals the calendar month.
FinancialPeriod getFinancialPeriod(
  int offset, {
  String locale = 'en',
  int startDay = 10,
}) {
  final cur = currentFinancialAnchor(startDay: startDay);
  int anchorMonth = cur.month + offset;
  int anchorYear = cur.year;
  while (anchorMonth > 12) { anchorMonth -= 12; anchorYear += 1; }
  while (anchorMonth < 1)  { anchorMonth += 12; anchorYear -= 1; }
  return getFinancialPeriodForAnchor(
    anchorYear,
    anchorMonth,
    locale: locale,
    startDay: startDay,
  );
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
