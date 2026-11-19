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

    /// Quiet text. In tinted and clear modes the system's secondary level.
    private var quiet: AnyShapeStyle {
        renderingMode == .fullColor ? AnyShapeStyle(style.secondary) : AnyShapeStyle(.secondary)
    }

    /// The user's style. In tinted and clear modes the system sets the colour from luminance, so marks are drawn
    /// as Increase Contrast draws them, in the text colour with heavier ink, and quiet text uses the system's
    /// secondary level. A mid-blue mark or grey text would turn faint there.
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
                             increaseContrast: contrast == .increased || renderingMode != .fullColor)
    }

    /// A row is dropped before text shrinks. When rows are dropped, a line says how many more there are,
    /// so a full set of marks never reads as the whole day. At standard sizes the line takes one row's place
    /// (none in the medium grid, which has two columns). At accessibility sizes it sits in the header.
    private func shownCount(of total: Int, room: Int) -> Int {
        if total <= room { return total }
        if typeSize.isAccessibilitySize || family == .systemMedium { return room }
        return max(room - 1, 1)
    }

    /// The rooms to try, most rows first. At accessibility sizes the medium widget tries two rows, then one,
    /// and shows what fits, so nothing overprints.
    private var rooms: [Int] {
        if typeSize.isAccessibilitySize { return family == .systemMedium ? [2, 1] : [1] }
        return [family == .systemMedium ? 4 : 3]
    }

    var body: some View {
        let style = style
        Group {
            if rooms.count > 1 {
                ViewThatFits(in: .vertical) {
                    ForEach(rooms, id: \.self) { layout(room: $0, style) }
                }
            } else {
                layout(room: rooms[0], style)
            }
        }
        .environment(\.style, style)
        .containerBackground(for: .widget) { style.paper }
    }

    private func layout(room: Int, _ style: ResolvedStyle) -> some View {
        let all = entry.snapshot.rows.count
        let hidden = all - shownCount(of: all, room: room)
        // At accessibility sizes a tall first letter of the name would touch the header's baseline.
        return VStack(alignment: .leading, spacing: typeSize.isAccessibilitySize ? 8 : 4) {
            header(style, hidden: hidden)
            // Habit names can be health details. On a locked device, in StandBy and on the lock screen,
            // the system redacts the rows. The "Today" header stays.
            content(style, room: room)
                .privacySensitive()
            Spacer(minLength: 0)
        }
    }

    private func header(_ style: ResolvedStyle, hidden: Int) -> some View {
        HStack(spacing: 6) {
            Text("Today").font(style.display(.subheadline, weight: .semibold)).foregroundStyle(style.text)
            Spacer(minLength: 4)
            if typeSize.isAccessibilitySize, hidden > 0 {
                // At accessibility sizes the count of habits not shown sits here, away from the marks.
                // The short form fits beside "Today". VoiceOver reads the full words.
                Text("\(hidden) more", comment: "Widget header at large text sizes: how many habits did not fit, short. For example: 5 more.")
                    .font(style.label(.caption))
                    .monospacedDigit()
                    .foregroundStyle(quiet)
                    .lineLimit(1)
                    .accessibilityLabel(Text(moreText(hidden)))
            }
            if entry.snapshot.paused {
                // The small widget has room for the symbol only. VoiceOver reads "Paused".
                Label("Paused", systemImage: "pause.circle")
                    .labelStyle(family == .systemSmall ? AnyLabelStyle(.iconOnly) : AnyLabelStyle(.titleAndIcon))
                    .font(style.label(.caption))
                    .foregroundStyle(quiet)
            } else if family == .systemMedium && !typeSize.isAccessibilitySize {
                Text(SharedStore.clock.date(for: entry.snapshot.day).formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(style.label(.caption))
                    .foregroundStyle(quiet)
            }
        }
        // The header keeps to one line at every size, so the rows get the room.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .combine)
    }

    /// The small widget at accessibility sizes: one row, the name above its mark.
    private var stacked: Bool { typeSize.isAccessibilitySize && family == .systemSmall }

    private func moreText(_ more: Int) -> String {
        String(localized: "\(more) more habits", comment: "Widget: how many of today's habits did not fit. Plural variations in the String Catalog. For example: 3 more habits.")
    }

    @ViewBuilder
    private func content(_ style: ResolvedStyle, room: Int) -> some View {
        let all = entry.snapshot.rows
        let shown = shownCount(of: all.count, room: room)
        let rows = entry.snapshot.shownRows(room: shown, kept: entry.kept[shown] ?? [])
        let more = all.count - rows.count
        if !entry.snapshot.hasHabits {
            Button(intent: WidgetOpenIntent(.newHabit)) {
                VStack(alignment: .leading, spacing: 4) {
                    if !typeSize.isAccessibilitySize {
                        Text("Nothing to track yet.").font(style.label(.footnote)).foregroundStyle(quiet)
                    }
                    Text("Add a habit").font(style.label(.footnote, weight: .semibold)).foregroundStyle(style.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Opens the app to add a habit"))
        } else if rows.isEmpty {
            Text("Nothing scheduled today.").font(style.label(.footnote)).foregroundStyle(quiet)
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
        if more > 0 && !typeSize.isAccessibilitySize {
            Spacer().frame(height: 4)
            // How many more, not how many are left to do. A tap here opens Today.
            Button(intent: WidgetOpenIntent(.today)) {
                Text(moreText(more))
                    .font(style.label(.caption))
                    .monospacedDigit()
                    .foregroundStyle(quiet)
                    // A short, quiet line. It keeps to one line so the row above keeps its room.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Opens Today"))
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
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Quiet text. In tinted and clear modes the system's secondary level, so it stays legible on any wallpaper.
    private var quiet: AnyShapeStyle {
        renderingMode == .fullColor ? AnyShapeStyle(style.secondary) : AnyShapeStyle(.secondary)
    }

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
            VStack(alignment: .leading, spacing: 0) {
                Text(row.name)
                    .font(style.label(.footnote))
                    .foregroundStyle(style.text)
                    .lineLimit(row.countLine == nil || typeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(stacked ? 0.8 : 1)
                    .fixedSize(horizontal: false, vertical: stacked)
                // A counted tap may not change the mark, so the count shows what the tap did.
                // At accessibility sizes the name takes both lines and VoiceOver reads the count.
                if let count = row.countLine, !typeSize.isAccessibilitySize {
                    Text(count)
                        .font(style.label(.caption2))
                        .monospacedDigit()
                        .foregroundStyle(quiet)
                        .lineLimit(1)
                }
            }
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
                // A tap amount typed each time needs the count sheet: the row opens the app on it.
                Button(intent: WidgetOpenIntent(.count(row.id))) { label }
                    .buttonStyle(.plain)
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
