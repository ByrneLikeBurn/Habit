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

/// Screen state shared by Today, the sheets and the menu commands.
@MainActor
@Observable
final class AppModel {
    var showNewHabit = false
    var editing: Habit?
    var counting: CountRequest?
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
        case .wrote(let delta, _):
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
            if habit.kind == .binary, delta < 0, let inverse = outcome.inverse {
                show(UndoLine(message: String(localized: "\(habit.name) taken back.")) { [weak self] in
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
        show(UndoLine(message: String(localized: "\(habit.name) archived.")) {
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
        AccessibilityNotification.Announcement(line.message).post()
    }
}
