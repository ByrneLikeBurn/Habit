import Foundation

/// The views of Habit detail. History has Week and Month only.
public enum PeriodKind: String, CaseIterable, Sendable, Hashable {
    case week, month, year
}

/// Weeks, months and years over day keys.
///
/// Months and years are Gregorian, like day keys, so a period always holds whole stored days.
/// Weeks start on the user's first weekday.
public enum Periods {
    /// The first day of the week holding `day`. `firstWeekday` is Gregorian: 1 is Sunday.
    public static func weekStart(of day: DayKey, firstWeekday: Int) -> DayKey {
        let back = (day.weekday - firstWeekday + 7) % 7
        return day.adding(days: -back)
    }

    public static func week(of day: DayKey, firstWeekday: Int) -> [DayKey] {
        let start = weekStart(of: day, firstWeekday: firstWeekday)
        return (0..<7).map { start.adding(days: $0) }
    }

    public static func monthStart(of day: DayKey) -> DayKey {
        DayKey(year: day.year, month: day.month, day: 1)
    }

    public static func daysInMonth(of day: DayKey) -> Int {
        let start = monthStart(of: day)
        return start.days(to: adding(months: 1, to: start))
    }

    public static func monthDays(of day: DayKey) -> [DayKey] {
        let start = monthStart(of: day)
        return (0..<daysInMonth(of: day)).map { start.adding(days: $0) }
    }

    /// The month grid: rows of seven, starting on the first weekday, with nil outside the month.
    public static func monthGrid(of day: DayKey, firstWeekday: Int) -> [[DayKey?]] {
        let days = monthDays(of: day)
        let lead = (days[0].weekday - firstWeekday + 7) % 7
        var cells: [DayKey?] = Array(repeating: nil, count: lead) + days.map(Optional.some)
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    /// The first of the month `months` after the month of `day`.
    public static func adding(months: Int, to day: DayKey) -> DayKey {
        let index = day.year * 12 + (day.month - 1) + months
        return DayKey(year: index / 12, month: index % 12 + 1, day: 1)
    }

    /// Moves `day` by whole periods and returns a day in the new period.
    public static func move(_ day: DayKey, by count: Int, kind: PeriodKind) -> DayKey {
        switch kind {
        case .week:
            return day.adding(days: 7 * count)
        case .month:
            return adding(months: count, to: day)
        case .year:
            return DayKey(year: day.year + count, month: 1, day: 1)
        }
    }

    /// True when `a` and `b` fall in the same period.
    public static func same(_ a: DayKey, _ b: DayKey, kind: PeriodKind, firstWeekday: Int) -> Bool {
        switch kind {
        case .week: weekStart(of: a, firstWeekday: firstWeekday) == weekStart(of: b, firstWeekday: firstWeekday)
        case .month: a.year == b.year && a.month == b.month
        case .year: a.year == b.year
        }
    }

    /// The first day the year view must draw for `since`: the Monday of its week, because a week
    /// belongs to the month that holds its Monday. It may fall in the month or year before.
    public static func yearViewStart(since: DayKey) -> DayKey {
        weekStart(of: since, firstWeekday: 2)
    }

    /// The months of the year view: from the month holding the Monday of the `since` week when that
    /// falls in `year`, else January, through December or the month holding the Monday of the week
    /// of `today`, whichever is first. Every day from `since` to `today` is drawn once.
    public static func yearMonths(year: Int, since: DayKey, today: DayKey) -> [DayKey] {
        let start = yearViewStart(since: since)
        let end = max(weekStart(of: today, firstWeekday: 2), start)
        let first = start.year == year ? start.month : 1
        let last = end.year == year ? end.month : 12
        guard start.year <= year, year <= end.year, first <= last else { return [] }
        return (first...last).map { DayKey(year: year, month: $0, day: 1) }
    }

    /// The earliest day that can be logged or shown, as import accepts.
    public static let earliest = DayKey(year: 2000, month: 1, day: 1)

    /// The weeks drawn for one month in the year view. A week belongs to the month that holds its Monday,
    /// so every day is drawn once in the year.
    public static func yearWeeks(of month: DayKey) -> [[DayKey]] {
        // Weeks run Monday to Sunday here, whatever the first weekday, so "holds its Monday" is exact.
        let days = monthDays(of: month)
        let mondays = days.filter { $0.weekday == 2 }
        return mondays.map { monday in (0..<7).map { monday.adding(days: $0) } }
    }

    /// A valid day key between 1 January 2000 and 31 December 2199.
    public static func isValid(_ raw: Int) -> Bool {
        let key = DayKey(rawValue: raw)
        guard (2000...2199).contains(key.year), (1...12).contains(key.month), key.day >= 1 else { return false }
        return key.day <= daysInMonth(of: DayKey(year: key.year, month: key.month, day: 1))
    }
}
