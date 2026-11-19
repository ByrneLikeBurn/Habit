import Foundation
import HabitKit

/// The widget's rows for each day, chosen the first time that day is drawn, including a day ahead in the
/// timeline, and kept all day. Stored in the shared settings by day, so a redraw after a tap keeps every row
/// where it was, the first tap of a day included. See `WidgetSnapshot.shownRows`.
enum WidgetRows {
    private static let key = "widgetRowsByDay"

    private static var stored: [String: [String: [String]]] {
        SharedStore.defaults.dictionary(forKey: key) as? [String: [String: [String]]] ?? [:]
    }

    static func kept(on day: DayKey) -> [Int: [UUID]] {
        var result: [Int: [UUID]] = [:]
        for (room, ids) in stored[String(day.rawValue)] ?? [:] {
            if let room = Int(room) { result[room] = ids.compactMap(UUID.init(uuidString:)) }
        }
        return result
    }

    /// Saves the rows for `days`, keeping no day before `today`.
    static func keep(_ rows: [DayKey: [Int: [UUID]]], today: DayKey) {
        var all = stored.filter { (Int($0.key) ?? 0) >= today.rawValue }
        for (day, byRoom) in rows {
            all[String(day.rawValue)] = Dictionary(uniqueKeysWithValues: byRoom.map { (String($0.key), $0.value.map(\.uuidString)) })
        }
        SharedStore.defaults.set(all, forKey: key)
    }
}
