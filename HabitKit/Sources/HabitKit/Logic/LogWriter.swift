import Foundation
import SwiftData

/// What a log request asks for.
public enum LogAction: Sendable, Equatable {
    /// The Today control. A yes-or-no habit toggles. A counted habit adds its tap amount.
    case tap
    /// Adds a typed amount.
    case add(Int)
    /// Takes away a typed amount, never more than the total.
    case takeAway(Int)
    /// Sets a yes-or-no day to done.
    case markDone
    /// Takes the day back to 0.
    case clear
}

public enum LogOutcome: Sendable, Equatable {
    /// One event was written.
    case wrote(delta: Int, newTotal: Int)
    /// A counted habit with no tap amount. The caller opens the count sheet.
    case needsAmount
    /// Nothing to do, for example taking away from 0.
    case unchanged(total: Int)

    /// The action that takes this outcome back, for undo.
    public var inverse: LogAction? {
        guard case .wrote(let delta, _) = self else { return nil }
        return delta > 0 ? .takeAway(delta) : .add(-delta)
    }
}

/// Turns a log request into one `LogEvent`.
///
/// Invariant 5: only `LogHabitIntent` calls this in the app. A source check enforces it.
public enum LogWriter {
    /// The delta an action would write, given the day's shown total. nil when nothing is written.
    public static func delta(for action: LogAction, kind: HabitKind, tapAmount: Int?, total: Int) -> Int? {
        let total = max(0, total)
        switch action {
        case .tap:
            switch kind {
            case .binary:
                // Taking a log back writes minus the current total.
                return total >= 1 ? -total : 1
            case .counted:
                guard let amount = tapAmount, amount > 0 else { return nil }
                return amount
            }
        case .add(let amount):
            return amount > 0 ? amount : nil
        case .takeAway(let amount):
            let clamped = min(amount, total)
            return clamped > 0 ? -clamped : nil
        case .markDone:
            return total >= 1 ? nil : 1
        case .clear:
            return total > 0 ? -total : nil
        }
    }

    @discardableResult
    public static func log(
        _ action: LogAction,
        habit: Habit,
        day: DayKey,
        source: LogSource,
        deviceID: String,
        now: Date,
        in context: ModelContext
    ) throws -> LogOutcome {
        let raw = habit.rawTotal(on: day)
        let shown = max(0, raw)
        if case .tap = action, habit.kind == .counted, (habit.tapAmount ?? 0) <= 0 {
            return .needsAmount
        }
        guard var delta = delta(for: action, kind: habit.kind, tapAmount: habit.tapAmount, total: shown) else {
            return .unchanged(total: shown)
        }
        // Two devices taking back the same log offline can leave a raw total below 0, shown as 0.
        // A yes-or-no log then lifts the day to exactly 1, so the tap is never swallowed.
        // A typed amount is always written as typed.
        if raw < 0, delta > 0, habit.kind == .binary { delta -= raw }
        let event = LogEvent(delta: delta, habit: habit, day: day, source: source, timestamp: now, deviceID: deviceID)
        context.insert(event)
        try context.save()
        return .wrote(delta: delta, newTotal: max(0, raw + delta))
    }
}
