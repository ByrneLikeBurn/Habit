import Foundation

/// What Habit detail shows under its grid. All time, so the same numbers mean the same thing in
/// week, month and year. There is never a rate, a percentage or "of N days".
public struct HabitStats: Sendable, Equatable {
    /// The earlier of the day the habit was added and its first log.
    public var since: DayKey
    /// Days with any log.
    public var daysLogged: Int
    /// The sum of every day's shown total, in the user's unit. Only shown for a counted habit.
    public var unitTotal: Int
    /// Days on which the target was met.
    public var daysDone: Int
    public var run: RunState
    public var longestRun: Int

    /// The current run, said without a zero.
    public enum RunState: Sendable, Equatable {
        case days(Int)
        /// No run is active after a gap.
        case betweenRuns
        /// Nothing has been logged yet.
        case noRunYet
    }
}

extension Habit {
    /// Raw totals per day key, from one pass over the events.
    public func dayTotals() -> [Int: Int] {
        var totals: [Int: Int] = [:]
        for event in events ?? [] {
            totals[event.dayKey] = (totals[event.dayKey] ?? 0).addingSaturating(event.delta)
        }
        return totals
    }

    /// The first day the habit has: the day it was added, or an earlier log.
    public func firstDay(totals: [Int: Int]? = nil) -> DayKey {
        let added = rules.map(\.fromDay).min()
        let logged = (totals ?? dayTotals()).filter { $0.value > 0 }.keys.min()
        return DayKey(rawValue: [added, logged].compactMap { $0 }.min() ?? 0)
    }

    public func stats(today: DayKey, sharedPauses: [Pause] = []) -> HabitStats {
        let totals = dayTotals()
        let summary = runSummary(today: today, sharedPauses: sharedPauses)
        let unitTotal = totals.values.reduce(0) { $0.addingSaturating(max(0, $1)) }
        let run: HabitStats.RunState = summary.current > 0 ? .days(summary.current) : (summary.daysLogged > 0 ? .betweenRuns : .noRunYet)
        let since = firstDay(totals: totals)
        return HabitStats(
            since: since.rawValue == 0 ? today : since,
            daysLogged: summary.daysLogged,
            unitTotal: unitTotal,
            daysDone: summary.daysDone,
            run: run,
            longestRun: summary.longest
        )
    }

    /// The state of every day in `days`, from totals read once.
    public func states(for days: [DayKey], today: DayKey, totals: [Int: Int], sharedPauses: [Pause] = [], showDaysNotLogged: Bool = false) -> [DayState] {
        days.map { state(on: $0, today: today, total: totals[$0.rawValue] ?? 0, sharedPauses: sharedPauses, showDaysNotLogged: showDaysNotLogged) }
    }
}
