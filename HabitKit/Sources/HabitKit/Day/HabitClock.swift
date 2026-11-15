import Foundation

/// The clock, calendar, time zone, locale and day-start hour as one injectable value.
/// Tests and screenshots build one from fixtures.
public struct HabitClock: Sendable {
    public static let dayStartRange = 0...8
    public static let defaultDayStartHour = 4

    public var now: @Sendable () -> Date
    /// The user's calendar. It carries the time zone, locale and first weekday.
    public var calendar: Calendar
    public private(set) var dayStartHour: Int

    public init(
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .autoupdatingCurrent,
        dayStartHour: Int = HabitClock.defaultDayStartHour
    ) {
        self.now = now
        self.calendar = calendar
        self.dayStartHour = min(max(dayStartHour, Self.dayStartRange.lowerBound), Self.dayStartRange.upperBound)
    }

    /// A clock frozen at one instant, for tests and screenshots.
    public static func frozen(at date: Date, timeZone: TimeZone, locale: Locale = Locale(identifier: "en_GB"), dayStartHour: Int = defaultDayStartHour) -> HabitClock {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        return HabitClock(now: { date }, calendar: calendar, dayStartHour: dayStartHour)
    }

    /// Gregorian calendar in the user's time zone, used to read wall-clock fields.
    private var wallCalendar: Calendar {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        return gregorian
    }

    /// The logical day an instant belongs to.
    ///
    /// The day turns over when the wall clock reaches the day-start hour. On a night when that
    /// hour does not exist because of daylight saving, it turns over at the next valid time.
    public func dayKey(for date: Date) -> DayKey {
        let c = wallCalendar.dateComponents([.year, .month, .day, .hour], from: date)
        let key = DayKey(year: c.year!, month: c.month!, day: c.day!)
        return c.hour! < dayStartHour ? key.adding(days: -1) : key
    }

    public var today: DayKey { dayKey(for: now()) }

    /// True between midnight and the day-start hour, when Today still shows the day before.
    public var isBeforeDayStart: Bool {
        wallCalendar.component(.hour, from: now()) < dayStartHour
    }

    /// Midday of the day in the user's time zone. Use it to format a day for display.
    public func date(for key: DayKey) -> Date {
        wallCalendar.date(from: DateComponents(year: key.year, month: key.month, day: key.day, hour: 12))!
    }

    /// The next instant the day turns over, for the "Until 04:00" line.
    public var dayStartTimeToday: Date {
        let c = wallCalendar.dateComponents([.year, .month, .day], from: now())
        return wallCalendar.date(from: DateComponents(year: c.year, month: c.month, day: c.day, hour: dayStartHour))!
    }
}
