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
    /// Nothing. Off schedule, or no log.
    case blank
    /// Faint dashed outline. A scheduled future day.
    case toCome
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

    public init(total: Int, kind: HabitKind, target: Int?, scheduled: Bool, paused: Bool, relation: DayRelation) {
        self.total = total
        self.kind = kind
        self.target = target
        self.scheduled = scheduled
        self.paused = paused
        self.relation = relation
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
            if !input.scheduled { return .loggedOffSchedule }
            return input.targetMet ? .done : .partDone
        }
        if input.paused { return .paused }
        guard input.scheduled else { return .blank }
        switch input.relation {
        case .future: return .toCome
        case .today: return .blank
        case .past: return showDaysNotLogged ? .notLogged : .blank
        }
    }
}
