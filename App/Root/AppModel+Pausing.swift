import SwiftUI
import SwiftData
import HabitKit

/// A pause ended today by "Resume tomorrow", kept so "Keep paused" can put its last day back.
struct ResumedPause {
    let pause: Pause
    let previousEnd: DayKey?
}

/// A pause as it was, so Undo can write it back after it was removed.
struct PauseCopy {
    let habit: Habit?
    let start: DayKey
    let end: DayKey?
    let reason: PauseReason

    init(_ pause: Pause) {
        habit = pause.habit
        start = pause.start
        end = pause.end
        reason = pause.reason
    }

    func restore(in context: ModelContext) throws {
        try PauseWriter.restore(habit: habit, start: start, end: end, reason: reason, in: context)
    }
}

/// An undo that runs once, whether from the Undo line or from Command-Z.
@MainActor
private final class Once {
    private var action: (() -> Void)?
    init(_ action: @escaping () -> Void) { self.action = action }
    func run() { let a = action; action = nil; a?() }
}

/// Pausing from Today, You, Edit, the row menu and the Mac Habit menu. Every write goes through `PauseWriter`.
/// Every pause change shows a line with Undo, as logs do, and Command-Z undoes it. A failed save says so in
/// the line, with no blame.
extension AppModel {
    /// Shows the line and registers the same undo with the undo manager, so the line and Command-Z never both act.
    private func offerUndo(_ message: String, name: String? = nil, status: String? = nil, action: String,
                           context: ModelContext, undo: @escaping () throws -> Void) {
        let once = Once { [weak self] in self?.perform(context) { try undo() } }
        undoManager?.registerUndo(withTarget: self) { _ in MainActor.assumeIsolated { once.run() } }
        undoManager?.setActionName(action)
        show(UndoLine(message: message, name: name, status: status) { once.run() })
    }

    func pauseEverything(context: ModelContext, clock: HabitClock) {
        let today = clock.today
        var pause: Pause?
        let done = perform(context) {
            pause = try PauseWriter.pauseEverything(today: today, in: context)
            resumedShared = []
        }
        guard done, let pause else { return }
        // The line shows where the tap was, so a slip on the button is one tap from undone.
        offerUndo(String(localized: "Everything is paused."), action: String(localized: "Pause Everything"), context: context) {
            try PauseWriter.end(pause, today: today, in: context)
        }
    }

    /// "Resume tomorrow" or "Undo pause" for the pauses with no habit that cover today.
    func resumeShared(context: ModelContext, clock: HabitClock) {
        let today = clock.today
        let before = ((try? PauseWriter.sharedPauses(in: context)) ?? []).filter { $0.covers(today) }
        let copies = before.map { ($0.persistentModelID, PauseCopy($0)) }
        var removed: [PauseCopy] = []
        let done = perform(context) {
            let endings = try PauseWriter.endShared(today: today, in: context)
            resumedShared = endings.compactMap { pause, ending in
                guard let pause, case .endsToday(let previous) = ending else { return nil }
                return ResumedPause(pause: pause, previousEnd: previous)
            }
            let left = Set(try PauseWriter.sharedPauses(in: context).map(\.persistentModelID))
            removed = copies.filter { !left.contains($0.0) }.map(\.1)
        }
        if done { offerResumed(removed: removed, resumed: resumedShared, context: context) }
    }

    /// The line after a resume. Undo puts a removed pause back whole and an ended one's last day back,
    /// so a planned pause that begins today is never lost to one tap.
    private func offerResumed(removed: [PauseCopy], resumed: [ResumedPause], name: String? = nil, context: ModelContext) {
        let message = resumed.isEmpty ? String(localized: "Pause undone.") : String(localized: "Resumes tomorrow.")
        offerUndo(message, name: name, status: name == nil ? nil : message, action: String(localized: "Resume"), context: context) { [weak self] in
            for copy in removed { try copy.restore(in: context) }
            for item in resumed { try PauseWriter.keep(item.pause, previousEnd: item.previousEnd, in: context) }
            self?.resumedShared = []
        }
    }

    /// The You switch turned off: ends "Pause everything" only. Dated pauses keep their dates.
    func resumeEverything(context: ModelContext, clock: HabitClock) {
        let today = clock.today
        var removed: [PauseCopy] = []
        var resumed: [ResumedPause] = []
        let done = perform(context) {
            for pause in try PauseWriter.sharedPauses(in: context) where pause.isEverything && pause.covers(today) && pause.endDay == nil {
                let copy = PauseCopy(pause)
                switch try PauseWriter.end(pause, today: today, in: context) {
                case .removed: removed.append(copy)
                case .endsToday(let previous): resumed.append(ResumedPause(pause: pause, previousEnd: previous))
                }
            }
            resumedShared = resumed
        }
        if done && !(removed.isEmpty && resumed.isEmpty) { offerResumed(removed: removed, resumed: resumed, context: context) }
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
        let today = clock.today
        var pause: Pause?
        guard perform(context, { pause = try PauseWriter.pause(habit, today: today, in: context) }), let pause else { return }
        offerUndo(String(localized: "\(habit.name) is paused.", comment: "Undo line and VoiceOver after Pause this habit. The placeholder is the habit's name."),
                  name: habit.name, status: String(localized: "Paused"), action: String(localized: "Pause"), context: context) {
            try PauseWriter.end(pause, today: today, in: context)
        }
    }

    /// "Resume tomorrow" or "Undo pause" for one habit's own open pause.
    func resume(_ habit: Habit, context: ModelContext, clock: HabitClock) {
        let today = clock.today
        guard let open = (habit.pauses ?? []).first(where: { $0.covers(today) && $0.endDay == nil }) else { return }
        let copy = PauseCopy(open)
        var ending: PauseWriter.Ending?
        guard perform(context, { ending = try PauseWriter.end(open, today: today, in: context) }), let ending else { return }
        switch ending {
        case .removed: offerResumed(removed: [copy], resumed: [], name: habit.name, context: context)
        case .endsToday(let previous): offerResumed(removed: [], resumed: [ResumedPause(pause: open, previousEnd: previous)], name: habit.name, context: context)
        }
    }

    /// "Resume tomorrow" in the Pause for dates form: kept for "Keep paused" on Today, with Undo.
    func resumeDates(_ pause: Pause, context: ModelContext, clock: HabitClock) {
        let copy = PauseCopy(pause)
        var ending: PauseWriter.Ending?
        guard perform(context, { ending = try PauseWriter.end(pause, today: clock.today, in: context) }), let ending else { return }
        switch ending {
        case .removed: offerResumed(removed: [copy], resumed: [], context: context)
        case .endsToday(let previous):
            resumedShared = [ResumedPause(pause: pause, previousEnd: previous)]
            offerResumed(removed: [], resumed: resumedShared, context: context)
        }
    }

    /// New or changed dates. Changed dates can shorten a run, so Undo puts the old dates back.
    func saveDates(_ pause: Pause?, first: DayKey, last: DayKey?, context: ModelContext) {
        if let pause {
            let oldFirst = pause.start, oldLast = pause.end
            guard perform(context, { try PauseWriter.change(pause, first: first, last: last, in: context) }) else { return }
            offerUndo(String(localized: "Dates changed", comment: "Undo line, a status, not a command."), action: String(localized: "Change Dates"), context: context) {
                try PauseWriter.change(pause, first: oldFirst, last: oldLast, in: context)
            }
        } else if let last {
            var added: Pause?
            guard perform(context, { added = try PauseWriter.addDates(first: first, last: last, in: context) }), let added else { return }
            offerUndo(String(localized: "Dates paused", comment: "Undo line after a new Pause for dates, a status, not a command."), action: String(localized: "Pause for Dates"), context: context) {
                try PauseWriter.remove(added, in: context)
            }
        }
    }

    /// Removing a pause changes how its days draw, so Undo puts the same dates back.
    func removePause(_ pause: Pause, context: ModelContext) {
        let copy = PauseCopy(pause)
        guard perform(context, { try PauseWriter.remove(pause, in: context) }) else { return }
        offerUndo(String(localized: "Pause removed", comment: "Undo line, a status, not a command."), action: String(localized: "Remove Pause"), context: context) {
            try copy.restore(in: context)
        }
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
