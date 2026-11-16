import SwiftUI
import SwiftData
import HabitKit

/// A short line with Undo, shown after a take-back or an archive.
struct UndoLine: Identifiable {
    let id = UUID()
    let message: String
    /// nil for a line that only informs, such as a failed save.
    let undo: (@MainActor () -> Void)?

    init(message: String, undo: (@MainActor () -> Void)? = nil) {
        self.message = message
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

/// Habit detail, opened on one period around one anchor day.
struct DetailRoute: Hashable {
    let habitID: UUID
    var kind: PeriodKind
    var anchor: DayKey
}

enum AppTab: Hashable { case today, history, you }

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
    var tab: AppTab = .today
    var todayPath: [DetailRoute] = []
    var historyPath: [DetailRoute] = []
    var showExport = false
    var choosingImportFile = false
    var importStage: ImportStage?
    var undoLine: UndoLine?
    var isReordering = false
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
            let message: String?
            if logDay != clock.today {
                let date = clock.date(for: logDay).formatted(Date.FormatStyle(timeZone: clock.calendar.timeZone).day().month(.wide).locale(clock.calendar.locale ?? .autoupdatingCurrent))
                message = switch habit.kind {
                case .binary: delta < 0 ? String(localized: "Cleared \(date)") : String(localized: "Logged \(date)")
                case .counted: "\(date): " + CountText.line(total: newTotal, target: habit.rule(on: logDay).target, unit: habit.unit)
                }
            } else {
                message = switch habit.kind {
                case .binary: delta < 0 ? String(localized: "\(habit.name) cleared") : nil
                case .counted: "\(habit.name): " + CountText.line(total: newTotal, target: habit.rule(on: logDay).target, unit: habit.unit)
                }
            }
            if let message, let inverse = outcome.inverse {
                show(UndoLine(message: message) { [weak self] in
                    self?.log(inverse, habit: habit, day: logDay, context: context, clock: clock, undoManager: undoManager)
                })
            } else {
                undoLine = nil
            }
        }
    }

    func archive(_ habit: Habit, context: ModelContext, clock: HabitClock) {
        habit.archivedAt = clock.now()
        try? context.save()
        show(UndoLine(message: String(localized: "\(habit.name) archived")) {
            habit.archivedAt = nil
            try? context.save()
        })
    }

    func bringBack(_ habit: Habit, context: ModelContext, all: [Habit]) {
        habit.archivedAt = nil
        habit.sortIndex = Ordering.nextIndex(all)
        try? context.save()
    }

    func show(_ line: UndoLine) {
        undoLine = line
        let spoken = line.undo == nil ? line.message : String(localized: "\(line.message). Undo available")
        AccessibilityNotification.Announcement(spoken).post()
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
