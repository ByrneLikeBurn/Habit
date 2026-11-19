import AppIntents
import Foundation

/// Where a widget tap that cannot log opens the app: the count sheet for one habit, a new habit, or Today.
/// The tap records the place in the shared settings, and the app opens it when it becomes active.
/// No URL scheme, no link: nothing outside the app can open it.
struct WidgetOpenIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Habit"
    static let isDiscoverable = false
    static let supportedModes: IntentModes = .foreground
    /// Opening the app needs an unlocked device, as every intent here does.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Place") var place: String

    init() {}
    init(_ place: WidgetPlace) { self.place = place.rawValue }

    @MainActor
    func perform() async throws -> some IntentResult {
        WidgetPlace(rawValue: place)?.record()
        return .result()
    }
}

/// A place the widget opens. Stored as text: "today", "new" or "count:<habit id>".
nonisolated enum WidgetPlace: Equatable, Sendable {
    case today, newHabit, count(UUID)

    static let key = "widgetOpens"

    var rawValue: String {
        switch self {
        case .today: "today"
        case .newHabit: "new"
        case .count(let id): "count:" + id.uuidString
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "today": self = .today
        case "new": self = .newHabit
        default:
            guard rawValue.hasPrefix("count:"), let id = UUID(uuidString: String(rawValue.dropFirst(6))) else { return nil }
            self = .count(id)
        }
    }

    /// The app can become active before the intent runs, or the intent can run while the app is open,
    /// so the place is stored with its time and announced. A place older than this is never opened.
    static let freshFor: TimeInterval = 10
    static let recorded = Notification.Name("widgetPlaceRecorded")

    @MainActor
    func record() {
        SharedStore.defaults.set([Self.key: rawValue, "at": Date().timeIntervalSince1970] as [String: Any], forKey: Self.key)
        NotificationCenter.default.post(name: Self.recorded, object: nil)
    }

    /// Reads and clears the place a widget tap left, if it is fresh.
    @MainActor
    static func take(now: Date = Date()) -> WidgetPlace? {
        let defaults = SharedStore.defaults
        guard let stored = defaults.dictionary(forKey: key) else { return nil }
        defaults.removeObject(forKey: key)
        guard let raw = stored[key] as? String, let at = stored["at"] as? TimeInterval,
              now.timeIntervalSince1970 - at < freshFor else { return nil }
        return WidgetPlace(rawValue: raw)
    }
}
