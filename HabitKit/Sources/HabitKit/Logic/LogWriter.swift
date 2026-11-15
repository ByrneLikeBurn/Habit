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

extension LogAction {
    /// What a request from outside the app means: Shortcuts, Siri, NFC, the widget.
    ///
    /// A shortcut means "log", so running it twice never takes a yes-or-no log back.
    /// Take away with no amount takes away one tap.
    public static func external(amount: Int?, takeAway: Bool, kind: HabitKind, tapAmount: Int?) -> LogAction {
        switch (kind, takeAway) {
        case (.binary, false): return .markDone
        case (.binary, true): return .clear
        case (.counted, false): return amount.map(LogAction.add) ?? .tap
        case (.counted, true): return .takeAway(amount ?? max(tapAmount ?? 1, 1))
        }
    }
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
        let cap = CountText.maximumAmount
        switch action {
        case .tap:
            switch kind {
            case .binary:
                // Taking a log back writes minus the current total.
                return total >= 1 ? -total : 1
            case .counted:
                guard let amount = tapAmount, amount > 0 else { return nil }
                return min(amount, cap)
            }
        case .add(let amount):
            return amount > 0 ? min(amount, cap) : nil
        case .takeAway(let amount):
            let clamped = min(amount, total, cap)
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
        // Only this day's events are read, so a tap costs the same on day 1 and day 1,000.
        let raw = try rawTotal(of: habit, on: day, in: context)
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
        do {
            try context.save()
        } catch {
            // Never leave an unsaved event behind to be counted or saved later.
            context.delete(event)
            throw error
        }
        return .wrote(delta: delta, newTotal: max(0, raw.addingSaturating(delta)))
    }

    /// The raw total for one habit on one day, read with a day-filtered fetch.
    public static func rawTotal(of habit: Habit, on day: DayKey, in context: ModelContext) throws -> Int {
        try dayTotals(on: day, in: context)[habit.id] ?? 0
    }

    /// Raw totals for every habit on one day, keyed by habit id. One fetch for the whole of Today.
    public static func dayTotals(on day: DayKey, in context: ModelContext) throws -> [UUID: Int] {
        let key = day.rawValue
        let events = try context.fetch(FetchDescriptor<LogEvent>(predicate: #Predicate { $0.dayKey == key }))
        var totals: [UUID: Int] = [:]
        for event in events {
            guard let id = event.habit?.id else { continue }
            totals[id] = (totals[id] ?? 0).addingSaturating(event.delta)
        }
        return totals
    }
}

extension Int {
    /// Addition that stops at the limits instead of trapping.
    func addingSaturating(_ other: Int) -> Int {
        let (result, overflow) = addingReportingOverflow(other)
        guard overflow else { return result }
        return other > 0 ? .max : .min
    }
}
