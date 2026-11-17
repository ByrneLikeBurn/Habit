import Foundation

/// A set of weekdays, stored as the habit's schedule mask. Bit 0 is Sunday, bit 6 is Saturday.
/// 127 is every day.
public struct Weekdays: OptionSet, Hashable, Codable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue & 127
    }

    /// `weekday` is Gregorian: 1 is Sunday, 7 is Saturday.
    public init(weekday: Int) {
        self.init(rawValue: 1 << (weekday - 1))
    }

    public static let all = Weekdays(rawValue: 127)

    public func contains(weekday: Int) -> Bool {
        contains(Weekdays(weekday: weekday))
    }

    public func contains(_ day: DayKey) -> Bool {
        contains(weekday: day.weekday)
    }

    public var count: Int { rawValue.nonzeroBitCount }
}

/// One day button in a weekday picker.
public struct WeekdayLabel: Hashable, Sendable, Identifiable {
    /// Gregorian weekday, 1 is Sunday.
    public let weekday: Int
    /// One letter, or two where one letter would repeat in this locale.
    public let short: String
    /// The full name, for VoiceOver.
    public let full: String

    public var id: Int { weekday }
}

public enum WeekdayText {
    /// The seven weekdays in the order of the user's calendar, starting on its first weekday.
    public static func labels(calendar: Calendar) -> [WeekdayLabel] {
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        let veryShort = calendar.veryShortStandaloneWeekdaySymbols
        let short = calendar.shortStandaloneWeekdaySymbols
        let full = calendar.standaloneWeekdaySymbols
        var counts: [String: Int] = [:]
        for letter in veryShort { counts[letter, default: 0] += 1 }
        return order.map { weekday in
            let i = weekday - 1
            let letter = veryShort[i]
            let label = counts[letter, default: 0] > 1 ? String(short[i].prefix(2)) : letter
            return WeekdayLabel(weekday: weekday, short: label, full: full[i])
        }
    }

    /// The text inside each day button, by Gregorian weekday (index 0 is Sunday). Two letters of the short
    /// name where all seven differ, as drawn. Where they repeat, as in Arabic and Hebrew, the very short
    /// names, and where those repeat too, the short names in full.
    public static func buttonTexts(calendar: Calendar) -> [String] {
        let twoLetters = calendar.shortStandaloneWeekdaySymbols.map { String($0.prefix(2)) }
        if Set(twoLetters).count == 7 { return twoLetters }
        let veryShort = calendar.veryShortStandaloneWeekdaySymbols
        if Set(veryShort).count == 7 { return veryShort }
        return calendar.shortStandaloneWeekdaySymbols
    }

    /// A sentence that restates a schedule, for example "Every day except Thursday".
    public static func sentence(for days: Weekdays, calendar: Calendar) -> String {
        let labels = labels(calendar: calendar)
        let chosen = labels.filter { days.contains(weekday: $0.weekday) }.map(\.full)
        let missing = labels.filter { !days.contains(weekday: $0.weekday) }.map(\.full)
        let locale = calendar.locale ?? .autoupdatingCurrent
        switch chosen.count {
        case 7:
            return String(localized: "Every day", bundle: .module)
        case 0:
            return String(localized: "No set days", bundle: .module, comment: "Habit detail. The habit has no set days and can be logged on any day.")
        case 4...6:
            let list = missing.formatted(.list(type: .and).locale(locale))
            return String(localized: "Every day except \(list)", bundle: .module, comment: "The list names the days the habit is not set for")
        default:
            return chosen.formatted(.list(type: .and).locale(locale))
        }
    }
}
