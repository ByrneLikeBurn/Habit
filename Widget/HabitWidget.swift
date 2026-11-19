import SwiftUI
import SwiftData
import WidgetKit
import AppIntents
import HabitKit

@main
struct HabitWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}

/// One Home Screen widget, small and medium: today's habits in Today's order. Each row is a button that logs.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Today", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Today's habits. Tap one to log it.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// Draws from the store only. An entry at now and at each day start ahead; pause edges fall on day starts.
struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snapshot: WidgetSnapshot(day: SharedStore.clock.today, paused: false, rows: [], hasHabits: true))
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        Task { @MainActor in completion(Self.entries().first ?? placeholder(in: context)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        Task { @MainActor in
            let entries = Self.entries()
            let reload = entries.last?.date ?? .now.addingTimeInterval(3600)
            completion(Timeline(entries: entries, policy: .after(reload)))
        }
    }

    @MainActor
    static func entries() -> [TodayEntry] {
        guard case .success(let container) = SharedStore.container else { return [] }
        // A fresh context each time, so writes from the app are read, not a cached copy.
        let context = ModelContext(container)
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let shared = (try? PauseWriter.sharedPauses(in: context)) ?? []
        let clock = SharedStore.clock
        // Each day's rows are chosen once, the first time it is in a timeline, and kept, so the first tap
        // of a day finds the rows it drew.
        var chosen: [DayKey: [Int: [UUID]]] = [:]
        let entries = WidgetSnapshot.entryDates(clock: clock).map { date in
            let day = clock.dayKey(for: date)
            let snapshot = WidgetSnapshot.make(habits: habits, sharedPauses: shared, today: day)
            let kept = chosen[day] ?? snapshot.chosenRows(kept: WidgetRows.kept(on: day))
            chosen[day] = kept
            return TodayEntry(date: date, snapshot: snapshot, kept: kept)
        }
        WidgetRows.keep(chosen, today: clock.today)
        return entries
    }
}
