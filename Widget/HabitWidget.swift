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

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
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
        let context = container.mainContext
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let shared = (try? PauseWriter.sharedPauses(in: context)) ?? []
        let clock = SharedStore.clock
        return WidgetSnapshot.entryDates(clock: clock).map { date in
            TodayEntry(date: date, snapshot: WidgetSnapshot.make(habits: habits, sharedPauses: shared, today: clock.dayKey(for: date)))
        }
    }
}

struct TodayWidgetView: View {
    let entry: TodayEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var typeSize

    /// The user's style. In tinted and clear modes the system sets the colour, so marks and text are drawn
    /// light and full opacity, and the system's vibrant foreground carries them.
    private var style: ResolvedStyle {
        let defaults = SharedStore.defaults
        let choice = AppearanceChoice.resolve(defaults.string(forKey: SettingKey.appearance))
        let chosen: Appearance = switch choice {
        case .system: colorScheme == .dark ? .ink : .paper
        case .paper: .paper
        case .ink: .ink
        }
        let appearance: Appearance = renderingMode == .fullColor ? chosen : .ink
        return ResolvedStyle(tokens: StyleID.resolve(defaults.string(forKey: SettingKey.style)).tokens,
                             appearance: appearance,
                             accent: Swatch.resolve(defaults.string(forKey: SettingKey.accent)),
                             increaseContrast: contrast == .increased)
    }

    /// A row is dropped before text shrinks. Two rows at accessibility sizes.
    private var rowLimit: Int {
        if typeSize.isAccessibilitySize { return 2 }
        return family == .systemMedium ? 4 : 3
    }

    var body: some View {
        let style = style
        VStack(alignment: .leading, spacing: 4) {
            header(style)
            content(style)
            Spacer(minLength: 0)
        }
        .environment(\.style, style)
        .containerBackground(for: .widget) { style.paper }
    }

    private func header(_ style: ResolvedStyle) -> some View {
        HStack(spacing: 6) {
            Text("Today").font(style.display(.subheadline, weight: .semibold)).foregroundStyle(style.text)
            Spacer(minLength: 4)
            if entry.snapshot.paused {
                Label("Paused", systemImage: "pause.circle")
                    .font(style.label(.caption))
                    .foregroundStyle(style.secondary)
            } else if family == .systemMedium && !typeSize.isAccessibilitySize {
                Text(SharedStore.clock.date(for: entry.snapshot.day).formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(style.label(.caption))
                    .foregroundStyle(style.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func content(_ style: ResolvedStyle) -> some View {
        let rows = Array(entry.snapshot.rows.prefix(rowLimit))
        if !entry.snapshot.hasHabits {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nothing to track yet.").font(style.label(.footnote)).foregroundStyle(style.secondary)
                Text("Add a habit").font(style.label(.footnote, weight: .semibold)).foregroundStyle(style.text)
            }
        } else if rows.isEmpty {
            Text("Nothing scheduled today.").font(style.label(.footnote)).foregroundStyle(style.secondary)
        } else if family == .systemMedium && !typeSize.isAccessibilitySize {
            let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
                ForEach(rows) { WidgetRow(row: $0, day: entry.snapshot.day, showsSymbol: true) }
            }
        } else {
            VStack(spacing: 0) {
                ForEach(rows) { WidgetRow(row: $0, day: entry.snapshot.day, showsSymbol: !typeSize.isAccessibilitySize) }
            }
        }
    }
}

/// One row: symbol, name and mark. The whole row is the button, 44 points high. No row draws the plus.
struct WidgetRow: View {
    let row: WidgetSnapshot.Row
    let day: DayKey
    let showsSymbol: Bool
    @Environment(\.style) private var style

    var body: some View {
        let label = HStack(spacing: 8) {
            if showsSymbol && !row.symbolName.isEmpty {
                Image(systemName: row.symbolName)
                    .font(style.label(.caption))
                    .foregroundStyle(style.text)
                    .frame(width: 16)
                    .accessibilityHidden(true)
            }
            Text(row.name)
                .font(style.label(.footnote))
                .foregroundStyle(style.text)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            MarkView(state: row.state, isToday: true, showsPlus: false, size: 24)
                .widgetAccentable()
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())

        Group {
            if row.kind == .counted && (row.tapAmount ?? 0) <= 0 {
                // A tap amount typed each time needs the count sheet: the row opens the app.
                label
            } else {
                Button(intent: WidgetLogIntent(habitID: row.id, day: day, total: row.total)) { label }
                    .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(row.name))
        .accessibilityValue(Text(value))
        .accessibilityHint(Text(hint))
        .accessibilityAddTraits(.isButton)
    }

    private var value: String {
        var parts: [String] = []
        if let count = row.countLine { parts.append(count) }
        switch row.state {
        case .done: parts.append(String(localized: "Done"))
        case .partDone: if row.countLine == nil { parts.append(String(localized: "Part done")) }
        case .paused: parts.append(String(localized: "Paused"))
        case .loggedWhilePaused: parts.append(String(localized: "Logged while paused"))
        case .noSetDays: parts.append(String(localized: "No set days"))
        default: break
        }
        return parts.joined(separator: ", ")
    }

    private var hint: String {
        switch row.kind {
        case .binary: row.total > 0 ? String(localized: "Takes the log back") : String(localized: "Logs it")
        case .counted:
            if let amount = row.tapAmount, amount > 0 { String(localized: "Adds \(amount.formatted())") } else { String(localized: "Opens Habit") }
        }
    }
}
