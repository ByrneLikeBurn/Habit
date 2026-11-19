import AppIntents
import Foundation
import SwiftData
import WidgetKit
import HabitKit

/// The widget row's button. It carries the day the widget showed and the total it drew, and logs through
/// `LogHabitIntent`, the one write path. If the day has turned over or the total has changed since the widget
/// drew, it writes nothing and redraws the widget, so a stale row never logs the wrong day or takes a log back.
struct WidgetLogIntent: AppIntent {
    static let title: LocalizedStringResource = "Log from the widget"
    static let isDiscoverable = false
    static let supportedModes: IntentModes = .background
    /// A tap on a locked device changes nothing until it is unlocked.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Habit") var habitID: String
    @Parameter(title: "Day") var day: Int
    @Parameter(title: "Total") var total: Int

    init() {}

    init(habitID: UUID, day: DayKey, total: Int) {
        self.habitID = habitID.uuidString
        self.day = day.rawValue
        self.total = total
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        defer { WidgetReload.now() }
        let clock = SharedStore.clock
        guard clock.today.rawValue == day, let id = UUID(uuidString: habitID) else { return .result() }
        // A fresh context, so the total compared is the one in the store now.
        let context = ModelContext(try SharedStore.container.get())
        var fetch = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == id })
        fetch.fetchLimit = 1
        guard let habit = try context.fetch(fetch).first, habit.isActive,
              WidgetSnapshot.accepts(shownDay: day, shownTotal: total, today: clock.today, currentTotal: (try? LogWriter.rawTotal(of: habit, on: clock.today, in: context)) ?? -1) else {
            return .result()
        }
        let intent = LogHabitIntent(habitID: habit.id, name: habit.name, action: .tap, source: .widget, day: clock.today)
        try intent.execute(in: context, clock: clock)
        return .result()
    }
}
