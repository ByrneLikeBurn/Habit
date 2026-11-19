import Foundation
import HabitKit

/// The widget's rows for today, chosen at the day's first draw and kept all day. Stored in the shared
/// settings by day, so a redraw after a tap keeps every row where it was. See `WidgetSnapshot.shownRows`.
enum WidgetRows {
    private static let dayKey = "widgetRowsDay"
    private static let rowsKey = "widgetRows"

    static func kept(on day: DayKey) -> [Int: [UUID]] {
        let defaults = SharedStore.defaults
        guard defaults.integer(forKey: dayKey) == day.rawValue,
              let stored = defaults.dictionary(forKey: rowsKey) as? [String: [String]] else { return [:] }
        var result: [Int: [UUID]] = [:]
        for (room, ids) in stored { if let room = Int(room) { result[room] = ids.compactMap(UUID.init(uuidString:)) } }
        return result
    }

    static func keep(_ rows: [Int: [UUID]], on day: DayKey) {
        let defaults = SharedStore.defaults
        defaults.set(day.rawValue, forKey: dayKey)
        defaults.set(Dictionary(uniqueKeysWithValues: rows.map { (String($0.key), $0.value.map(\.uuidString)) }), forKey: rowsKey)
    }
}
