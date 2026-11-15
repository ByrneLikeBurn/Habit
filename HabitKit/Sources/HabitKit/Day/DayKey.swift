import Foundation

/// One logical day, stored as yyyymmdd.
///
/// The key always uses Gregorian year, month and day, so stored keys sort and compare
/// the same whatever calendar the user reads dates in. Display uses the user's calendar.
public struct DayKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(year: Int, month: Int, day: Int) {
        rawValue = year * 10_000 + month * 100 + day
    }

    public var year: Int { rawValue / 10_000 }
    public var month: Int { rawValue / 100 % 100 }
    public var day: Int { rawValue % 100 }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool { lhs.rawValue < rhs.rawValue }

    public var description: String { String(rawValue) }

    /// Day arithmetic runs in a fixed UTC Gregorian calendar, so daylight saving never moves it.
    static let arithmetic: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    var utcNoon: Date {
        DayKey.arithmetic.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    init(utcDate: Date) {
        let c = DayKey.arithmetic.dateComponents([.year, .month, .day], from: utcDate)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    public func adding(days: Int) -> DayKey {
        DayKey(utcDate: DayKey.arithmetic.date(byAdding: .day, value: days, to: utcNoon)!)
    }

    /// Days from `self` to `other`. Positive when `other` is later.
    public func days(to other: DayKey) -> Int {
        DayKey.arithmetic.dateComponents([.day], from: utcNoon, to: other.utcNoon).day!
    }

    /// Gregorian weekday, 1 is Sunday and 7 is Saturday.
    public var weekday: Int {
        DayKey.arithmetic.component(.weekday, from: utcNoon)
    }
}
