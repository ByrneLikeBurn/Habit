import Foundation

/// What a day's mark shows. One drawing has one meaning.
public enum DayState: String, Sendable, Equatable, CaseIterable {
    /// Solid. The target was met, or any log on a habit with no target.
    case done
    /// Hatched. A counted habit has some logs and is under target.
    case partDone
    /// Centred dash. The day is paused and has no log.
    case paused
    /// Diamond. The day is paused and has a log.
    case loggedWhilePaused
    /// Diamond. The day is not scheduled and has a log.
    case loggedOffSchedule
    /// A small dot. A past day or today that the habit is not scheduled for, with no log.
    case offSchedule
    /// A small dot, drawn as `offSchedule`. Today for a habit with no set days, with no log.
    /// Never owed, and read as "No set days", not "Not scheduled".
    case noSetDays
    /// Nothing. A day with no log that is scheduled, or in the future. A future day shows its date alone.
    case blank
    /// Empty outline. A past scheduled day with no log, only when Show days not logged is on.
    case notLogged

    /// True when the day holds a log, so it extends a run.
    public var isLogged: Bool {
        switch self {
        case .done, .partDone, .loggedWhilePaused, .loggedOffSchedule: true
        default: false
        }
    }
}

public enum DayRelation: Sendable {
    case past, today, future
}

public struct DayInput: Sendable, Equatable {
    public var total: Int
    public var kind: HabitKind
    public var target: Int?
    public var scheduled: Bool
    public var paused: Bool
    public var relation: DayRelation
    /// The day's rule has no set days. Such a habit can be logged on any day and is never owed.
    public var noSetDays: Bool

    public init(total: Int, kind: HabitKind, target: Int?, scheduled: Bool, paused: Bool, relation: DayRelation, noSetDays: Bool = false) {
        self.total = total
        self.kind = kind
        self.target = target
        self.scheduled = scheduled
        self.paused = paused
        self.relation = relation
        self.noSetDays = noSetDays
    }

    /// The target was met. A yes-or-no habit is met at 1. A counted habit with no target is met by any log.
    public var targetMet: Bool {
        guard total > 0 else { return false }
        switch kind {
        case .binary: return total >= 1
        case .counted: return total >= (target ?? 1)
        }
    }
}

extension DayState {
    public static func resolve(_ input: DayInput, showDaysNotLogged: Bool = false) -> DayState {
        if input.total > 0 {
            // A log on a paused or off-schedule day is credited, whatever the count.
            if input.paused { return .loggedWhilePaused }
            // No set days: a log gets the same mark as on a set day.
            if input.noSetDays { return input.targetMet ? .done : .partDone }
            if !input.scheduled { return .loggedOffSchedule }
            return input.targetMet ? .done : .partDone
        }
        // Days to come draw nothing, paused or not, so an open pause never reads as a forecast.
        if input.relation == .future { return .blank }
        if input.paused { return .paused }
        // No set days: the dot today, so it is never shown as owed, and nothing on any other day,
        // whether or not Show days not logged is on.
        if input.noSetDays { return input.relation == .today ? .noSetDays : .blank }
        guard input.scheduled else { return input.relation == .future ? .blank : .offSchedule }
        switch input.relation {
        case .future, .today: return .blank
        case .past: return showDaysNotLogged ? .notLogged : .blank
        }
    }
}
