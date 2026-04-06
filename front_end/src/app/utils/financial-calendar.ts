/**
 * Financial Calendar Utility (TypeScript port of /utils/financialCalendar.js)
 * Financial period: 10th of month M → 9th of month M+1
 * Week 1 : period.start → coming Saturday at 23:59:59
 * Weeks 2-4: full Sunday–Saturday
 * Week 5 : last Sunday → period.end (may be partial)
 */

export interface FinancialPeriod {
  start: Date;
  end: Date;
  label: string;
}

export interface FinancialWeek {
  weekNumber: number; // 1-5
  start: Date | null;
  end: Date | null;
  label: string;
}

export interface HourlySlot {
  hour: number;
  start: Date;
  end: Date;
  label: string;
}

export interface DailySlot {
  date: Date;
  label: string;
}

export const MONTHS_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                             'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
export const DAYS_SHORT   = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

export function formatDayMonth(date: Date): string {
  return `${date.getDate()} ${MONTHS_SHORT[date.getMonth()]}`;
}

export function formatDayMonthYear(date: Date): string {
  return `${formatDayMonth(date)} ${date.getFullYear()}`;
}

export function formatDayName(date: Date): string {
  return DAYS_SHORT[date.getDay()];
}

function buildPeriodLabel(start: Date, end: Date): string {
  return `${formatDayMonth(start)} – ${formatDayMonthYear(end)}`;
}

/**
 * Get the current financial period (0 offset).
 */
export function getCurrentFinancialPeriod(): FinancialPeriod {
  return getFinancialPeriod(0);
}

/**
 * Get a financial period by offset from the current one.
 * offset 0 = current, -1 = previous, +1 = next
 */
export function getFinancialPeriod(offset: number = 0): FinancialPeriod {
  const today = new Date();
  const day = today.getDate();

  let anchorYear  = today.getFullYear();
  let anchorMonth = today.getMonth(); // 0-based

  if (day < 10) {
    // Current period started last month
    anchorMonth -= 1;
    if (anchorMonth < 0) {
      anchorMonth = 11;
      anchorYear -= 1;
    }
  }

  // Apply offset (one calendar month per step)
  anchorMonth += offset;
  while (anchorMonth > 11) { anchorMonth -= 12; anchorYear += 1; }
  while (anchorMonth < 0)  { anchorMonth += 12; anchorYear -= 1; }

  const start = new Date(anchorYear, anchorMonth, 10, 0, 0, 0, 0);

  let endMonth = anchorMonth + 1;
  let endYear  = anchorYear;
  if (endMonth > 11) { endMonth = 0; endYear += 1; }
  const end = new Date(endYear, endMonth, 9, 23, 59, 59, 999);

  return { start, end, label: buildPeriodLabel(start, end) };
}

/**
 * Get the 5 financial weeks within a period.
 * Always returns exactly 5 elements; pads empty slots with null start/end.
 */
export function getFinancialWeeks(period: FinancialPeriod): FinancialWeek[] {
  const weeks: FinancialWeek[] = [];

  // Week 1: period.start → coming Saturday
  const w1Start   = new Date(period.start);
  const dayOfWeek = w1Start.getDay(); // 0=Sun … 6=Sat
  const daysUntilSat = dayOfWeek === 6 ? 0 : 6 - dayOfWeek;
  const w1EndDate = new Date(w1Start);
  w1EndDate.setDate(w1EndDate.getDate() + daysUntilSat);
  const w1End = new Date(w1EndDate.getFullYear(), w1EndDate.getMonth(), w1EndDate.getDate(), 23, 59, 59, 999);

  weeks.push({
    weekNumber: 1,
    start: w1Start,
    end: w1End,
    label: `${formatDayMonth(w1Start)} – ${formatDayMonth(w1End)}`
  });

  // Weeks 2-5
  let cursor = new Date(w1End);
  cursor.setDate(cursor.getDate() + 1); // First Sunday after week 1

  for (let wn = 2; wn <= 5; wn++) {
    if (cursor > period.end) {
      weeks.push({ weekNumber: wn, start: null, end: null, label: '' });
      continue;
    }

    const wStart = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate(), 0, 0, 0, 0);
    let wEnd: Date;

    if (wn === 5) {
      wEnd = new Date(period.end);
    } else {
      const satDate = new Date(wStart);
      satDate.setDate(satDate.getDate() + 6); // +6 days = Saturday
      wEnd = new Date(satDate.getFullYear(), satDate.getMonth(), satDate.getDate(), 23, 59, 59, 999);
      if (wEnd > period.end) {
        wEnd = new Date(period.end);
      }
    }

    weeks.push({
      weekNumber: wn,
      start: wStart,
      end: wEnd,
      label: `${formatDayMonth(wStart)} – ${formatDayMonth(wEnd)}`
    });

    cursor = new Date(wEnd);
    cursor.setDate(cursor.getDate() + 1);
  }

  // Guarantee exactly 5 slots
  while (weeks.length < 5) {
    weeks.push({ weekNumber: weeks.length + 1, start: null, end: null, label: '' });
  }

  return weeks;
}

/**
 * Get the financial week (within the current period) that contains a given date.
 */
export function getFinancialWeekForDate(date: Date): FinancialWeek {
  const period = getCurrentFinancialPeriod();
  const weeks  = getFinancialWeeks(period);

  for (const week of weeks) {
    if (!week.start || !week.end) continue;
    if (date >= week.start && date <= week.end) {
      return week;
    }
  }

  return weeks[0];
}

/**
 * Get all 24 hourly slots for a given date.
 */
export function getHourlySlots(date: Date): HourlySlot[] {
  const slots: HourlySlot[] = [];
  const y = date.getFullYear();
  const m = date.getMonth();
  const d = date.getDate();

  for (let hour = 0; hour < 24; hour++) {
    const start = new Date(y, m, d, hour, 0, 0, 0);
    const end   = new Date(y, m, d, hour, 59, 59, 999);
    const hh    = String(hour).padStart(2, '0');
    const label = `${hh}:00`;
    slots.push({ hour, start, end, label });
  }

  return slots;
}

/**
 * Get daily slots for a financial week.
 */
export function getDailySlots(week: { start: Date; end: Date }): DailySlot[] {
  const slots: DailySlot[] = [];
  const cursor = new Date(week.start.getFullYear(), week.start.getMonth(), week.start.getDate());
  const endDay = new Date(week.end.getFullYear(), week.end.getMonth(), week.end.getDate());

  while (cursor <= endDay) {
    const label = `${DAYS_SHORT[cursor.getDay()]} ${formatDayMonth(cursor)}`;
    slots.push({ date: new Date(cursor), label });
    cursor.setDate(cursor.getDate() + 1);
  }

  return slots;
}

/**
 * Build a weekly label like "Week 2 · 17–23 Mar"
 */
export function buildWeekLabel(week: FinancialWeek): string {
  if (!week.start || !week.end) return `Wk ${week.weekNumber}`;
  return `Week ${week.weekNumber} · ${formatDayMonth(week.start)}–${formatDayMonth(week.end)}`;
}

/**
 * Build a daily label like "Mon 17 Mar"
 */
export function buildDayLabel(date: Date): string {
  return `${DAYS_SHORT[date.getDay()]} ${formatDayMonth(date)}`;
}

/**
 * Build an hourly label like "Mon 17 Mar · 09:00–10:00"
 */
export function buildHourLabel(date: Date, hour: number): string {
  const hh   = String(hour).padStart(2, '0');
  const hhN  = String(hour + 1).padStart(2, '0');
  return `${buildDayLabel(date)} · ${hh}:00–${hhN}:00`;
}

/**
 * Format amount as NIS string: ₪1,234.50
 */
export function formatNIS(amount: number): string {
  return `\u20AA${amount.toLocaleString('en-IL', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

/**
 * Sum amounts from a list of transactions.
 */
export function sumAmounts(transactions: { amount: number }[]): number {
  return transactions.reduce((acc, t) => acc + t.amount, 0);
}

/**
 * Return the date portion of an ISO string as a local Date at midnight.
 */
export function toLocalDate(isoString: string): Date {
  const d = new Date(isoString);
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

/**
 * Format a payment method key to a human-readable string.
 */
export function formatPaymentMethod(method: string, card?: { lastFourDigits: string; nickname?: string | null } | null): string {
  switch (method) {
    case 'card':
      if (card) return card.nickname ?? `••••${card.lastFourDigits}`;
      return 'Card';
    case 'credit_card':   return 'Card'; // legacy fallback
    case 'debit_card':    return 'Card'; // legacy fallback
    case 'cash':          return 'Cash';
    case 'bank_transfer': return 'Bank Transfer';
    default:              return method;
  }
}
