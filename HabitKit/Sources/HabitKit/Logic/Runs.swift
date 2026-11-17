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
        if input.total > 0 {
            // Invariant 3: a paused day with a log extends a run, whatever the schedule.
            if input.paused { return .extend }
            // No set days: a run is measured against set days, so a log there neither extends nor breaks.
            // Logs months apart never read as a run. Its logs still count in days logged and days done.
            if input.noSetDays { return .neutral }
            return .extend
        }
        if input.paused || !input.scheduled || input.noSetDays { return .neutral }
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
        // A day after today that already holds a log (after travel, or a new day-start hour) still counts.
        let latestLog = (events ?? []).filter { $0.delta != 0 }.map(\.dayKey).max().map(DayKey.init(rawValue:))
        let end = max(today, latestLog ?? today)
        let count = max(0, start.days(to: end))
        var totals: [Int: Int] = [:]
        for event in events ?? [] { totals[event.dayKey] = (totals[event.dayKey] ?? 0).addingSaturating(event.delta) }
        let days = (0...count).map { offset -> DayInput in
            let day = start.adding(days: offset)
            let rule = rule(on: day)
            return DayInput(
                total: max(0, totals[day.rawValue] ?? 0),
                kind: kind,
                target: rule.target,
                scheduled: rule.schedule.contains(day),
                paused: isPaused(on: day, sharedPauses: sharedPauses),
                relation: day < today ? .past : .today,
                noSetDays: rule.schedule.isEmpty
            )
        }
        return Runs.summarise(days)
    }
}
