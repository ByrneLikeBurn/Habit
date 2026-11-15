import Foundation
import SwiftData
import Testing
@testable import HabitKit

@MainActor
private func makeContext() throws -> ModelContext {
    let container = try ModelContainer(
        for: Schema(versionedSchema: HabitSchemaV1.self),
        migrationPlan: HabitMigrationPlan.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
}

private let today = DayKey(rawValue: 20261114)
private let now = Date(timeIntervalSince1970: 1_794_700_000)

@MainActor
private func habit(_ kind: HabitKind, target: Int? = 1, tap: Int? = 1, in context: ModelContext) -> Habit {
    let habit = Habit(name: "Drink water", symbolName: "drop", kind: kind, target: target, tapAmount: tap, createdAt: now, firstDay: today.adding(days: -30))
    context.insert(habit)
    return habit
}

@MainActor
@discardableResult
private func log(_ action: LogAction, _ habit: Habit, _ context: ModelContext, day: DayKey = today, device: String = "A") throws -> LogOutcome {
    try LogWriter.log(action, habit: habit, day: day, source: .manual, deviceID: device, now: now, in: context)
}

@MainActor
@Suite("Logging")
struct LoggingTests {
    @Test func yesOrNoTapLogsAndASecondTapTakesItBack() throws {
        let context = try makeContext()
        let h = habit(.binary, in: context)
        #expect(try log(.tap, h, context) == .wrote(delta: 1, newTotal: 1))
        #expect(h.state(on: today, today: today) == .done)
        #expect(try log(.tap, h, context) == .wrote(delta: -1, newTotal: 0))
        #expect(h.state(on: today, today: today) == .blank)
    }

    @Test func takingBackWritesMinusTheCurrentTotal() throws {
        let context = try makeContext()
        let h = habit(.binary, in: context)
        try log(.add(3), h, context)
        #expect(try log(.tap, h, context) == .wrote(delta: -3, newTotal: 0))
    }

    @Test func countedTapOnlyEverAddsTheTapAmount() throws {
        let context = try makeContext()
        let h = habit(.counted, target: 8, tap: 2, in: context)
        for expected in [2, 4, 6, 8, 10] {
            #expect(try log(.tap, h, context) == .wrote(delta: 2, newTotal: expected))
        }
        #expect(h.state(on: today, today: today) == .done)
    }

    @Test func countedWithNoTapAmountAsksForAnAmount() throws {
        let context = try makeContext()
        let h = habit(.counted, target: 15_000, tap: nil, in: context)
        #expect(try log(.tap, h, context) == .needsAmount)
        #expect(h.events?.isEmpty == true)
    }

    @Test func aTypedAmountIsWrittenAsTheDeltaItself() throws {
        let context = try makeContext()
        let h = habit(.counted, target: 15_000, tap: nil, in: context)
        #expect(try log(.add(12_345), h, context) == .wrote(delta: 12_345, newTotal: 12_345))
        #expect(try log(.takeAway(345), h, context) == .wrote(delta: -345, newTotal: 12_000))
        #expect(h.events?.map(\.delta).sorted() == [-345, 12_345])
    }

    @Test func takeAwayNeverTakesMoreThanTheTotal() throws {
        let context = try makeContext()
        let h = habit(.counted, target: 8, in: context)
        try log(.add(3), h, context)
        #expect(try log(.takeAway(10), h, context) == .wrote(delta: -3, newTotal: 0))
        #expect(try log(.takeAway(1), h, context) == .unchanged(total: 0))
    }

    @Test func zeroAndNegativeAmountsWriteNothing() throws {
        let context = try makeContext()
        let h = habit(.counted, target: 8, in: context)
        #expect(try log(.add(0), h, context) == .unchanged(total: 0))
        #expect(try log(.add(-4), h, context) == .unchanged(total: 0))
        #expect(h.events?.isEmpty == true)
    }

    @Test func undoIsTheInverse() throws {
        let context = try makeContext()
        let h = habit(.counted, target: 8, in: context)
        let outcome = try log(.add(5), h, context)
        try log(outcome.inverse!, h, context)
        #expect(h.total(on: today) == 0)
        let binary = habit(.binary, in: context)
        try log(.tap, binary, context)
        let takeBack = try log(.tap, binary, context)
        try log(takeBack.inverse!, binary, context)
        #expect(binary.state(on: today, today: today) == .done)
    }

    @Test func twoDevicesTakingBackOfflineShowZeroAndTheNextTapLogs() throws {
        let context = try makeContext()
        let h = habit(.binary, in: context)
        try log(.tap, h, context, device: "A")
        // Both devices saw a total of 1 and each wrote -1 before syncing.
        context.insert(LogEvent(delta: -1, habit: h, day: today, source: .manual, timestamp: now, deviceID: "A"))
        context.insert(LogEvent(delta: -1, habit: h, day: today, source: .watch, timestamp: now, deviceID: "B"))
        #expect(h.rawTotal(on: today) == -1)
        #expect(h.total(on: today) == 0)
        #expect(try log(.tap, h, context) == .wrote(delta: 2, newTotal: 1))
        #expect(h.state(on: today, today: today) == .done)
    }

    @Test func twoDevicesAddingOfflineSumInAnyOrder() throws {
        let context = try makeContext()
        let h = habit(.counted, target: 8, in: context)
        let deltas = [(2, "A"), (3, "B"), (-1, "A"), (4, "B")]
        for (delta, device) in deltas.reversed() {
            context.insert(LogEvent(delta: delta, habit: h, day: today, source: .manual, timestamp: now, deviceID: device))
        }
        #expect(h.total(on: today) == 8)
    }

    @Test func eventsKeepTheirDayAndSource() throws {
        let context = try makeContext()
        let h = habit(.binary, in: context)
        try LogWriter.log(.tap, habit: h, day: today.adding(days: -2), source: .shortcut, deviceID: "A", now: now, in: context)
        let event = try #require(h.events?.first)
        #expect(event.day == today.adding(days: -2))
        #expect(event.source == .shortcut)
        #expect(h.total(on: today) == 0)
    }
}

@MainActor
@Suite("Target and schedule history")
struct RuleTests {
    @Test func aChangeAppliesFromTheDayOfTheChange() throws {
        let context = try makeContext()
        let h = habit(.counted, target: 8, in: context)
        try log(.add(6), h, context, day: today.adding(days: -1))
        h.setRule(target: 5, schedule: .all, from: today)
        #expect(h.state(on: today.adding(days: -1), today: today) == .partDone)
        try log(.add(6), h, context)
        #expect(h.state(on: today, today: today) == .done)
        #expect(h.target == 5)
    }

    @Test func aScheduleChangeLeavesEarlierDaysScheduled() throws {
        let context = try makeContext()
        let h = habit(.binary, in: context)
        let saturdayOff = Weekdays(rawValue: 127 & ~Weekdays(weekday: 7).rawValue)
        h.setRule(target: 1, schedule: saturdayOff, from: today)
        #expect(!h.isScheduled(on: today))
        #expect(h.isScheduled(on: today.adding(days: -7)))
    }

    @Test func twoChangesOnOneDayKeepOneRule() throws {
        let context = try makeContext()
        let h = habit(.counted, target: 8, in: context)
        h.setRule(target: 6, schedule: .all, from: today)
        h.setRule(target: 4, schedule: .all, from: today)
        #expect(h.rules.count == 2)
        #expect(h.rule(on: today).target == 4)
        #expect(h.rule(on: today.adding(days: -1)).target == 8)
    }

    @Test func aDayBeforeTheFirstRuleUsesTheFirstRule() throws {
        let context = try makeContext()
        let h = habit(.counted, target: 8, in: context)
        #expect(h.rule(on: today.adding(days: -400)).target == 8)
    }

    @Test func runsFromTheStore() throws {
        let context = try makeContext()
        let h = habit(.binary, in: context)
        for offset in [-3, -2, -1, 0] {
            try log(.tap, h, context, day: today.adding(days: offset))
        }
        let paused = Pause(habit: h, start: today.adding(days: -5), end: today.adding(days: -4), reason: .vacation)
        context.insert(paused)
        try log(.tap, h, context, day: today.adding(days: -6))
        let summary = h.runSummary(today: today)
        // -6 logged, -5 and -4 paused with no log, -3 to 0 logged.
        #expect(summary.current == 5)
    }
}

@MainActor
@Suite("Ordering")
struct OrderingTests {
    @Test func moveRewritesIndexesAndKeepsHiddenHabitsInPlace() throws {
        let context = try makeContext()
        let names = ["A", "B", "C", "D"]
        let habits = names.enumerated().map { index, name in
            let h = Habit(name: name, symbolName: "drop", kind: .binary, target: 1, sortIndex: index, createdAt: now, firstDay: today)
            context.insert(h)
            return h
        }
        // C is hidden from the visible list. Move D to the top.
        let visible = [habits[0], habits[1], habits[3]]
        Ordering.move(visible, from: IndexSet(integer: 2), to: 0, all: habits)
        #expect(Ordering.sorted(habits).map(\.name) == ["D", "A", "C", "B"])
    }

    @Test func archivedHabitsAreNotListed() throws {
        let context = try makeContext()
        let h = habit(.binary, in: context)
        h.archivedAt = now
        #expect(Ordering.sorted([h]).isEmpty)
    }
}
