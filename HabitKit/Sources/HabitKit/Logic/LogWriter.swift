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

/// Every `LogEvent` is created here.
///
/// Invariant 5: a user log reaches `log` only through `LogHabitIntent`. Import reaches
/// `importEvents` only from the app's import file. A source check enforces both.
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

    /// The device value every imported log carries. The export file holds no device id.
    public static let importedDeviceID = "imported"

    public struct ImportResult: Sendable, Equatable {
        public var habitsAdded: Int
        public var logsAdded: Int
        public var pausesAdded: Int
        public var skipped: Int

        public init(habitsAdded: Int, logsAdded: Int, pausesAdded: Int, skipped: Int) {
            self.habitsAdded = habitsAdded
            self.logsAdded = logsAdded
            self.pausesAdded = pausesAdded
            self.skipped = skipped
        }
    }

    /// Writes a checked plan: all of it or none of it, with one save.
    ///
    /// A log keeps its id, day key, timestamp and source, and gets the device value "imported".
    /// No value is altered: `ImportPlan.make` refuses a whole file for one bad record.
    /// An existing habit keeps this device's details, archived state included.
    @MainActor
    @discardableResult
    public static func importEvents(_ plan: ImportPlan, in context: ModelContext) throws -> ImportResult {
        let existing = try context.fetch(FetchDescriptor<Habit>())
        var habits = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        // Into an empty store the file's order is kept as it is. Otherwise new habits follow the ones here.
        let live = existing.filter { $0.deletedAt == nil }
        let base = live.isEmpty ? nil : (live.map(\.sortIndex).max() ?? 0) + 1
        for (rank, r) in plan.newHabits.sorted(by: { $0.sortIndex < $1.sortIndex }).enumerated() {
            guard let kind = HabitKind(rawValue: r.kind), let first = r.rules.first else {
                context.rollback()
                throw ImportProblem.damaged
            }
            let habit = Habit(
                name: r.name, symbolName: r.symbol, kind: kind, target: r.target, unit: r.unit,
                schedule: Weekdays(rawValue: r.schedule), tapAmount: r.tapAmount,
                sortIndex: base.map { $0 + rank } ?? r.sortIndex,
                createdAt: r.created, firstDay: DayKey(rawValue: first.fromDay)
            )
            habit.id = r.id
            habit.target = r.target
            habit.tapAmount = r.tapAmount
            habit.archivedAt = r.archived
            habit.rules = r.rules.map { HabitRule(fromDay: DayKey(rawValue: $0.fromDay), target: $0.target, schedule: Weekdays(rawValue: $0.schedule)) }
            context.insert(habit)
            habits[r.id] = habit
        }
        for p in plan.newPauses {
            let pause = Pause(habit: p.habit.flatMap { habits[$0] }, start: DayKey(rawValue: p.start), end: p.end.map(DayKey.init(rawValue:)), reason: PauseReason(rawValue: p.reason) ?? .manual)
            pause.id = p.id
            context.insert(pause)
        }
        for log in plan.newLogs {
            guard let habit = habits[log.habit], let source = LogSource(rawValue: log.source) else {
                context.rollback()
                throw ImportProblem.damaged
            }
            let event = LogEvent(delta: log.delta, habit: habit, day: DayKey(rawValue: log.day), source: source, timestamp: log.time, deviceID: importedDeviceID)
            event.id = log.id
            context.insert(event)
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return ImportResult(habitsAdded: plan.newHabits.count, logsAdded: plan.newLogs.count, pausesAdded: plan.newPauses.count, skipped: plan.skippedLogs)
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
