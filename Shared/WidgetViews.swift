import SwiftUI
import WidgetKit
import AppIntents
import HabitKit

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    /// The rows chosen at the day's first draw, by room size. Empty for a day not yet drawn.
    var kept: [Int: [UUID]] = [:]
}

/// The widget's drawing, in Shared so the app can show it on a debug screen for screenshots.
struct TodayWidgetView: View {
    let entry: TodayEntry
    /// Set by the app's debug board, where there is no widget family.
    var boardFamily: WidgetFamily?
    @Environment(\.widgetFamily) private var widgetFamily
    private var family: WidgetFamily { boardFamily ?? widgetFamily }
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

    /// A row is dropped before text shrinks. When rows are dropped, one row's place goes to a line that
    /// says how many more there are, so a full set of marks never reads as the whole day.
    private func shownCount(of total: Int) -> Int {
        let room = typeSize.isAccessibilitySize ? (family == .systemMedium ? 2 : 1) : (family == .systemMedium ? 4 : 3)
        if total <= room { return total }
        // The medium grid has two columns, so the line takes no row there.
        return family == .systemMedium && !typeSize.isAccessibilitySize ? room : max(room - 1, 1)
    }

    var body: some View {
        let style = style
        VStack(alignment: .leading, spacing: 4) {
            header(style)
            // Habit names can be health details. On a locked device, in StandBy and on the lock screen,
            // the system redacts the rows. The "Today" header stays.
            content(style)
                .privacySensitive()
            Spacer(minLength: 0)
        }
        .environment(\.style, style)
        .containerBackground(for: .widget) { style.paper }
    }

    private func header(_ style: ResolvedStyle) -> some View {
        HStack(spacing: 6) {
            Text("Today").font(style.display(.subheadline, weight: .semibold)).foregroundStyle(style.text)
            Spacer(minLength: 4)
            if stacked, hiddenCount > 0 {
                // At accessibility sizes the small widget says how many more here, away from the mark.
                // The short form fits beside "Today". VoiceOver reads the full words.
                Text("\(hiddenCount) more", comment: "Small widget header at large text sizes: how many habits did not fit, short. For example: 5 more.")
                    .font(style.label(.caption))
                    .foregroundStyle(style.secondary)
                    .lineLimit(1)
                    .accessibilityLabel(Text(moreText(hiddenCount)))
            }
            if entry.snapshot.paused {
                // The small widget has room for the symbol only. VoiceOver reads "Paused".
                Label("Paused", systemImage: "pause.circle")
                    .labelStyle(family == .systemSmall ? AnyLabelStyle(.iconOnly) : AnyLabelStyle(.titleAndIcon))
                    .font(style.label(.caption))
                    .foregroundStyle(style.secondary)
            } else if family == .systemMedium && !typeSize.isAccessibilitySize {
                Text(SharedStore.clock.date(for: entry.snapshot.day).formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(style.label(.caption))
                    .foregroundStyle(style.secondary)
            }
        }
        // The header keeps to one line at every size, so the rows get the room.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .combine)
    }

    private var hiddenCount: Int {
        let all = entry.snapshot.rows.count
        return all - shownCount(of: all)
    }

    /// The small widget at accessibility sizes: one row, the name above its mark.
    private var stacked: Bool { typeSize.isAccessibilitySize && family == .systemSmall }

    private func moreText(_ more: Int) -> String {
        String(localized: "\(more) more habits", comment: "Widget: how many of today's habits did not fit. Plural variations in the String Catalog. For example: 3 more habits.")
    }

    @ViewBuilder
    private func content(_ style: ResolvedStyle) -> some View {
        let all = entry.snapshot.rows
        let room = shownCount(of: all.count)
        let rows = entry.snapshot.shownRows(room: room, kept: entry.kept[room] ?? [])
        let more = all.count - rows.count
        if !entry.snapshot.hasHabits {
            VStack(alignment: .leading, spacing: 4) {
                if !typeSize.isAccessibilitySize {
                    Text("Nothing to track yet.").font(style.label(.footnote)).foregroundStyle(style.secondary)
                }
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
                ForEach(rows) {
                    WidgetRow(row: $0, day: entry.snapshot.day, showsSymbol: !typeSize.isAccessibilitySize,
                              stacked: stacked)
                }
            }
        }
        if more > 0 && !stacked {
            // How many more, not how many are left to do. A tap here opens Today.
            Text(moreText(more))
                .font(style.label(.caption))
                .foregroundStyle(style.secondary)
                // A short, quiet line. It keeps to one line so the row above keeps its room.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }
}

/// One row: symbol, name and mark. The whole row is the button, 44 points high. No row draws the plus.
struct WidgetRow: View {
    let row: WidgetSnapshot.Row
    let day: DayKey
    let showsSymbol: Bool
    var stacked = false
    @Environment(\.style) private var style

    var body: some View {
        // At accessibility sizes in a narrow widget the name takes the full width, with the mark below it.
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 8))
        let label = layout {
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
                .minimumScaleFactor(stacked ? 0.8 : 1)
                .fixedSize(horizontal: false, vertical: stacked)
                .layoutPriority(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                MarkView(state: row.state, isToday: true, showsPlus: false, size: 24)
                    .widgetAccentable()
            }
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
            if let amount = row.tapAmount, amount > 0 {
                String(localized: "Adds \(CountText.line(total: amount, target: nil, unit: row.unit))", comment: "Widget, VoiceOver hint for a counted habit. The amount with its unit, for example: Adds 250 ml.")
            } else {
                String(localized: "Opens the app to add an amount")
            }
        }
    }
}

/// A label style chosen at run time.
struct AnyLabelStyle: LabelStyle {
    private let make: (Configuration) -> AnyView
    init<S: LabelStyle>(_ style: S) { make = { AnyView(Label($0).labelStyle(style)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}
