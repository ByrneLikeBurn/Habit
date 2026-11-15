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

@Suite("Requests from outside the app")
struct ExternalActionTests {
    @Test func aShortcutForAYesOrNoHabitOnlyEverLogs() {
        #expect(LogAction.external(amount: nil, takeAway: false, kind: .binary, tapAmount: 1) == .markDone)
        #expect(LogAction.external(amount: 3, takeAway: false, kind: .binary, tapAmount: 1) == .markDone)
        #expect(LogWriter.delta(for: .markDone, kind: .binary, tapAmount: 1, total: 1) == nil)
    }

    @Test func takeAwayWithNoAmountTakesAwayOneTap() {
        #expect(LogAction.external(amount: nil, takeAway: true, kind: .counted, tapAmount: 2) == .takeAway(2))
        #expect(LogAction.external(amount: nil, takeAway: true, kind: .counted, tapAmount: nil) == .takeAway(1))
        #expect(LogAction.external(amount: nil, takeAway: true, kind: .binary, tapAmount: 1) == .clear)
    }

    @Test func countedAmounts() {
        #expect(LogAction.external(amount: nil, takeAway: false, kind: .counted, tapAmount: 1) == .tap)
        #expect(LogAction.external(amount: 250, takeAway: false, kind: .counted, tapAmount: 1) == .add(250))
        #expect(LogAction.external(amount: 250, takeAway: true, kind: .counted, tapAmount: 1) == .takeAway(250))
    }
}

@MainActor
@Suite("Review fixes")
struct ReviewFixTests {
    @Test func hugeNumbersAreRefusedOrCapped() throws {
        #expect(CountText.parse("9223372036854775807") == nil)
        #expect(CountText.parse("1000001") == nil)
        #expect(CountText.parse("1000000") == 1_000_000)
        #expect(CountText.parse("1,000,000", locale: Locale(identifier: "en_GB")) == 1_000_000)
        #expect(LogWriter.delta(for: .add(.max), kind: .counted, tapAmount: 1, total: 0) == CountText.maximumAmount)
        let context = try makeContext()
        let h = Habit(name: "Steps", symbolName: "figure.walk", kind: .counted, target: 15_000, tapAmount: nil, createdAt: now, firstDay: today)
        context.insert(h)
        context.insert(LogEvent(delta: .max, habit: h, day: today, source: .manual, timestamp: now, deviceID: "A"))
        context.insert(LogEvent(delta: .max, habit: h, day: today, source: .manual, timestamp: now, deviceID: "B"))
        #expect(h.total(on: today) == .max)
        #expect(try LogWriter.rawTotal(of: h, on: today, in: context) == .max)
    }

    @Test func dayTotalsMatchTheHabitsOwnSum() throws {
        let context = try makeContext()
        let a = Habit(name: "A", symbolName: "drop", kind: .counted, target: 8, createdAt: now, firstDay: today)
        let b = Habit(name: "B", symbolName: "book", kind: .binary, target: 1, createdAt: now, firstDay: today)
        context.insert(a)
        context.insert(b)
        for (habit, delta, day) in [(a, 3, today), (a, 2, today), (a, 9, today.adding(days: -1)), (b, 1, today)] {
            try LogWriter.log(.add(delta), habit: habit, day: day, source: .manual, deviceID: "A", now: now, in: context)
        }
        let totals = try LogWriter.dayTotals(on: today, in: context)
        #expect(totals[a.id] == 5 && totals[a.id] == a.rawTotal(on: today))
        #expect(totals[b.id] == 1)
    }

    @Test func aLogAfterTodayIsDrawnAndCounted() throws {
        let context = try makeContext()
        let h = Habit(name: "Read", symbolName: "book", kind: .binary, target: 1, createdAt: now, firstDay: today.adding(days: -2))
        context.insert(h)
        // Logged in Tokyo on the 15th, then flew to London where it is still the 14th.
        let tomorrow = today.adding(days: 1)
        try LogWriter.log(.tap, habit: h, day: tomorrow, source: .manual, deviceID: "A", now: now, in: context)
        #expect(h.state(on: tomorrow, today: today) == .done)
        let summary = h.runSummary(today: today)
        #expect(summary.daysLogged == 1)
        #expect(summary.current == 1)
    }

    @Test func changingTheDayStartDuringADayMovesToday() {
        // 07:00 in London. With day start 04:00 it is the 14th. With 08:00 it is still the 13th.
        let instant = try! Date("2026-11-14T07:00:00Z", strategy: .iso8601)
        let early = HabitClock.frozen(at: instant, timeZone: TimeZone(identifier: "Europe/London")!, dayStartHour: 4)
        let late = HabitClock.frozen(at: instant, timeZone: TimeZone(identifier: "Europe/London")!, dayStartHour: 8)
        #expect(early.today == today && !early.isBeforeDayStart)
        #expect(late.today == today.adding(days: -1) && late.isBeforeDayStart)
    }
}
