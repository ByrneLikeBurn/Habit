import SwiftUI
import SwiftData
import HabitKit

/// A pause ended today by "Resume tomorrow", kept so "Keep paused" can put its last day back.
struct ResumedPause {
    let pause: Pause
    let previousEnd: DayKey?
}

/// Pausing from Today, You, Edit, the row menu and the Mac Habit menu. Every write goes through `PauseWriter`.
/// A failed save says so in the Undo line, with no blame.
extension AppModel {
    func pauseEverything(context: ModelContext, clock: HabitClock) {
        let done = perform(context) {
            try PauseWriter.pauseEverything(today: clock.today, in: context)
            resumedShared = []
        }
        if done { announce(String(localized: "Everything is paused.")) }
    }

    /// "Resume tomorrow" or "Undo pause" for the pauses with no habit that cover today.
    func resumeShared(context: ModelContext, clock: HabitClock) {
        let done = perform(context) {
            let endings = try PauseWriter.endShared(today: clock.today, in: context)
            resumedShared = endings.compactMap { pause, ending in
                guard let pause, case .endsToday(let previous) = ending else { return nil }
                return ResumedPause(pause: pause, previousEnd: previous)
            }
        }
        if done { announce(resumedShared.isEmpty ? String(localized: "Pause undone.") : String(localized: "Resumes tomorrow.")) }
    }

    /// The You switch turned off: ends "Pause everything" only. Dated pauses keep their dates.
    func resumeEverything(context: ModelContext, clock: HabitClock) {
        let today = clock.today
        perform(context) {
            for pause in try PauseWriter.sharedPauses(in: context) where pause.isEverything && pause.covers(today) && pause.endDay == nil {
                try PauseWriter.end(pause, today: today, in: context)
            }
            resumedShared = []
        }
    }

    /// "Keep paused" on Today: each pause ended today goes back as it was. "Pause everything" opens again.
    func keepShared(context: ModelContext, clock: HabitClock, status: SharedPauseStatus) {
        let done = perform(context) {
            if resumedShared.isEmpty, status == .resumesTomorrow(canKeep: true) {
                try PauseWriter.pauseEverything(today: clock.today, in: context)
            }
            for resumed in resumedShared { try PauseWriter.keep(resumed.pause, previousEnd: resumed.previousEnd, in: context) }
            resumedShared = []
        }
        if done { announce(String(localized: "Paused again.")) }
    }

    func pause(_ habit: Habit, context: ModelContext, clock: HabitClock) {
        if perform(context, { try PauseWriter.pause(habit, today: clock.today, in: context) }) {
            announce(String(localized: "\(habit.name) is paused.", comment: "Spoken after Pause this habit. The placeholder is the habit's name."))
        }
    }

    /// "Resume tomorrow" or "Undo pause" for one habit's own open pause.
    func resume(_ habit: Habit, context: ModelContext, clock: HabitClock) {
        let today = clock.today
        guard let open = (habit.pauses ?? []).first(where: { $0.covers(today) && $0.endDay == nil }) else { return }
        var ending: PauseWriter.Ending?
        if perform(context, { ending = try PauseWriter.end(open, today: today, in: context) }) {
            announce(ending == .removed ? String(localized: "Pause undone.") : String(localized: "Resumes tomorrow."))
        }
    }

    /// Removing a pause changes how its days draw, so the line offers Undo, which puts the same dates back.
    func removePause(_ pause: Pause, context: ModelContext) {
        let start = pause.start, end = pause.end, reason = pause.reason, habit = pause.habit
        var removed = false
        perform(context) { try PauseWriter.remove(pause, in: context); removed = true }
        guard removed else { return }
        show(UndoLine(message: String(localized: "Pause removed", comment: "Undo line, a status, not a command."), status: nil) { [weak self] in
            self?.perform(context) { try PauseWriter.restore(habit: habit, start: start, end: end, reason: reason, in: context) }
        })
    }

    /// Runs a pause write and says plainly if the save failed. Returns whether it was saved.
    @discardableResult
    func perform(_ context: ModelContext, _ write: () throws -> Void) -> Bool {
        do {
            try write()
            return true
        } catch {
            context.rollback()
            show(UndoLine(message: String(localized: "That change could not be saved. Try again.")))
            return false
        }
    }

    /// VoiceOver hears what a pause button did, since the button itself may go.
    func announce(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
    }
}
