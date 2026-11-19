import SwiftUI
import SwiftData
import HabitKit

/// The line at the top of Today while a pause with no habit covers today. One sentence that says what is
/// paused, the helper, and one button. At accessibility sizes the helper is left out.
struct PauseLineView: View {
    @Environment(Settings.self) private var settings
    let status: SharedPauseStatus
    let clock: HabitClock
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.style) private var style
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if status.isPaused {
            VStack(alignment: .leading, spacing: 10) {
                sentence
                    .font(style.label(.subheadline))
                    .fixedSize(horizontal: false, vertical: true)
                    // At accessibility sizes the helper is not drawn. VoiceOver still reads it.
                    .accessibilityLabel(Text("\(title) \(helper)"))
                    .accessibilityAddTraits(.isHeader)
                // While the Undo line for a pause change shows, it is the one undo, so this button waits.
                if let button = buttonTitle, model.undoLine?.isPauseChange != true {
                    Button(button) { act() }
                        .buttonStyle(.outlinedCapsule)
                        .accessibilityIdentifier("pause-line-button")
                }
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .contain)
        }
    }

    private var title: String {
        switch status {
        case .none: ""
        case .everything: String(localized: "Everything is paused.")
        case .until(let day, _):
            String(localized: "Paused until \(PauseText.dayMonth(day, clock: clock)).", comment: "Today, while dated pauses cover today. The placeholder is the last paused day, for example: 27 November.")
        case .resumesTomorrow: String(localized: "Resumes tomorrow.")
        }
    }

    private var helper: String {
        switch status {
        case .resumesTomorrow: String(localized: "Today stays paused. You can still log.")
        default: PauseText.helper(showRuns: settings.showRuns)
        }
    }

    private var sentence: Text {
        let first = Text(title).fontWeight(.semibold).foregroundStyle(style.text)
        if typeSize.isAccessibilitySize { return first }
        return Text("\(first) \(Text(helper).foregroundStyle(style.secondary))", comment: "Today's pause line: a short sentence, then the helper. Keep the order.")
    }

    private var buttonTitle: LocalizedStringKey? {
        switch status {
        case .none: nil
        case .everything(let startedToday), .until(_, let startedToday): startedToday ? "Undo pause" : "Resume tomorrow"
        case .resumesTomorrow(let canKeep): canKeep || !model.resumedShared.isEmpty ? "Keep paused" : nil
        }
    }

    private func act() {
        switch status {
        case .none: break
        case .everything, .until: model.resumeShared(context: context, clock: clock)
        case .resumesTomorrow: model.keepShared(context: context, clock: clock, status: status)
        }
    }
}

/// The quiet button under Today's last row. It asks for no confirmation. Once pressed it goes, and the
/// pause line at the top offers "Undo pause".
struct PauseEverythingButton: View {
    let status: SharedPauseStatus
    let clock: HabitClock
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.style) private var style

    var body: some View {
        if let title {
            Button {
                if status == .none {
                    model.pauseEverything(context: context, clock: clock)
                } else {
                    model.resumeShared(context: context, clock: clock)
                }
            } label: {
                Label {
                    Text(title).underline()
                } icon: {
                    Image(systemName: "pause.circle").accessibilityHidden(true)
                }
                .font(style.label(.subheadline))
                .foregroundStyle(style.text)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("pause-everything")
        }
    }

    private var title: LocalizedStringKey? {
        switch status {
        case .none: "Pause everything"
        // While paused, the pause line at the top holds the one button, so it is never shown twice.
        default: nil
        }
    }
}

/// Dates in pause wording, in the user's calendar and locale.
enum PauseText {
    /// What a pause does, said the same way everywhere. A dash on a box can read as minus, so the line names it.
    /// Runs are named only when they are shown.
    static func helper(showRuns: Bool) -> String {
        showRuns
            ? String(localized: "A dash marks a paused day. It leaves your runs as they are. You can still log.")
            : String(localized: "A dash marks a paused day. You can still log.")
    }

    static func dayMonth(_ day: DayKey, clock: HabitClock) -> String {
        clock.date(for: day).formatted(format(clock).day().month(.wide))
    }

    /// "Tue 10 Nov", for "Paused since".
    static func short(_ day: DayKey, clock: HabitClock) -> String {
        clock.date(for: day).formatted(format(clock).weekday(.abbreviated).day().month(.abbreviated))
    }

    /// "20 to 27 November", or "Since 3 October" for a pause with no last day.
    static func range(_ pause: Pause, clock: HabitClock) -> String {
        guard let end = pause.end else {
            return String(localized: "Since \(dayMonth(pause.start, clock: clock))", comment: "A pause with no last day, for example: Since 3 October.")
        }
        let first = clock.date(for: pause.start), last = clock.date(for: end)
        let style = Date.IntervalFormatStyle(locale: clock.calendar.locale ?? .autoupdatingCurrent,
                                             calendar: clock.calendar, timeZone: clock.calendar.timeZone)
        // Same year as today: the year is left out.
        let thisYear = clock.date(for: clock.today)
        let sameYear = clock.calendar.isDate(first, equalTo: thisYear, toGranularity: .year) && clock.calendar.isDate(last, equalTo: thisYear, toGranularity: .year)
        let interval = first..<last.addingTimeInterval(1)
        return sameYear ? interval.formatted(style.day().month(.wide)) : interval.formatted(style.day().month(.wide).year())
    }

    private static func format(_ clock: HabitClock) -> Date.FormatStyle {
        Date.FormatStyle(locale: clock.calendar.locale ?? .autoupdatingCurrent, calendar: clock.calendar, timeZone: clock.calendar.timeZone)
    }
}
