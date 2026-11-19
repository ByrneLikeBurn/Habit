import Foundation

extension Habit {
    public var kind: HabitKind {
        get { HabitKind(rawValue: kindRaw) ?? .binary }
        set { kindRaw = newValue.rawValue }
    }

    /// The current schedule. Change it only through `setRule`, which keeps the history in step.
    public var schedule: Weekdays { Weekdays(rawValue: scheduleMask) }

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
        scheduleMask = newSchedule.rawValue
        // A rule dated later, such as one an earlier edit today set for tomorrow, gives way to this one.
        rules.removeAll { $0.fromDay > day.rawValue }
        let current = rule(on: day)
        if current.target == resolvedTarget, current.scheduleMask == newSchedule.rawValue { return }
        rules.removeAll { $0.fromDay >= day.rawValue }
        rules.append(HabitRule(fromDay: day, target: resolvedTarget, schedule: newSchedule))
        rules.sort { $0.fromDay < $1.fromDay }
    }

    /// True when an edit to `schedule` would wait until tomorrow: today is logged, today has set days,
    /// and the edit sets no set days. Applied today, it would take today's log out of a run, so Longest run
    /// would fall. Any other edit, a target change included, applies from today.
    public func noSetDaysWaitsForTomorrow(_ schedule: Weekdays, today: DayKey) -> Bool {
        schedule.isEmpty && total(on: today) > 0 && !rule(on: today).schedule.isEmpty
    }

    /// The rule Edit habit opens on: one that starts tomorrow, if an edit is waiting, otherwise today's.
    public func ruleForEditing(today: DayKey) -> HabitRule {
        let tomorrow = today.adding(days: 1)
        return rules.first { $0.fromDay == tomorrow.rawValue } ?? rule(on: today)
    }

    /// The form's Save. The target applies from today. The schedule applies from today, or from tomorrow
    /// when `noSetDaysWaitsForTomorrow` holds. Returns the day the schedule takes effect.
    @discardableResult
    public func applyEdit(target newTarget: Int?, schedule newSchedule: Weekdays, today: DayKey) -> DayKey {
        guard noSetDaysWaitsForTomorrow(newSchedule, today: today) else {
            setRule(target: newTarget, schedule: newSchedule, from: today)
            return today
        }
        let tomorrow = today.adding(days: 1)
        setRule(target: newTarget, schedule: rule(on: today).schedule, from: today)
        setRule(target: newTarget, schedule: newSchedule, from: tomorrow)
        return tomorrow
    }

    /// The sum of every delta logged for `day`. May be negative after edits on two devices.
    public func rawTotal(on day: DayKey) -> Int {
        (events ?? []).reduce(0) { $1.dayKey == day.rawValue ? $0.addingSaturating($1.delta) : $0 }
    }

    /// The total shown to the user. A total below 0 is shown as 0.
    public func total(on day: DayKey) -> Int {
        max(0, rawTotal(on: day))
    }

    public func isScheduled(on day: DayKey) -> Bool {
        rule(on: day).schedule.contains(day)
    }

    /// No set days on `day`: the rule for that day has no weekday on. Read from the rule, not the
    /// current mask, so a change dated later does not move today's row early.
    public func hasNoSetDays(on day: DayKey) -> Bool {
        rule(on: day).schedule.isEmpty
    }

    public func isPaused(on day: DayKey, sharedPauses: [Pause] = []) -> Bool {
        (pauses ?? []).contains { $0.covers(day) } || sharedPauses.contains { $0.covers(day) }
    }

    /// The state of one day, drawn as a mark.
    public func state(on day: DayKey, today: DayKey, sharedPauses: [Pause] = [], showDaysNotLogged: Bool = false) -> DayState {
        state(on: day, today: today, total: total(on: day), sharedPauses: sharedPauses, showDaysNotLogged: showDaysNotLogged)
    }

    /// The state of one day when its total is already known, so the events are not scanned again.
    public func state(on day: DayKey, today: DayKey, total: Int, sharedPauses: [Pause] = [], showDaysNotLogged: Bool = false) -> DayState {
        // Before the habit began, a day with no log draws nothing: no dot, dash or outline.
        if total <= 0, let start = rules.first?.fromDay, day.rawValue < start { return .blank }
        let rule = rule(on: day)
        return DayState.resolve(DayInput(
            total: max(0, total),
            kind: kind,
            target: rule.target,
            scheduled: rule.schedule.contains(day),
            paused: isPaused(on: day, sharedPauses: sharedPauses),
            relation: day < today ? .past : (day == today ? .today : .future),
            noSetDays: rule.schedule.isEmpty
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
