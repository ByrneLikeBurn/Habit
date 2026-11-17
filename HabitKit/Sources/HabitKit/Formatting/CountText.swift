import Foundation

/// Words for counts. The user's unit is shown as typed. Numbers use the locale's grouping.
public enum CountText {
    /// The largest number that can be typed or logged at once.
    public static let maximumAmount = 1_000_000

    /// The count line under a counted habit, for example "3 of 8 glasses" or "3 glasses".
    /// Today's line on a row. A habit with no set days and nothing logged today is never owed, so it names
    /// its target ("Target 20 minutes"), not "0 of 20 minutes". Once logged it reads like any other row.
    public static func todayLine(total: Int, target: Int?, unit: String, noSetDays: Bool, locale: Locale = .autoupdatingCurrent) -> String {
        guard noSetDays, total == 0, let target else { return line(total: total, target: target, unit: unit, locale: locale) }
        let t = target.formatted(.number.locale(locale))
        let unit = unit.trimmingCharacters(in: .whitespaces)
        if unit.isEmpty {
            return String(localized: "Target \(t)", bundle: .module, comment: "Today row for a habit with no set days, before anything is logged today: the target alone. Not a daily quota")
        }
        return String(localized: "Target \(t) \(unit)", bundle: .module, comment: "Today row for a habit with no set days, before anything is logged today: the target with the unit as the user typed it. Not a daily quota")
    }

    public static func line(total: Int, target: Int?, unit: String, locale: Locale = .autoupdatingCurrent) -> String {
        let n = total.formatted(.number.locale(locale))
        let unit = unit.trimmingCharacters(in: .whitespaces)
        switch (target, unit.isEmpty) {
        case let (target?, false):
            let t = target.formatted(.number.locale(locale))
            return String(localized: "\(n) of \(t) \(unit)", bundle: .module, comment: "Count line: total, target, the unit as the user typed it")
        case let (target?, true):
            let t = target.formatted(.number.locale(locale))
            return String(localized: "\(n) of \(t)", bundle: .module, comment: "Count line with no unit: total, target")
        case (nil, false):
            return String(localized: "\(n) \(unit)", bundle: .module, comment: "Count line with no target: total, the unit as typed")
        case (nil, true):
            return n
        }
    }

    /// The line under the total in the count sheet, for example "of 8 glasses today".
    public static func sheetCaption(target: Int?, unit: String, dayName: String?, locale: Locale = .autoupdatingCurrent) -> String {
        let unit = unit.trimmingCharacters(in: .whitespaces)
        let when = dayName ?? String(localized: "today", bundle: .module, comment: "Count sheet caption for today")
        switch (target, unit.isEmpty) {
        case let (target?, false):
            return String(localized: "of \(target.formatted(.number.locale(locale))) \(unit) \(when)", bundle: .module)
        case let (target?, true):
            return String(localized: "of \(target.formatted(.number.locale(locale))) \(when)", bundle: .module)
        case (nil, false):
            return String(localized: "\(unit) \(when)", bundle: .module)
        case (nil, true):
            return when
        }
    }

    /// Parses a typed whole number, allowing the locale's grouping separator.
    /// nil if it is not a whole number or is beyond `maximumAmount` either way.
    public static func parse(_ text: String, locale: Locale = .autoupdatingCurrent) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let value = Int(trimmed) { return abs(value) <= maximumAmount ? value : nil }
        // Allow the grouping separator, but never a fraction.
        guard let value = try? Decimal(trimmed, format: .number.locale(locale)),
              abs(value) <= Decimal(maximumAmount) else { return nil }
        let number = NSDecimalNumber(decimal: value)
        guard number == NSDecimalNumber(value: number.intValue) else { return nil }
        return number.intValue
    }

    /// The default tap amount for a target: 1 when the target is 20 or less or empty, otherwise
    /// empty, which means a tap opens the count sheet.
    public static func defaultTapAmount(forTarget target: Int?) -> Int? {
        guard let target else { return 1 }
        return target <= 20 ? 1 : nil
    }
}
