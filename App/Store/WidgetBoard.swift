import SwiftUI
import SwiftData
import HabitKit

/// Debug screenshots only: the widget's drawing in its two sizes, from the fixture store. The Home Screen
/// adds the corner radius and, in tinted and clear modes, the system's own colour, which this cannot show.
struct WidgetBoard: View {
    @Environment(\.modelContext) private var context
    @Environment(Settings.self) private var settings
    @Environment(\.style) private var style

    var body: some View {
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let shared = (try? PauseWriter.sharedPauses(in: context)) ?? []
        let today = settings.clock.today
        let entry = TodayEntry(date: settings.clock.now(), snapshot: WidgetSnapshot.make(habits: habits, sharedPauses: shared, today: today))
        let empty = TodayEntry(date: settings.clock.now(), snapshot: WidgetSnapshot(day: today, paused: false, rows: [], hasHabits: false))
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 20) {
                    tile(entry, width: 170)
                    tile(empty, width: 170)
                }
                tile(entry, width: 364)
            }
            .padding(16)
        }
        .background(style.rule)
    }

    private func tile(_ entry: TodayEntry, width: CGFloat) -> some View {
        TodayWidgetView(entry: entry, boardFamily: width > 200 ? .systemMedium : .systemSmall)
            .padding(16)
            .frame(width: width, height: 170, alignment: .topLeading)
            .background(style.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
