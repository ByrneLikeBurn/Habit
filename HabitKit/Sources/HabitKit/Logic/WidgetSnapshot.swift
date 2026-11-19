import Foundation

/// What the Home Screen widget shows, built from the store only. The widget draws this and nothing ahead of a write.
/// Rows keep Today's order and come from `Ordering.today`, and each mark from `Habit.state(on:today:)`, so the widget
/// follows the same rules as Today, no set days and pauses included.
public struct WidgetSnapshot: Equatable, Sendable {
    public struct Row: Equatable, Sendable, Identifiable {
        public var id: UUID
        public var name: String
        public var symbolName: String
        public var kind: HabitKind
        public var state: DayState
        /// The day's total, for the intent's check that nothing changed since the widget drew.
        public var total: Int
        /// The count line for a counted habit, nil for a yes-or-no one.
        public var countLine: String?
        public var tapAmount: Int?
        public var paused: Bool
    }

    public var day: DayKey
    /// The header reads "Paused" while a pause with no habit covers the day.
    public var paused: Bool
    public var rows: [Row]
    /// False when there are no habits at all, for "Nothing to track yet".
    public var hasHabits: Bool

    public init(day: DayKey, paused: Bool, rows: [Row], hasHabits: Bool) {
        self.day = day
        self.paused = paused
        self.rows = rows
        self.hasHabits = hasHabits
    }

    /// A widget tap logs only if the widget still shows today and the total it drew. Otherwise the widget
    /// redraws and nothing is written, so a row drawn before midnight never logs the new day, and a second
    /// tap on a row not yet redrawn never takes the first log back.
    public static func accepts(shownDay: Int, shownTotal: Int, today: DayKey, currentTotal: Int) -> Bool {
        shownDay == today.rawValue && shownTotal == currentTotal
    }

    /// The widget's mark size. Its diamond (68% of the mark) sits well above the 12 point jump in the cut.
    public static let markSize: CGFloat = 24

    @MainActor
    public static func make(habits: [Habit], sharedPauses: [Pause], today: DayKey, locale: Locale = .autoupdatingCurrent) -> WidgetSnapshot {
        let split = Ordering.today(habits, day: today)
        let rows = split.scheduled.map { habit -> Row in
            let total = habit.total(on: today)
            let state = habit.state(on: today, today: today, total: total, sharedPauses: sharedPauses)
            let paused = habit.isPaused(on: today, sharedPauses: sharedPauses)
            let count = habit.kind == .counted
                ? CountText.todayLine(total: total, target: habit.rule(on: today).target, unit: habit.unit,
                                      noSetDays: state == .noSetDays, paused: paused, locale: locale)
                : nil
            return Row(id: habit.id, name: habit.name, symbolName: habit.symbolName, kind: habit.kind, state: state,
                       total: total, countLine: count, tapAmount: habit.tapAmount, paused: paused)
        }
        return WidgetSnapshot(day: today, paused: SharedPauseStatus.of(sharedPauses, today: today).isPaused,
                              rows: rows, hasHabits: !Ordering.sorted(habits).isEmpty)
    }

    /// Entry dates: now, then each day start ahead. Pauses begin and end on day boundaries, so each pause edge
    /// is a day start too. The widget reloads after the last.
    public static func entryDates(clock: HabitClock, days: Int = 2) -> [Date] {
        var dates = [clock.now()]
        var next = clock.nextDayStart(after: clock.now())
        for _ in 0..<days {
            dates.append(next)
            next = clock.nextDayStart(after: next.addingTimeInterval(60))
        }
        return dates
    }
}

extension HabitClock {
    /// The next instant the day turns over, after `date`. On a daylight-saving night with no such hour,
    /// the calendar gives the next valid time.
    public func nextDayStart(after date: Date) -> Date {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let c = gregorian.dateComponents([.year, .month, .day], from: date)
        var candidate = gregorian.date(from: DateComponents(year: c.year, month: c.month, day: c.day, hour: dayStartHour))!
        while candidate <= date {
            let d = gregorian.date(byAdding: .day, value: 1, to: gregorian.date(from: DateComponents(year: c.year, month: c.month, day: c.day, hour: 12))!)!
            let n = gregorian.dateComponents([.year, .month, .day], from: candidate > d ? candidate : d)
            candidate = gregorian.date(from: DateComponents(year: n.year, month: n.month, day: n.day, hour: dayStartHour))!
        }
        return candidate
    }
}
