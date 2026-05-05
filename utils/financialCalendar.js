/**
 * Financial Calendar Utility
 * Pure utility module – no DB, no framework dependencies.
 * Financial period: month running from the 10th to the 9th of the following month.
 */

/**
 * Format a date as "D Mon" e.g. "10 Mar"
 * @param {Date} date
 * @returns {string}
 */
function formatDayMonth(date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return `${date.getDate()} ${months[date.getMonth()]}`;
}

/**
 * Format a date as "D Mon YYYY" e.g. "10 Mar 2025"
 * @param {Date} date
 * @returns {string}
 */
function formatDayMonthYear(date) {
  return `${formatDayMonth(date)} ${date.getFullYear()}`;
}

/**
 * Build the period label "10 Mar – 9 Apr 2025"
 * @param {Date} start
 * @param {Date} end
 * @returns {string}
 */
function buildPeriodLabel(start, end) {
  return `${formatDayMonth(start)} – ${formatDayMonthYear(end)}`;
}

/**
 * Get the current financial period.
 * Period runs from `startDay` of one month to `startDay - 1` of the next.
 * @param {number} startDay - 1..28 (default 10)
 * @returns {{ start: Date, end: Date, label: string }}
 */
function getCurrentFinancialPeriod(startDay = 10) {
  return getFinancialPeriod(0, startDay);
}

/**
 * Get a specific financial period by offset from current.
 * @param {number} offset - 0 = current, -1 = previous, 1 = next
 * @param {number} startDay - day of month the period begins on (1..28, default 10)
 * @returns {{ start: Date, end: Date, label: string }}
 */
function getFinancialPeriod(offset = 0, startDay = 10) {
  const today = new Date();
  const day = today.getDate();

  // Determine the "anchor" month — the month in which the period starts (on `startDay`)
  let anchorYear = today.getFullYear();
  let anchorMonth = today.getMonth(); // 0-based

  if (day < startDay) {
    // Current period started last month
    anchorMonth -= 1;
    if (anchorMonth < 0) {
      anchorMonth = 11;
      anchorYear -= 1;
    }
  }

  // Apply offset (each offset shifts by one calendar month)
  anchorMonth += offset;
  while (anchorMonth > 11) { anchorMonth -= 12; anchorYear += 1; }
  while (anchorMonth < 0)  { anchorMonth += 12; anchorYear -= 1; }

  // Period start: `startDay` of anchor month at 00:00:00
  const start = new Date(anchorYear, anchorMonth, startDay, 0, 0, 0, 0);

  let end;
  if (startDay === 1) {
    // Calendar month: end is last day of anchor month
    let nextMonth = anchorMonth + 1;
    let nextYear  = anchorYear;
    if (nextMonth > 11) { nextMonth = 0; nextYear += 1; }
    end = new Date(nextYear, nextMonth, 1, 0, 0, 0, 0);
    end = new Date(end.getTime() - 1);
  } else {
    // Period end: (startDay - 1) of anchor month + 1 at 23:59:59
    let endMonth = anchorMonth + 1;
    let endYear  = anchorYear;
    if (endMonth > 11) { endMonth = 0; endYear += 1; }
    end = new Date(endYear, endMonth, startDay - 1, 23, 59, 59, 999);
  }

  return { start, end, label: buildPeriodLabel(start, end) };
}

/**
 * Get a calendar-month period (1st → end of month) for a given offset.
 * Used when the caller explicitly requests `periodType=calendar`.
 * @param {number} offset - 0 = current, -1 = previous, 1 = next
 * @returns {{ start: Date, end: Date, label: string }}
 */
function getCalendarMonthPeriod(offset = 0) {
  return getFinancialPeriod(offset, 1);
}

/**
 * Get the financial period for an explicit (year, month) anchor.
 * The anchor is the calendar month in which the period starts on `startDay`.
 * @param {number} anchorYear
 * @param {number} anchorMonth - 1..12
 * @param {number} startDay - day of month the period begins on (1..28, default 10)
 * @returns {{ start: Date, end: Date, label: string }}
 */
function getFinancialPeriodForAnchor(anchorYear, anchorMonth, startDay = 10) {
  const m = anchorMonth - 1; // 0-based
  const start = new Date(anchorYear, m, startDay, 0, 0, 0, 0);

  let end;
  if (startDay === 1) {
    let nextMonth = m + 1;
    let nextYear  = anchorYear;
    if (nextMonth > 11) { nextMonth = 0; nextYear += 1; }
    end = new Date(new Date(nextYear, nextMonth, 1, 0, 0, 0, 0).getTime() - 1);
  } else {
    let endMonth = m + 1;
    let endYear  = anchorYear;
    if (endMonth > 11) { endMonth = 0; endYear += 1; }
    end = new Date(endYear, endMonth, startDay - 1, 23, 59, 59, 999);
  }

  return { start, end, label: buildPeriodLabel(start, end) };
}

/**
 * Get the 5 financial weeks within a financial period.
 * Week 1 : period.start → coming Saturday at 23:59:59
 *           (if period.start is already Saturday, week 1 = that day only)
 * Weeks 2-4: full Sunday–Saturday weeks
 * Week 5 : Sunday after week 4 ends → period.end
 * Always returns exactly 5 elements; pads with { start: null, end: null, label: '' } if needed.
 *
 * @param {{ start: Date, end: Date }} period
 * @returns {Array<{ weekNumber: number, start: Date, end: Date, label: string }>}
 */
function getFinancialWeeks(period) {
  const weeks = [];

  // ---- Week 1 ----
  const w1Start = new Date(period.start);

  // Find the next Saturday (day 6) on or after w1Start
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

  // ---- Weeks 2–5 ----
  let cursor = new Date(w1End);
  cursor.setDate(cursor.getDate() + 1); // First Sunday after week 1

  for (let wn = 2; wn <= 5; wn++) {
    if (cursor > period.end) {
      // Pad with empty slot
      weeks.push({ weekNumber: wn, start: null, end: null, label: '' });
      continue;
    }

    const wStart = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate(), 0, 0, 0, 0);

    let wEnd;
    if (wn === 5) {
      // Last week always ends on period.end
      wEnd = new Date(period.end);
    } else {
      // Full Sunday–Saturday week: end is the Saturday of this week
      const satDate = new Date(wStart);
      satDate.setDate(satDate.getDate() + 6); // +6 days = Saturday
      wEnd = new Date(satDate.getFullYear(), satDate.getMonth(), satDate.getDate(), 23, 59, 59, 999);

      // Cap at period.end (shouldn't normally happen for weeks 2-4, but be safe)
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

    // Advance cursor to next Sunday
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
 * Get the financial week that contains a given date.
 * @param {Date} date
 * @returns {{ weekNumber: number, start: Date, end: Date, label: string }}
 */
function getFinancialWeekForDate(date) {
  const period = getCurrentFinancialPeriod();
  const weeks  = getFinancialWeeks(period);

  for (const week of weeks) {
    if (!week.start || !week.end) continue;
    if (date >= week.start && date <= week.end) {
      return week;
    }
  }

  // Fallback: return week 1 if date is outside any slot (edge case)
  return weeks[0];
}

/**
 * Get hourly slots for a given date (for hourly timeline view).
 * @param {Date} date
 * @returns {Array<{ hour: number, start: Date, end: Date, label: string }>}
 */
function getHourlySlots(date) {
  const slots = [];
  const y = date.getFullYear();
  const m = date.getMonth();
  const d = date.getDate();

  for (let hour = 0; hour < 24; hour++) {
    const start = new Date(y, m, d, hour, 0, 0, 0);
    const end   = new Date(y, m, d, hour, 59, 59, 999);
    const ampm  = hour < 12 ? 'AM' : 'PM';
    const displayHour = hour === 0 ? 12 : hour > 12 ? hour - 12 : hour;
    const label = `${displayHour}:00 ${ampm}`;
    slots.push({ hour, start, end, label });
  }

  return slots;
}

/**
 * Get daily slots for a financial week.
 * @param {{ start: Date, end: Date }} week
 * @returns {Array<{ date: Date, label: string }>}
 */
function getDailySlots(week) {
  const days    = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const months  = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const slots   = [];

  const cursor = new Date(week.start.getFullYear(), week.start.getMonth(), week.start.getDate());
  const endDay = new Date(week.end.getFullYear(), week.end.getMonth(), week.end.getDate());

  while (cursor <= endDay) {
    const dayName = days[cursor.getDay()];
    const label   = `${dayName} ${cursor.getDate()}/${cursor.getMonth() + 1}`;
    slots.push({ date: new Date(cursor), label });
    cursor.setDate(cursor.getDate() + 1);
  }

  return slots;
}

module.exports = {
  getCurrentFinancialPeriod,
  getFinancialPeriod,
  getCalendarMonthPeriod,
  getFinancialPeriodForAnchor,
  getFinancialWeeks,
  getFinancialWeekForDate,
  getHourlySlots,
  getDailySlots
};
