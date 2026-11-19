import Foundation
import SwiftData

// Pausing, milestone 3. Rules from docs/spec.md, "Milestone 3 screens".
// - "Pause everything" and "Pause for dates" are each one Pause with no habit. "Pause this habit" has one.
// - A day is paused if any pause covers it. A habit added during a pause is paused too.
// - One ending rule: ending a pause sets its last day to today, so today stays paused and the habit
//   starts again tomorrow. A pause whose first day is today is removed whole, so a slip leaves no trace.
// Pauses are not logs. They are written here, never through LogWriter.

extension Pause {
    public var start: DayKey { DayKey(rawValue: startDay) }
    public var end: DayKey? { endDay.map(DayKey.init(rawValue:)) }
    /// "Pause everything": open-ended until turned off.
    public var isEverything: Bool { habit == nil && reason == .gentle }
    /// "Pause for dates": a first and last day, every habit.
    public var isDates: Bool { habit == nil && reason != .gentle }
}

/// What Today says about pausing, from the pauses with no habit. "Pause everything" outranks dates.
public enum SharedPauseStatus: Equatable, Sendable {
    case none
    /// "Everything is paused." The button reads "Undo pause" when the pause began today, else "Resume tomorrow".
    case everything(startedToday: Bool)
    /// "Paused until 27 November." A dated pause that covers today and ends after it.
    case until(DayKey, startedToday: Bool)
    /// "Resumes tomorrow." Today is the last paused day. `canKeep` is true for "Pause everything",
    /// whose "Keep paused" opens it again.
    case resumesTomorrow(canKeep: Bool)

    public static func of(_ pauses: [Pause], today: DayKey) -> SharedPauseStatus {
        let covering = pauses.filter { $0.habit == nil && $0.covers(today) }
        if let everything = covering.filter(\.isEverything).max(by: { ($0.endDay ?? .max) < ($1.endDay ?? .max) }) {
            if everything.endDay == nil { return .everything(startedToday: everything.startDay == today.rawValue) }
            // Ended today and a dated pause goes on: the dates say more.
            if let dates = Self.latestEnd(of: covering.filter(\.isDates)), dates > today {
                return .until(dates, startedToday: false)
            }
            return .resumesTomorrow(canKeep: true)
        }
        let dated = covering.filter(\.isDates)
        guard let end = latestEnd(of: dated) else { return .none }
        if end == today { return .resumesTomorrow(canKeep: false) }
        let startedToday = dated.allSatisfy { $0.startDay == today.rawValue }
        return .until(end, startedToday: startedToday)
    }

    /// Overlapping pauses are treated as one: the latest last day among those covering today.
    private static func latestEnd(of pauses: [Pause]) -> DayKey? {
        guard !pauses.isEmpty else { return nil }
        return pauses.compactMap(\.end).max()
    }

    public var isPaused: Bool { self != .none }
}

/// One habit's own pause, as Edit and the row menu show it.
public enum HabitPauseStatus: Equatable, Sendable {
    case none
    /// Paused since a day, open-ended. `startedToday` gives "Undo pause" in place of "Resume tomorrow".
    case paused(since: DayKey, startedToday: Bool)
    /// Today is the last paused day. "Keep paused" opens it again.
    case resumesTomorrow
}

extension Habit {
    /// This habit's own pause on `today`. Pauses with no habit are read through `SharedPauseStatus`.
    public func ownPauseStatus(today: DayKey) -> HabitPauseStatus {
        let covering = (pauses ?? []).filter { $0.covers(today) }
        if let open = covering.filter({ $0.endDay == nil }).min(by: { $0.startDay < $1.startDay }) {
            return .paused(since: open.start, startedToday: open.startDay == today.rawValue)
        }
        return covering.isEmpty ? .none : .resumesTomorrow
    }
}

/// Every pause write. Each returns what it did, so the caller can say it and offer Undo.
@MainActor
public enum PauseWriter {
    /// "Pause everything". If an everything pause ended today, it opens again instead, as "Keep paused" does.
    @discardableResult
    public static func pauseEverything(today: DayKey, in context: ModelContext) throws -> Pause {
        if let ending = try sharedPauses(in: context).first(where: { $0.isEverything && $0.endDay == today.rawValue }) {
            ending.endDay = nil
            try context.save()
            return ending
        }
        let pause = Pause(habit: nil, start: today, end: nil, reason: .gentle)
        context.insert(pause)
        try context.save()
        return pause
    }

    /// "Pause this habit". If its own pause ended today, it opens again instead.
    @discardableResult
    public static func pause(_ habit: Habit, today: DayKey, in context: ModelContext) throws -> Pause {
        if let ending = (habit.pauses ?? []).first(where: { $0.endDay == today.rawValue }) {
            ending.endDay = nil
            try context.save()
            return ending
        }
        let pause = Pause(habit: habit, start: today, end: nil, reason: .manual)
        context.insert(pause)
        habit.pauses = (habit.pauses ?? []) + [pause]
        try context.save()
        return pause
    }

    /// The one ending rule. A pause that began today, or has not begun, is removed whole.
    /// Otherwise its last day becomes today, so today stays paused. Returns what happened.
    @discardableResult
    public static func end(_ pause: Pause, today: DayKey, in context: ModelContext) throws -> Ending {
        if pause.startDay >= today.rawValue {
            context.delete(pause)
            try context.save()
            return .removed
        }
        let previous = pause.end
        pause.endDay = today.rawValue
        try context.save()
        return .endsToday(previousEnd: previous)
    }

    public enum Ending: Equatable, Sendable {
        case removed
        /// The last day is now today. `previousEnd` is what it was, for "Keep paused".
        case endsToday(previousEnd: DayKey?)
    }

    /// "Keep paused": the last day goes back to what it was before "Resume tomorrow".
    public static func keep(_ pause: Pause, previousEnd: DayKey?, in context: ModelContext) throws {
        pause.endDay = previousEnd?.rawValue
        try context.save()
    }

    /// "Resume tomorrow" or "Undo pause" on Today. While "Pause everything" is on, only it ends, and
    /// dated pauses keep their dates. Otherwise every dated pause covering today ends.
    public static func endShared(today: DayKey, in context: ModelContext) throws -> [(Pause?, Ending)] {
        var results: [(Pause?, Ending)] = []
        let covering = try sharedPauses(in: context).filter { $0.covers(today) && $0.endDay != today.rawValue }
        let everything = covering.filter { $0.isEverything && $0.endDay == nil }
        for pause in everything.isEmpty ? covering : everything {
            let ending = try end(pause, today: today, in: context)
            results.append((ending == .removed ? nil : pause, ending))
        }
        return results
    }

    /// "Pause for dates". Dates can be in the past. The last day may not come before the first.
    @discardableResult
    public static func addDates(first: DayKey, last: DayKey, in context: ModelContext) throws -> Pause {
        precondition(first <= last)
        let pause = Pause(habit: nil, start: first, end: last, reason: .vacation)
        context.insert(pause)
        try context.save()
        return pause
    }

    public static func change(_ pause: Pause, first: DayKey, last: DayKey?, in context: ModelContext) throws {
        if let last { precondition(first <= last) }
        pause.startDay = first.rawValue
        pause.endDay = last?.rawValue
        try context.save()
    }

    /// Undo of Remove: the same pause, written back.
    @discardableResult
    public static func restore(habit: Habit?, start: DayKey, end: DayKey?, reason: PauseReason, in context: ModelContext) throws -> Pause {
        let pause = Pause(habit: habit, start: start, end: end, reason: reason)
        context.insert(pause)
        if let habit { habit.pauses = (habit.pauses ?? []) + [pause] }
        try context.save()
        return pause
    }

    public static func remove(_ pause: Pause, in context: ModelContext) throws {
        context.delete(pause)
        try context.save()
    }

    /// Bring back pauses the days a habit was archived: from the day it was archived through yesterday.
    /// If the archive day holds a log, the pause starts the day after, so a done day stays done.
    /// nil when there is nothing to pause.
    @MainActor
    public static func archivedSpan(of habit: Habit, archivedOn: DayKey, today: DayKey) -> ClosedRange<DayKey>? {
        let first = habit.total(on: archivedOn) > 0 ? archivedOn.adding(days: 1) : archivedOn
        let last = today.adding(days: -1)
        return first <= last ? first...last : nil
    }

    @discardableResult
    public static func pauseArchivedSpan(_ habit: Habit, span: ClosedRange<DayKey>, in context: ModelContext) throws -> Pause {
        let pause = Pause(habit: habit, start: span.lowerBound, end: span.upperBound, reason: .manual)
        context.insert(pause)
        habit.pauses = (habit.pauses ?? []) + [pause]
        try context.save()
        return pause
    }

    public static func sharedPauses(in context: ModelContext) throws -> [Pause] {
        try context.fetch(FetchDescriptor<Pause>(predicate: #Predicate { $0.habit == nil }))
    }
}

/// What a dated pause would change, for the line in the form.
public struct PauseImpact: Equatable, Sendable {
    /// Logged days that will draw as logged while paused.
    public var logsGainPause: Int
    /// Logged days that will no longer be paused, and draw as normal marks again.
    public var logsLosePause: Int
    /// Calendar days that gain a pause, today and later included. Days another pause covers do not count.
    public var daysGainPause: Int
    public var daysLosePause: Int

    public static let none = PauseImpact(logsGainPause: 0, logsLosePause: 0, daysGainPause: 0, daysLosePause: 0)

    /// Compares `old` (the saved dates, nil for a new pause) with `new` (nil for Remove). Logged days count
    /// up to today: nothing is logged after it yet. Days other pauses already cover do not change.
    @MainActor
    public static func of(old: ClosedRange<DayKey>?, new: ClosedRange<DayKey>?, habits: [Habit], otherShared: [Pause], today: DayKey) -> PauseImpact {
        var result = PauseImpact.none
        guard let span = [old, new].compactMap({ $0 }).reduce(nil as ClosedRange<DayKey>?, { acc, r in
            acc.map { min($0.lowerBound, r.lowerBound)...max($0.upperBound, r.upperBound) } ?? r
        }) else { return result }
        func inRange(_ range: ClosedRange<DayKey>?, _ day: DayKey) -> Bool { range?.contains(day) ?? false }
        func coveredElsewhere(_ day: DayKey) -> Bool { otherShared.contains { $0.covers(day) } }
        var calendarDay = span.lowerBound
        let lastCalendarDay = span.upperBound
        while calendarDay <= lastCalendarDay {
            defer { calendarDay = calendarDay.adding(days: 1) }
            let was = inRange(old, calendarDay), will = inRange(new, calendarDay)
            guard was != will, !coveredElsewhere(calendarDay) else { continue }
            if will { result.daysGainPause += 1 } else { result.daysLosePause += 1 }
        }
        let lowest = span.lowerBound
        let highest = min(span.upperBound, today)
        guard lowest <= highest else { return result }
        for habit in habits where habit.isActive {
            var day = lowest
            while day <= highest {
                defer { day = day.adding(days: 1) }
                let was = inRange(old, day), will = inRange(new, day)
                guard was != will, !habit.isPaused(on: day, sharedPauses: otherShared) else { continue }
                guard habit.total(on: day) > 0 else { continue }
                if will { result.logsGainPause += 1 } else { result.logsLosePause += 1 }
            }
        }
        return result
    }
}
