import SwiftUI
import SwiftData
import HabitKit

/// Dates in words, in the user's locale and time zone.
struct DayWords {
    let clock: HabitClock

    private var locale: Locale { clock.calendar.locale ?? .autoupdatingCurrent }
    private func style() -> Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: gregorian, timeZone: clock.calendar.timeZone)
    }
    /// Periods are Gregorian, like day keys, so their names are too.
    private var gregorian: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = locale
        c.timeZone = clock.calendar.timeZone
        return c
    }

    func date(_ day: DayKey) -> Date { clock.date(for: day) }

    /// "Tuesday 10 November"
    func long(_ day: DayKey) -> String {
        date(day).formatted(style().weekday(.wide).day().month(.wide))
    }

    /// "7 November"
    func dayMonth(_ day: DayKey) -> String {
        date(day).formatted(style().day().month(.wide))
    }

    /// "Mon 9"
    func short(_ day: DayKey) -> String {
        date(day).formatted(style().weekday(.abbreviated).day())
    }

    /// "November 2026"
    func month(_ day: DayKey) -> String {
        date(day).formatted(style().month(.wide).year())
    }

    /// "Nov"
    func monthShort(_ day: DayKey) -> String {
        date(day).formatted(style().month(.abbreviated))
    }

    /// "28 April 2026"
    func full(_ day: DayKey) -> String {
        date(day).formatted(style().day().month(.wide).year())
    }

    private func intervalStyle() -> Date.IntervalFormatStyle {
        Date.IntervalFormatStyle(locale: locale, calendar: gregorian, timeZone: clock.calendar.timeZone)
    }

    /// "9–15 November" in en_GB, "November 9 – 15" in en_US. The locale orders and joins the dates.
    func week(_ days: [DayKey]) -> String {
        guard let first = days.first, let last = days.last else { return "" }
        if first == last { return dayMonth(first) }
        return (date(first)..<date(last)).formatted(intervalStyle().day().month(.wide))
    }

    /// "17 July – 13 November 2026", with the year.
    func range(_ first: DayKey, _ last: DayKey) -> String {
        if first == last { return full(first) }
        return (date(first)..<date(last)).formatted(intervalStyle().day().month(.wide).year())
    }

    func title(_ kind: PeriodKind, anchor: DayKey) -> String {
        switch kind {
        case .week: week(Periods.week(of: anchor, firstWeekday: clock.calendar.firstWeekday))
        case .month: month(anchor)
        case .year: date(anchor).formatted(style().year())
        }
    }

    /// The state of a day in words, for VoiceOver. A day with no log is read as the date alone.
    static func state(_ state: DayState) -> String? {
        switch state {
        case .done: String(localized: "Done")
        case .partDone: String(localized: "Part done")
        case .paused: String(localized: "Paused")
        case .loggedWhilePaused: String(localized: "Logged while paused")
        case .loggedOffSchedule: String(localized: "Logged on a day off")
        case .offSchedule: String(localized: "Not scheduled")
        case .notLogged: String(localized: "Not logged")
        case .blank: nil
        }
    }
}

/// The period title, which returns to the current period, and the previous and next arrows.
struct PeriodHeader: View {
    let title: String
    let isCurrent: Bool
    var canGoBack = true
    let canGoForward: Bool
    let move: (Int) -> Void
    let goToCurrent: () -> Void
    @Environment(\.style) private var style

    var body: some View {
        HStack(spacing: 0) {
            Button(action: goToCurrent) {
                Text(title)
                    .font(style.display(.title3))
                    .underline()
                    .foregroundStyle(style.text)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isCurrent ? Text("") : Text("Goes back to now"))
            Spacer(minLength: 8)
            Button { move(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canGoBack)
            .accessibilityLabel(Text("Previous"))
            Button { move(1) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
            .accessibilityLabel(Text("Next"))
        }
        .font(style.label(.body))
        .foregroundStyle(style.text)
    }
}

/// The key under the year view and the History month: the small shapes and what each means.
struct SmallMarkKey: View {
    @Environment(\.style) private var style
    @Environment(Settings.self) private var settings

    /// The diamond is drawn for a log on a paused day and for a log on a day off, so its entry names both.
    private var entries: [(DayState, Bool, LocalizedStringResource)] {
        var list: [(DayState, Bool, LocalizedStringResource)] = [
            (.done, false, "Done"), (.partDone, false, "Part done"), (.paused, false, "Paused"),
            (.loggedWhilePaused, false, "Logged while paused or on a day off"), (.offSchedule, false, "Not scheduled"),
        ]
        if settings.showDaysNotLogged { list.append((.notLogged, false, "Not logged")) }
        return list
    }

    var body: some View {
        let entries = entries
        FlowLayout(spacing: 12, lineSpacing: 4) {
            ForEach(entries.indices, id: \.self) { i in
                HStack(spacing: 4) {
                    SmallMarkView(state: entries[i].0, isToday: entries[i].1, size: 10)
                    Text(entries[i].2)
                }
            }
        }
        .font(style.label(.caption))
        .foregroundStyle(style.secondary)
        .accessibilityElement(children: .combine)
    }
}

/// One small mark, for keys and lists.
struct SmallMarkView: View {
    let state: DayState
    var isToday = false
    let size: CGFloat
    @Environment(\.style) private var style

    var body: some View {
        Canvas { context, canvasSize in
            SmallMark.draw(state, isToday: isToday, in: CGRect(origin: .zero, size: canvasSize).insetBy(dx: 2, dy: 2), context: &context, style: style)
        }
        .frame(width: size + 4, height: size + 4)
        .accessibilityHidden(true)
    }
}

/// Wraps children onto new lines when they do not fit.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                y += line + lineSpacing
                x = 0
                line = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            line = max(line, size.height)
        }
        return CGSize(width: min(widest, width), height: y + line)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, line: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += line + lineSpacing
                x = bounds.minX
                line = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            line = max(line, size.height)
        }
    }
}

/// "Tap" on touch screens, "Click" on the Mac.
enum Verb {
    #if os(macOS)
    static let tapPastDay = String(localized: "Click a past day to add or change a log.")
    static let tapHabitOrDay = String(localized: "Click a habit to open it. Click a day to add or change a log.")
    static let tapHabitMonth = String(localized: "Click a habit to open its month.")
    static let tapMonth = String(localized: "Click a month to open it.")
    #else
    static let tapPastDay = String(localized: "Tap a past day to add or change a log.")
    static let tapHabitOrDay = String(localized: "Tap a habit to open it. Tap a day to add or change a log.")
    static let tapHabitMonth = String(localized: "Tap a habit to open its month.")
    static let tapMonth = String(localized: "Tap a month to open it.")
    #endif
}

extension View {
    /// The Undo line above the tab bar, in the tab where the action was made. It covers nothing and
    /// stays until the next action.
    func undoLineInset(_ tab: AppTab) -> some View {
        modifier(UndoLineInset(tab: tab))
    }
}

private struct UndoLineInset: ViewModifier {
    let tab: AppTab
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) {
            if let line = model.undoLine, line.tab == tab {
                UndoLineView(line: line)
            }
        }
    }
}

/// Global pauses, which have no habit. Milestone 3 adds the controls; imported pauses already count.
struct SharedPausesKey: EnvironmentKey {
    static let defaultValue: [Pause] = []
}

extension EnvironmentValues {
    var sharedPauses: [Pause] {
        get { self[SharedPausesKey.self] }
        set { self[SharedPausesKey.self] = newValue }
    }
}

/// Week, Month and Year as a segmented control, or one row that opens a list at accessibility sizes,
/// where a segmented control keeps small text.
struct PeriodPicker: View {
    @Binding var kind: PeriodKind
    let kinds: [PeriodKind]
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            Picker(selection: $kind) {
                ForEach(kinds, id: \.self) { Text($0.name).tag($0) }
            } label: {
                Text("View")
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
        } else {
            Picker("View", selection: $kind) {
                ForEach(kinds, id: \.self) { Text($0.name).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}
