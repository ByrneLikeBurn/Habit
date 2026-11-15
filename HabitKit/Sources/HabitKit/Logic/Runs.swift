import Foundation

/// Runs and day counts for one habit.
///
/// Invariant 3: pausing only ever helps. A paused day with no log never breaks a run and
/// never extends it. A paused day with a log extends it.
/// Something is better than nothing: any logged day extends a run, a part-done day included.
public struct RunSummary: Sendable, Equatable {
    public var current: Int
    public var longest: Int
    /// Days on which the target was met.
    public var daysDone: Int
    /// Days with any log.
    public var daysLogged: Int

    public init(current: Int, longest: Int, daysDone: Int, daysLogged: Int) {
        self.current = current
        self.longest = longest
        self.daysDone = daysDone
        self.daysLogged = daysLogged
    }
}

public enum Runs {
    /// What one day does to a run.
    public enum Effect: Sendable, Equatable {
        case extend
        case neutral
        case `break`
    }

    public static func effect(of input: DayInput) -> Effect {
        if input.total > 0 { return .extend }
        if input.paused || !input.scheduled { return .neutral }
        // Today is not over, so an empty today never breaks a run.
        if input.relation != .past { return .neutral }
        return .break
    }

    /// `days` runs oldest first and ends with today.
    public static func summarise(_ days: [DayInput]) -> RunSummary {
        var current = 0
        var longest = 0
        var done = 0
        var logged = 0
        for day in days {
            if day.total > 0 { logged += 1 }
            if day.targetMet { done += 1 }
            switch effect(of: day) {
            case .extend:
                current += 1
                longest = max(longest, current)
            case .neutral:
                break
            case .break:
                current = 0
            }
        }
        return RunSummary(current: current, longest: longest, daysDone: done, daysLogged: logged)
    }
}

extension Habit {
    /// Runs from the habit's first rule through `today`.
    public func runSummary(today: DayKey, sharedPauses: [Pause] = []) -> RunSummary {
        let first = DayKey(rawValue: rules.map(\.fromDay).min() ?? today.rawValue)
        let earliestLog = (events ?? []).map(\.dayKey).min().map(DayKey.init(rawValue:))
        let start = min(first, earliestLog ?? first)
        let count = max(0, start.days(to: today))
        let days = (0...count).map { offset -> DayInput in
            let day = start.adding(days: offset)
            let rule = rule(on: day)
            return DayInput(
                total: total(on: day),
                kind: kind,
                target: rule.target,
                scheduled: rule.schedule.contains(day),
                paused: isPaused(on: day, sharedPauses: sharedPauses),
                relation: day == today ? .today : .past
            )
        }
        return Runs.summarise(days)
    }
}
