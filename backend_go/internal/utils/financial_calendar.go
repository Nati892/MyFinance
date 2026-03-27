package utils

import (
	"fmt"
	"time"
)

// FinancialPeriod represents a financial month: runs from the 10th of one
// calendar month to the 9th of the next at 23:59:59.
// Identical logic to your utils/financialCalendar.js.
type FinancialPeriod struct {
	Start time.Time `json:"start"`
	End   time.Time `json:"end"`
	Label string    `json:"label"`
}

// FinancialWeek is one of the 5 weekly slots within a financial period.
// nil Start/End means the slot is unused (padding for periods shorter than 5 weeks).
type FinancialWeek struct {
	WeekNumber int        `json:"weekNumber"`
	Start      *time.Time `json:"start"`
	End        *time.Time `json:"end"`
	Label      string     `json:"label"`
}

// HourlySlot represents one hour of a day in the hourly timeline view.
type HourlySlot struct {
	Hour  int        `json:"hour"`
	Start time.Time  `json:"start"`
	End   time.Time  `json:"end"`
	Label string     `json:"label"`
}

// DailySlot is one day in a weekly view.
type DailySlot struct {
	Date  time.Time `json:"date"`
	Label string    `json:"label"`
}

var monthNames = [12]string{
	"Jan", "Feb", "Mar", "Apr", "May", "Jun",
	"Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
}

var dayNames = [7]string{"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}

// GetFinancialPeriod returns the financial period at `offset` months from current.
// 0 = current, -1 = previous, 1 = next.
//
// In Go, time arithmetic uses time.Date() for calendar math — it handles month
// overflow correctly (e.g., January - 1 = December of the previous year).
func GetFinancialPeriod(offset int) FinancialPeriod {
	today := time.Now()
	day := today.Day()

	// Determine the anchor month — the month in which this period starts (on the 10th).
	anchorYear := today.Year()
	// time.Month is an int-like type (1=Jan...12=Dec). We convert to int for math.
	anchorMonth := int(today.Month())

	if day < 10 {
		// We're before the 10th, so the current period started last month
		anchorMonth--
		if anchorMonth < 1 {
			anchorMonth = 12
			anchorYear--
		}
	}

	// Apply the offset — each unit is one calendar month
	anchorMonth += offset
	for anchorMonth > 12 {
		anchorMonth -= 12
		anchorYear++
	}
	for anchorMonth < 1 {
		anchorMonth += 12
		anchorYear--
	}

	// Period start: 10th of anchor month at 00:00:00.000
	// time.Date normalizes overflows: time.Date(2024, 13, 1, ...) = 2025-01-01
	start := time.Date(anchorYear, time.Month(anchorMonth), 10, 0, 0, 0, 0, time.Local)

	// Period end: 9th of the following month at 23:59:59.999
	endMonth := anchorMonth + 1
	endYear := anchorYear
	if endMonth > 12 {
		endMonth = 1
		endYear++
	}
	end := time.Date(endYear, time.Month(endMonth), 9, 23, 59, 59, int(999*time.Millisecond), time.Local)

	return FinancialPeriod{
		Start: start,
		End:   end,
		Label: buildPeriodLabel(start, end),
	}
}

// GetCurrentFinancialPeriod returns the current period (offset = 0).
func GetCurrentFinancialPeriod() FinancialPeriod {
	return GetFinancialPeriod(0)
}

// GetFinancialWeeks returns exactly 5 weekly slots for a given period.
// Week 1: period.Start → next Saturday at 23:59:59
// Weeks 2-4: full Sunday–Saturday weeks
// Week 5: Sunday after week 4 → period.End
func GetFinancialWeeks(period FinancialPeriod) []FinancialWeek {
	weeks := make([]FinancialWeek, 0, 5)

	// Week 1: from period.Start to the nearest Saturday (inclusive)
	w1Start := period.Start
	// time.Weekday(): 0=Sunday, 1=Monday, ..., 6=Saturday
	dayOfWeek := int(w1Start.Weekday())
	daysUntilSat := 6 - dayOfWeek // 0 if already Saturday
	w1EndDate := w1Start.AddDate(0, 0, daysUntilSat)
	w1End := time.Date(w1EndDate.Year(), w1EndDate.Month(), w1EndDate.Day(), 23, 59, 59, 0, time.Local)

	w1StartCopy := w1Start
	w1EndCopy := w1End
	weeks = append(weeks, FinancialWeek{
		WeekNumber: 1,
		Start:      &w1StartCopy,
		End:        &w1EndCopy,
		Label:      fmt.Sprintf("%s – %s", formatDayMonth(w1Start), formatDayMonth(w1End)),
	})

	// Cursor advances to the Sunday after week 1 ends
	cursor := w1End.AddDate(0, 0, 1)
	cursor = time.Date(cursor.Year(), cursor.Month(), cursor.Day(), 0, 0, 0, 0, time.Local)

	for wn := 2; wn <= 5; wn++ {
		if cursor.After(period.End) {
			// Pad with an empty slot
			weeks = append(weeks, FinancialWeek{WeekNumber: wn, Label: ""})
			continue
		}

		wStart := cursor
		var wEnd time.Time

		if wn == 5 {
			// Last week always ends on period.End
			wEnd = period.End
		} else {
			// Full Sunday–Saturday: add 6 days to get Saturday
			satDate := wStart.AddDate(0, 0, 6)
			wEnd = time.Date(satDate.Year(), satDate.Month(), satDate.Day(), 23, 59, 59, 0, time.Local)
			// Cap at period.End
			if wEnd.After(period.End) {
				wEnd = period.End
			}
		}

		wStartCopy := wStart
		wEndCopy := wEnd
		weeks = append(weeks, FinancialWeek{
			WeekNumber: wn,
			Start:      &wStartCopy,
			End:        &wEndCopy,
			Label:      fmt.Sprintf("%s – %s", formatDayMonth(wStart), formatDayMonth(wEnd)),
		})

		cursor = wEnd.AddDate(0, 0, 1)
		cursor = time.Date(cursor.Year(), cursor.Month(), cursor.Day(), 0, 0, 0, 0, time.Local)
	}

	// Guarantee exactly 5 slots
	for len(weeks) < 5 {
		weeks = append(weeks, FinancialWeek{WeekNumber: len(weeks) + 1, Label: ""})
	}

	return weeks
}

// GetHourlySlots returns 24 hourly slots for a given date (for the hourly timeline view).
func GetHourlySlots(date time.Time) []HourlySlot {
	slots := make([]HourlySlot, 24)
	y, m, d := date.Year(), date.Month(), date.Day()

	for hour := 0; hour < 24; hour++ {
		start := time.Date(y, m, d, hour, 0, 0, 0, time.Local)
		end := time.Date(y, m, d, hour, 59, 59, 0, time.Local)

		// Build "12:00 PM" style label
		ampm := "AM"
		displayHour := hour
		if hour >= 12 {
			ampm = "PM"
		}
		if hour == 0 {
			displayHour = 12
		} else if hour > 12 {
			displayHour = hour - 12
		}

		slots[hour] = HourlySlot{
			Hour:  hour,
			Start: start,
			End:   end,
			Label: fmt.Sprintf("%d:00 %s", displayHour, ampm),
		}
	}

	return slots
}

// GetDailySlots returns one slot per day within a week.
func GetDailySlots(week FinancialWeek) []DailySlot {
	if week.Start == nil || week.End == nil {
		return []DailySlot{}
	}

	slots := []DailySlot{}
	cursor := time.Date(week.Start.Year(), week.Start.Month(), week.Start.Day(), 0, 0, 0, 0, time.Local)
	endDay := time.Date(week.End.Year(), week.End.Month(), week.End.Day(), 0, 0, 0, 0, time.Local)

	for !cursor.After(endDay) {
		label := fmt.Sprintf("%s %d/%d", dayNames[cursor.Weekday()], cursor.Day(), int(cursor.Month()))
		slots = append(slots, DailySlot{Date: cursor, Label: label})
		cursor = cursor.AddDate(0, 0, 1)
	}

	return slots
}

// formatDayMonth formats a date as "10 Mar" — used in period labels.
func formatDayMonth(t time.Time) string {
	return fmt.Sprintf("%d %s", t.Day(), monthNames[t.Month()-1])
}

// buildPeriodLabel builds "10 Mar – 9 Apr 2025".
func buildPeriodLabel(start, end time.Time) string {
	return fmt.Sprintf("%s – %d %s %d",
		formatDayMonth(start),
		end.Day(), monthNames[end.Month()-1], end.Year(),
	)
}
