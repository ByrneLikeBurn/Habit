import Foundation

extension Habit {
    public var kind: HabitKind {
        get { HabitKind(rawValue: kindRaw) ?? .binary }
        set { kindRaw = newValue.rawValue }
    }

    public var schedule: Weekdays {
        get { Weekdays(rawValue: scheduleMask) }
        set { scheduleMask = newValue.rawValue }
    }

    public var isArchived: Bool { archivedAt != nil }
    public var isActive: Bool { archivedAt == nil && deletedAt == nil }
    public var hasLogs: Bool { !(events ?? []).isEmpty }

    /// The target and schedule that applied on `day`.
    /// A day before the first rule uses the first rule.
    public func rule(on day: DayKey) -> HabitRule {
        let sorted = rules.sorted { $0.fromDay < $1.fromDay }
        if let last = sorted.last(where: { $0.fromDay <= day.rawValue }) { return last }
        if let first = sorted.first { return first }
        return HabitRule(fromDay: day, target: target, schedule: schedule)
    }

    /// Sets the target and schedule from `day` onward. Earlier days keep their rule.
    public func setRule(target newTarget: Int?, schedule newSchedule: Weekdays, from day: DayKey) {
        let resolvedTarget = kind == .binary ? 1 : newTarget
        target = resolvedTarget
        schedule = newSchedule
        let current = rule(on: day)
        if current.target == resolvedTarget, current.scheduleMask == newSchedule.rawValue { return }
        rules.removeAll { $0.fromDay >= day.rawValue }
        rules.append(HabitRule(fromDay: day, target: resolvedTarget, schedule: newSchedule))
        rules.sort { $0.fromDay < $1.fromDay }
    }

    /// The sum of every delta logged for `day`. May be negative after edits on two devices.
    public func rawTotal(on day: DayKey) -> Int {
        (events ?? []).reduce(0) { $1.dayKey == day.rawValue ? $0 + $1.delta : $0 }
    }

    /// The total shown to the user. A total below 0 is shown as 0.
    public func total(on day: DayKey) -> Int {
        max(0, rawTotal(on: day))
    }

    public func isScheduled(on day: DayKey) -> Bool {
        rule(on: day).schedule.contains(day)
    }

    public func isPaused(on day: DayKey, sharedPauses: [Pause] = []) -> Bool {
        ((pauses ?? []) + sharedPauses).contains { $0.covers(day) }
    }

    /// The state of one day, drawn as a mark.
    public func state(on day: DayKey, today: DayKey, sharedPauses: [Pause] = [], showDaysNotLogged: Bool = false) -> DayState {
        let rule = rule(on: day)
        return DayState.resolve(DayInput(
            total: total(on: day),
            kind: kind,
            target: rule.target,
            scheduled: rule.schedule.contains(day),
            paused: isPaused(on: day, sharedPauses: sharedPauses),
            relation: day < today ? .past : (day == today ? .today : .future)
        ), showDaysNotLogged: showDaysNotLogged)
    }
}

extension Pause {
    public var reason: PauseReason { PauseReason(rawValue: reasonRaw) ?? .manual }

    public func covers(_ day: DayKey) -> Bool {
        day.rawValue >= startDay && (endDay.map { day.rawValue <= $0 } ?? true)
    }
}

extension LogEvent {
    public var source: LogSource { LogSource(rawValue: sourceRaw) ?? .manual }
    public var day: DayKey { DayKey(rawValue: dayKey) }
}
