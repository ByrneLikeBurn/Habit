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
        Task { @MainActor in completion(Self.timeline().entries.first ?? placeholder(in: context)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        Task { @MainActor in
            let (entries, settleAt) = Self.timeline()
            let reload = [entries.last?.date, settleAt].compactMap { $0 }.min() ?? .now.addingTimeInterval(3600)
            completion(Timeline(entries: entries, policy: .after(reload)))
        }
    }

    /// The entries, and when settled rows should give way to rows still to do, if that is later today.
    @MainActor
    static func timeline() -> (entries: [TodayEntry], settleAt: Date?) {
        guard case .success(let container) = SharedStore.container else { return ([], nil) }
        // A fresh context each time, so writes from the app are read, not a cached copy.
        let context = ModelContext(container)
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let shared = (try? PauseWriter.sharedPauses(in: context)) ?? []
        let clock = SharedStore.clock
        // Each day's rows are chosen once, the first time it is in a timeline, and kept, so the first tap
        // of a day finds the rows it drew.
        // Rows that are all done give way to rows still to do once the last widget tap is a while past.
        let now = clock.now()
        let settleAt = WidgetRows.lastTap.map { $0.addingTimeInterval(WidgetRows.settleTime) }
        let settled = settleAt.map { now >= $0 } ?? true
        var chosen: [DayKey: [Int: [UUID]]] = [:]
        var askLater = false
        let entries = WidgetSnapshot.entryDates(clock: clock).map { date in
            let day = clock.dayKey(for: date)
            // Only the day's events are fetched; the widget's memory stays flat as history grows.
            let snapshot = WidgetSnapshot.make(habits: habits, sharedPauses: shared, today: day,
                                               totals: (try? LogWriter.dayTotals(on: day, in: context)) ?? [:])
            let stored = WidgetRows.kept(on: day)
            let isToday = day == clock.today
            let kept = chosen[day] ?? snapshot.chosenRows(kept: stored, rechooseSettled: isToday && settled)
            if isToday && !settled && snapshot.hasSettledRoom(kept: kept) { askLater = true }
            chosen[day] = kept
            return TodayEntry(date: date, snapshot: snapshot, kept: kept)
        }
        WidgetRows.keep(chosen, today: clock.today)
        return (entries, askLater ? settleAt : nil)
    }
}
