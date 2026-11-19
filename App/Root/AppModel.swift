import SwiftUI
import SwiftData
import HabitKit

/// A short line with Undo, shown after a take-back or an archive.
struct UndoLine: Identifiable {
    let id = UUID()
    /// The whole line, as shown at standard sizes and read by VoiceOver.
    let message: String
    /// The habit's name and what happened to it, shown on their own at accessibility sizes.
    /// Only the name is ever cut, so the status always shows in full.
    let name: String?
    let status: String
    /// nil for a line that only informs, such as a failed save.
    let undo: (@MainActor () -> Void)?
    /// The tab the action was made in. The line shows there only, so Undo never acts out of sight.
    var tab: AppTab = .today
    /// The habit logged, so Today can scroll its row clear of the line when the line covers it.
    var habitID: UUID?

    init(message: String, name: String? = nil, status: String? = nil, undo: (@MainActor () -> Void)? = nil) {
        self.message = message
        self.name = name
        self.status = status ?? message
        self.undo = undo
    }
}

/// The count sheet's subject.
struct CountRequest: Identifiable {
    let habit: Habit
    let day: DayKey
    var id: UUID { habit.id }
}

/// The day sheet's subject: one habit on one day, from Habit detail or History.
struct DayRequest: Identifiable {
    let habit: Habit
    let day: DayKey
    var id: String { "\(habit.id)-\(day)" }
}

/// The Pause for dates form's subject: nil for a new pause.
struct PauseRequest: Identifiable {
    let pause: Pause?
    var id: String { pause.map { "\($0.id)" } ?? "new" }
}

/// Habit detail, opened on one period around one anchor day.
struct DetailRoute: Hashable {
    let habitID: UUID
    var kind: PeriodKind
    var anchor: DayKey
}

enum AppTab: Hashable { case today, history, you }

/// A View menu command for the period on screen: History, or Habit detail.
struct PeriodRequest: Equatable {
    enum Command: Equatable { case show(PeriodKind), move(Int), current }
    let command: Command
    let id = UUID()
}

/// Screen state shared by Today, the sheets and the menu commands.
@MainActor
@Observable
final class AppModel {
    var showNewHabit = false
    var editing: Habit?
    var counting: CountRequest?
    var daySheet: DayRequest?
    /// The past-day date picker in Habit detail, before the day sheet.
    var pickingPastDay: Habit?
    /// The day picked in "Add a past day", opened when the picker has closed.
    var pastDayChosen: DayRequest?
    var tab: AppTab = .today
    var todayPath: [DetailRoute] = []
    var historyPath: [DetailRoute] = []
    var showExport = false
    var choosingImportFile = false
    var importStage: ImportStage?
    var undoLine: UndoLine?
    var isReordering = false
    /// Today asks You to open Archived.
    var showArchived = false
    /// The Mac: the row selected on Today, which the Habit menu acts on.
    var selectedHabit: Habit?
    /// The habit Habit detail shows, while it is on screen.
    var detailHabit: Habit?
    /// "Pause for dates" from the Mac Habit menu.
    var pauseForm: PauseRequest?
    var periodRequest: PeriodRequest?
    /// The window's undo manager, so a log from the Mac Habit menu can be undone with Command-Z.
    @ObservationIgnored weak var undoManager: UndoManager?
    /// Pauses ended today from Today, for "Keep paused".
    var resumedShared: [ResumedPause] = []
    /// Changes on every log and take-back, for one haptic.
    var feedback = 0

    /// Logs through LogHabitIntent, the one write path, and registers undo.
    func log(_ action: LogAction, habit: Habit, day: DayKey? = nil, context: ModelContext, clock: HabitClock, undoManager: UndoManager?) {
        let intent = LogHabitIntent(habitID: habit.id, name: habit.name, action: action, source: .manual, day: day)
        let outcome: LogOutcome
        do {
            outcome = try intent.execute(in: context, clock: clock).outcome
        } catch {
            // Nothing was written. Say so, with no blame and no alarm.
            show(UndoLine(message: String(localized: "That log could not be saved. Try again.")))
            return
        }
        switch outcome {
        case .needsAmount:
            counting = CountRequest(habit: habit, day: day ?? clock.today)
        case .unchanged:
            break
        case .wrote(let delta, let newTotal):
            feedback += 1
            let logDay = day ?? clock.today
            if let inverse = outcome.inverse {
                undoManager?.registerUndo(withTarget: self) { model in
                    MainActor.assumeIsolated {
                        model.log(inverse, habit: habit, day: logDay, context: context, clock: clock, undoManager: undoManager)
                    }
                }
                undoManager?.setActionName(String(localized: "Log"))
            }
            // A take-back, every counted change and any change to a past day show a line with Undo.
            // A yes-or-no log for today shows its mark.
            let message: String?, status: String?
            let count = CountText.line(total: newTotal, target: habit.rule(on: logDay).target, unit: habit.unit)
            if logDay != clock.today {
                let date = clock.date(for: logDay).formatted(Date.FormatStyle(timeZone: clock.calendar.timeZone).day().month(.wide).locale(clock.calendar.locale ?? .autoupdatingCurrent))
                message = switch habit.kind {
                case .binary: delta < 0
                    ? String(localized: "\(habit.name) cleared, \(date)", comment: "Undo line. The habit's name, then the past day whose log was cleared, for example: Read cleared, 7 November.")
                    : String(localized: "\(habit.name) logged, \(date)", comment: "Undo line. The habit's name, then the past day it was logged for, for example: Read logged, 7 November.")
                case .counted: String(localized: "\(habit.name), \(date): \(count)", comment: "Undo line for a counted habit on a past day. The habit's name, the day, then the new total, for example: Drink water, 7 November: 4 of 8 glasses.")
                }
                // At large sizes the status sits under the name, so a short date saves a line.
                let shortDate = clock.date(for: logDay).formatted(Date.FormatStyle(timeZone: clock.calendar.timeZone).day().month(.abbreviated).locale(clock.calendar.locale ?? .autoupdatingCurrent))
                status = switch habit.kind {
                case .binary: delta < 0
                    ? String(localized: "Cleared, \(date)", comment: "Undo line status under the habit's name, at large text sizes. The past day whose log was cleared, for example: Cleared, 7 November.")
                    : String(localized: "Logged, \(date)", comment: "Undo line status under the habit's name, at large text sizes. The past day it was logged for, for example: Logged, 7 November.")
                case .counted: String(localized: "\(shortDate): \(count)", comment: "Undo line status under a counted habit's name, at large text sizes. The past day, short, then the new total, for example: 7 Nov: 4 of 8 glasses.")
                }
            } else {
                message = switch habit.kind {
                case .binary: delta < 0 ? String(localized: "\(habit.name) cleared", comment: "Undo line, a status, not a command. The placeholder is the habit's name, for example: Read cleared.") : nil
                case .counted: String(localized: "\(habit.name): \(count)", comment: "Undo line for a counted habit today. The habit's name, then the new total, for example: Drink water: 4 of 8 glasses.")
                }
                status = switch habit.kind {
                case .binary: String(localized: "Cleared", comment: "Undo line status under the habit's name, at large text sizes. A status, not a command.")
                case .counted: count
                }
            }
            if let message, let inverse = outcome.inverse {
                var line = UndoLine(message: message, name: habit.name, status: status) { [weak self] in
                    self?.log(inverse, habit: habit, day: logDay, context: context, clock: clock, undoManager: undoManager)
                }
                line.habitID = habit.id
                show(line)
            } else {
                undoLine = nil
            }
        }
    }

    func archive(_ habit: Habit, context: ModelContext, clock: HabitClock) {
        habit.archivedAt = clock.now()
        try? context.save()
        show(UndoLine(message: String(localized: "\(habit.name) archived", comment: "Undo line, a status, not a command. The placeholder is the habit's name, for example: Read archived."),
                      name: habit.name, status: String(localized: "Archived", comment: "Undo line status under the habit's name, at large text sizes. A status, not a command.")) {
            habit.archivedAt = nil
            try? context.save()
        })
    }

    /// Brings a habit back. With `pausing`, the days it was archived are paused first, so its run is kept.
    func bringBack(_ habit: Habit, context: ModelContext, all: [Habit], pausing span: ClosedRange<DayKey>? = nil) {
        let archivedAt = habit.archivedAt, sortIndex = habit.sortIndex
        var added: Pause?
        if let span { added = try? PauseWriter.pauseArchivedSpan(habit, span: span, in: context) }
        habit.archivedAt = nil
        habit.sortIndex = Ordering.nextIndex(all)
        try? context.save()
        show(UndoLine(message: String(localized: "\(habit.name) brought back", comment: "Undo line, a status, not a command. The placeholder is the habit's name, for example: Read brought back."),
                      name: habit.name, status: String(localized: "Brought back", comment: "Undo line status under the habit's name, at large text sizes. A status, not a command.")) {
            habit.archivedAt = archivedAt
            habit.sortIndex = sortIndex
            if let added { context.delete(added) }
            try? context.save()
        })
    }

    func show(_ line: UndoLine) {
        var line = line
        line.tab = tab
        undoLine = line
        let spoken = line.undo == nil ? line.message : String(localized: "\(line.message). Undo available")
        AccessibilityNotification.Announcement(spoken).post()
    }

    /// The current tab's pushed pages.
    var currentPath: [DetailRoute] {
        switch tab {
        case .today: todayPath
        case .history: historyPath
        case .you: []
        }
    }

    /// The Habit menu's subject: the habit detail shows, or else the row selected on Today.
    var menuHabit: Habit? {
        if !currentPath.isEmpty { return detailHabit }
        return tab == .today ? selectedHabit : nil
    }

    /// The periods the View menu offers for what is on screen. Empty when no period is shown.
    var periodKinds: [PeriodKind] {
        if !currentPath.isEmpty { return PeriodKind.allCases }
        return tab == .history ? [.week, .month] : []
    }

    func goBack() {
        switch tab {
        case .today: if !todayPath.isEmpty { todayPath.removeLast() }
        case .history: if !historyPath.isEmpty { historyPath.removeLast() }
        case .you: break
        }
    }

    /// Opens Habit detail in the tab that asked for it.
    func openDetail(_ habit: Habit, kind: PeriodKind = .month, anchor: DayKey, from tab: AppTab) {
        let route = DetailRoute(habitID: habit.id, kind: kind, anchor: anchor)
        switch tab {
        case .history: historyPath.append(route)
        default: todayPath.append(route)
        }
    }
}
