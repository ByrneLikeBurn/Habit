import AppIntents
import Foundation

/// Where a widget tap that cannot log opens the app: the count sheet for one habit, a new habit, or Today.
/// The tap records the place in the shared settings, and the app opens it when it becomes active.
/// No URL scheme, no link: nothing outside the app can open it.
struct WidgetOpenIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Habit"
    static let isDiscoverable = false
    static let openAppWhenRun = true
    /// Opening the app needs an unlocked device, as every intent here does.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Place") var place: String

    init() {}
    init(_ place: WidgetPlace) { self.place = place.rawValue }

    @MainActor
    func perform() async throws -> some IntentResult {
        SharedStore.defaults.set(place, forKey: WidgetPlace.key)
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

    /// Reads and clears the place a widget tap left.
    @MainActor
    static func take() -> WidgetPlace? {
        let defaults = SharedStore.defaults
        guard let raw = defaults.string(forKey: key) else { return nil }
        defaults.removeObject(forKey: key)
        return WidgetPlace(rawValue: raw)
    }
}
