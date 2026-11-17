import Foundation
#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import AppKit
#endif
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

private let today = DayKey(rawValue: 20261114) // a Saturday
private let now = Date(timeIntervalSince1970: 1_794_700_000)

@MainActor
private func addHabit(_ name: String, _ kind: HabitKind = .binary, target: Int? = 1, unit: String = "", schedule: Weekdays = .all, firstDay: DayKey = today.adding(days: -30), in context: ModelContext) -> Habit {
    let habit = Habit(name: name, symbolName: "drop", kind: kind, target: target, unit: unit, schedule: schedule, createdAt: now, firstDay: firstDay)
    context.insert(habit)
    return habit
}

@MainActor
private func log(_ action: LogAction, _ habit: Habit, day: DayKey, _ context: ModelContext) throws {
    try LogWriter.log(action, habit: habit, day: day, source: .manual, deviceID: "device-A", now: now, in: context)
}

@Suite("Periods")
struct PeriodTests {
    @Test func weekStartsOnTheUsersFirstWeekday() {
        // Monday start: Saturday 14 November belongs to the week of Monday 9 November.
        #expect(Periods.weekStart(of: today, firstWeekday: 2) == DayKey(rawValue: 20261109))
        // Sunday start: the week of Sunday 8 November.
        #expect(Periods.weekStart(of: today, firstWeekday: 1) == DayKey(rawValue: 20261108))
        #expect(Periods.week(of: today, firstWeekday: 2).count == 7)
    }

    @Test func monthGridHasWholeWeeks() {
        let grid = Periods.monthGrid(of: today, firstWeekday: 2)
        // November 2026 starts on a Sunday, so with Monday first the first row has six blanks.
        #expect(grid.first?.prefix(6).allSatisfy { $0 == nil } == true)
        #expect(grid.first?[6] == DayKey(rawValue: 20261101))
        #expect(grid.allSatisfy { $0.count == 7 })
        #expect(grid.flatMap { $0 }.compactMap { $0 }.count == 30)
        #expect(Periods.daysInMonth(of: DayKey(rawValue: 20280210)) == 29)
    }

    @Test func movingByMonthsAndYears() {
        #expect(Periods.adding(months: 2, to: DayKey(rawValue: 20261130)) == DayKey(rawValue: 20270101))
        #expect(Periods.adding(months: -11, to: today) == DayKey(rawValue: 20251201))
        #expect(Periods.move(today, by: -1, kind: .week) == DayKey(rawValue: 20261107))
    }

    @Test func noDayOfAYearIsInTwoYearWeeks() {
        let months = (1...12).map { DayKey(year: 2026, month: $0, day: 1) }
        let days = months.flatMap { Periods.yearWeeks(of: $0).flatMap { $0 } }
        #expect(Set(days).count == days.count)
        // A week belongs to the month that holds its Monday.
        for month in months {
            for week in Periods.yearWeeks(of: month) {
                #expect(week[0].weekday == 2 && week[0].month == month.month)
            }
        }
    }

    @Test func theYearStartsAtTheSinceMonth() {
        let since = DayKey(rawValue: 20260428)
        #expect(Periods.yearMonths(year: 2026, since: since, today: today).map(\.month) == Array(4...11))
        #expect(Periods.yearMonths(year: 2025, since: since, today: today).isEmpty)
    }

    @Test func dayKeyChecks() {
        #expect(Periods.isValid(20261114))
        #expect(Periods.isValid(20280229))
        #expect(!Periods.isValid(20270229))
        #expect(!Periods.isValid(20261131))
        #expect(!Periods.isValid(19991231))
        #expect(!Periods.isValid(0))
    }
}

@MainActor
@Suite("Stats")
struct StatsTests {
    @Test func aDayNotScheduledDrawsADotAndADayToComeDrawsNothing() throws {
        let context = try makeContext()
        let weekdays = Weekdays(rawValue: 0b0111110)
        let h = addHabit("Pack lunch", schedule: weekdays, in: context)
        #expect(h.state(on: today, today: today) == .offSchedule)
        #expect(h.state(on: today.adding(days: 1), today: today) == .blank)
        #expect(h.state(on: today.adding(days: 2), today: today) == .blank)
    }

    @Test func statsForACountedHabit() throws {
        let context = try makeContext()
        let h = addHabit("Water", .counted, target: 8, unit: "glasses", in: context)
        try log(.add(8), h, day: today.adding(days: -2), context)
        try log(.add(3), h, day: today.adding(days: -1), context)
        try log(.add(2), h, day: today, context)
        let stats = h.stats(today: today)
        #expect(stats.daysLogged == 3)
        #expect(stats.daysDone == 1)
        #expect(stats.unitTotal == 13)
        // Part done extends a run.
        #expect(stats.run == .days(3))
        #expect(stats.longestRun == 3)
        #expect(stats.since == today.adding(days: -30))
    }

    @Test func aRunAfterAGapReadsBetweenRunsAndNeverZero() throws {
        let context = try makeContext()
        let h = addHabit("Read", in: context)
        #expect(h.stats(today: today).run == .noRunYet)
        try log(.markDone, h, day: today.adding(days: -5), context)
        #expect(h.stats(today: today).run == .betweenRuns)
        #expect(h.stats(today: today).longestRun == 1)
        // A take-back to zero counts as no log.
        try log(.markDone, h, day: today.adding(days: -1), context)
        try log(.clear, h, day: today.adding(days: -1), context)
        #expect(h.stats(today: today).run == .betweenRuns)
    }

    @Test func sinceUsesAnEarlierLog() throws {
        let context = try makeContext()
        let h = addHabit("Read", in: context)
        try log(.markDone, h, day: DayKey(rawValue: 20260428), context)
        #expect(h.stats(today: today).since == DayKey(rawValue: 20260428))
    }
}

@MainActor
@Suite("Export and import")
struct ExportImportTests {
    private func seed(_ context: ModelContext) throws -> [Habit] {
        let water = addHabit("Drink water", .counted, target: 8, unit: "glasses", in: context)
        let read = addHabit("Read", in: context)
        read.sortIndex = 1
        let pause = Pause(habit: nil, start: today.adding(days: -10), end: today.adding(days: -8), reason: .vacation)
        context.insert(pause)
        for offset in 1...20 {
            try log(.add(offset % 4 + 1), water, day: today.adding(days: -offset), context)
            if offset % 3 != 0 { try log(.markDone, read, day: today.adding(days: -offset), context) }
        }
        // A negative amount and a zero-sum day survive the trip.
        try log(.takeAway(2), water, day: today.adding(days: -3), context)
        try log(.markDone, read, day: today, context)
        try log(.clear, read, day: today, context)
        // A target change against history.
        water.setRule(target: 6, schedule: .all, from: today.adding(days: -5))
        try context.save()
        return [water, read]
    }

    private func export(_ context: ModelContext, at date: Date = now) throws -> Data {
        try ExportFile.make(from: context, appBuild: "1", now: date).encoded()
    }

    private func importData(_ data: Data, into context: ModelContext) throws -> LogWriter.ImportResult {
        let plan = try ImportPlan.make(from: data, in: context)
        return try LogWriter.importEvents(plan, in: context)
    }

    @Test func roundTripGivesTheSameFileAndTheSameTotalsAndRuns() throws {
        let source = try makeContext()
        let habits = try seed(source)
        let first = try export(source)

        let target = try makeContext()
        let result = try importData(first, into: target)
        #expect(result.habitsAdded == 2)
        #expect(result.pausesAdded == 1)
        let second = try export(target)
        #expect(first == second)

        let imported = try target.fetch(FetchDescriptor<Habit>())
        for original in habits {
            let copy = try #require(imported.first { $0.id == original.id })
            #expect(copy.dayTotals() == original.dayTotals())
            let pauses = try target.fetch(FetchDescriptor<Pause>())
            let originalPauses = try source.fetch(FetchDescriptor<Pause>())
            #expect(copy.runSummary(today: today, sharedPauses: pauses) == original.runSummary(today: today, sharedPauses: originalPauses))
            #expect(copy.rules == original.rules)
        }
        let events = try target.fetch(FetchDescriptor<LogEvent>())
        #expect(events.allSatisfy { $0.deviceID == LogWriter.importedDeviceID })
        #expect(events.contains { $0.delta < 0 })
    }

    @Test func theFileHoldsNoDeviceIdAndNoSettings() throws {
        let context = try makeContext()
        _ = try seed(context)
        let text = try #require(String(data: try export(context), encoding: .utf8))
        #expect(!text.contains("device-A"))
        #expect(!text.lowercased().contains("device"))
        #expect(text.contains(ExportFile.formatName))
    }

    @Test func aSecondImportAddsNothing() throws {
        let source = try makeContext()
        _ = try seed(source)
        let data = try export(source)
        let target = try makeContext()
        _ = try importData(data, into: target)
        let count = try target.fetchCount(FetchDescriptor<LogEvent>())
        let plan = try ImportPlan.make(from: data, in: target)
        #expect(plan.isEmpty)
        #expect(plan.skippedLogs == count)
        #expect(plan.differing == 0)
        _ = try LogWriter.importEvents(plan, in: target)
        #expect(try target.fetchCount(FetchDescriptor<LogEvent>()) == count)
    }

    @Test func dayKeysDoNotMoveUnderAnotherTimeZoneOrDayStart() throws {
        let source = try makeContext()
        _ = try seed(source)
        let data = try export(source)
        // Import reads day keys as stored. No clock is involved, so nothing can shift them.
        let target = try makeContext()
        _ = try importData(data, into: target)
        let a = Set(try source.fetch(FetchDescriptor<LogEvent>()).map { "\($0.id)-\($0.dayKey)" })
        let b = Set(try target.fetch(FetchDescriptor<LogEvent>()).map { "\($0.id)-\($0.dayKey)" })
        #expect(a == b)
    }

    @Test func aHabitThatDiffersKeepsThisDevicesVersionAndArchivedStaysArchived() throws {
        let source = try makeContext()
        let habits = try seed(source)
        let data = try export(source)
        let target = try makeContext()
        _ = try importData(data, into: target)
        let here = try target.fetch(FetchDescriptor<Habit>())
        let water = try #require(here.first { $0.id == habits[0].id })
        water.name = "Water"
        let read = try #require(here.first { $0.id == habits[1].id })
        read.archivedAt = now
        try target.save()
        // A new log in the file for the archived habit still imports.
        try log(.markDone, habits[1], day: today.adding(days: -3), source)
        let plan = try ImportPlan.make(from: try export(source), in: target)
        #expect(plan.differing == 2)
        #expect(plan.newLogs.count == 1)
        _ = try LogWriter.importEvents(plan, in: target)
        #expect(water.name == "Water")
        #expect(read.archivedAt != nil)
    }

    // MARK: Refusals. Each writes nothing.

    private func expectRefused(_ data: Data, _ problem: ImportProblem, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let target = try makeContext()
        #expect(throws: problem, sourceLocation: sourceLocation) { _ = try ImportPlan.make(from: data, in: target) }
        #expect(try target.fetchCount(FetchDescriptor<LogEvent>()) == 0, sourceLocation: sourceLocation)
        #expect(try target.fetchCount(FetchDescriptor<Habit>()) == 0, sourceLocation: sourceLocation)
    }

    private func sampleFile() throws -> ExportFile {
        let context = try makeContext()
        _ = try seed(context)
        return try ExportFile.make(from: context, appBuild: "1", now: now)
    }

    @Test func refusesAFileThatIsNotAHabitExport() throws {
        try expectRefused(Data("hello".utf8), .notAHabitExport)
        try expectRefused(Data(#"{"format":"something else","version":1}"#.utf8), .notAHabitExport)
    }

    @Test func refusesANewerVersion() throws {
        var file = try sampleFile()
        file.version = ExportFile.currentVersion + 1
        try expectRefused(try file.encoded(), .newerVersion)
        // Newer is named even when the records changed shape.
        try expectRefused(Data(#"{"format":"dev.byrnelikeburn.Habit.export","version":2,"items":[]}"#.utf8), .newerVersion)
    }

    @Test func refusesACutOffFile() throws {
        let data = try sampleFile().encoded()
        try expectRefused(data.prefix(data.count / 2), .notAHabitExport)
    }

    @Test func refusesBadRecords() throws {
        var badDay = try sampleFile()
        badDay.logs[0].day = 20261131
        try expectRefused(try badDay.encoded(), .damaged)

        var overCap = try sampleFile()
        overCap.logs[0].delta = CountText.maximumAmount + 1
        try expectRefused(try overCap.encoded(), .damaged)

        var unknownKind = try sampleFile()
        unknownKind.habits[0].kind = "timer"
        try expectRefused(try unknownKind.encoded(), .damaged)

        var missingHabit = try sampleFile()
        missingHabit.logs[0].habit = UUID()
        try expectRefused(try missingHabit.encoded(), .damaged)
    }

    @Test func unknownKeysAreIgnored() throws {
        let data = try sampleFile().encoded()
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["comment"] = "from a later tool"
        let target = try makeContext()
        let plan = try ImportPlan.make(from: try JSONSerialization.data(withJSONObject: object), in: target)
        #expect(plan.newHabits.count == 2)
    }

    // MARK: Gate: import size and count limits.

    @Test func aFileOverTheSizeLimitIsRefusedBeforeItIsRead() throws {
        let data = Data(count: ImportLimits.maxBytes + 1)
        try expectRefused(data, .tooLarge)
    }

    @Test func aFileOverACountLimitIsRefusedWithNothingWritten() throws {
        var file = try sampleFile()
        let template = file.logs[0]
        file.logs = (0...ImportLimits.maxLogs).map { _ in
            var log = template
            log.id = UUID()
            return log
        }
        let data = try file.encoded()
        #expect(data.count <= ImportLimits.maxBytes, "The size limit must leave room for the count limit")
        try expectRefused(data, .tooLarge)

        var habits = try sampleFile()
        let h = habits.habits[0]
        habits.habits = (0...ImportLimits.maxHabits).map { _ in var copy = h; copy.id = UUID(); return copy }
        habits.logs = []
        try expectRefused(try habits.encoded(), .tooLarge)
    }

    @Test func aFileAtTheLimitsImports() throws {
        var file = try sampleFile()
        let template = file.logs[0]
        file.logs = (0..<ImportLimits.maxLogs).map { i in
            var log = template
            log.id = UUID()
            log.day = today.adding(days: -(i % 3000)).rawValue
            return log
        }
        let data = try file.encoded()
        #expect(data.count <= ImportLimits.maxBytes)
        let target = try makeContext()
        let plan = try ImportPlan.make(from: data, in: target)
        #expect(plan.newLogs.count == ImportLimits.maxLogs)
        // Before events were attached per habit in one assignment, this took hours.
        let started = Date()
        let result = try LogWriter.importEvents(plan, in: target)
        #expect(result.logsAdded == ImportLimits.maxLogs)
        #expect(Date().timeIntervalSince(started) < 120)
        // Each event points at its habit, and the habit holds every event.
        let orphans = try target.fetchCount(FetchDescriptor<LogEvent>(predicate: #Predicate { $0.habit == nil }))
        #expect(orphans == 0)
        let habit = try #require(try target.fetch(FetchDescriptor<Habit>()).first { $0.id == template.habit })
        // Every log in this file belongs to the template's habit.
        #expect(habit.events?.count == ImportLimits.maxLogs)
    }

    @Test func exportFileNameHoldsNoName() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        #expect(ExportFile.fileName(for: now, calendar: calendar) == "Habit export 2026-11-14.json")
    }
}

@MainActor
@Suite("Review fixes, milestone 2")
struct HistoryReviewFixTests {
    @Test func daysBeforeTheHabitBeganDrawNothing() throws {
        let context = try makeContext()
        // Every day except Thursday, from Tuesday 28 April 2026.
        var schedule = Weekdays.all
        schedule.remove(Weekdays(weekday: 5))
        let h = addHabit("Water", schedule: schedule, firstDay: DayKey(rawValue: 20260428), in: context)
        let thursdayBefore = DayKey(rawValue: 20260423)
        #expect(!h.rule(on: thursdayBefore).schedule.contains(thursdayBefore))
        #expect(h.state(on: thursdayBefore, today: today) == .blank)
        #expect(h.state(on: DayKey(rawValue: 20260427), today: today, showDaysNotLogged: true) == .blank)
        // From the first day, an off day has its dot.
        #expect(h.state(on: DayKey(rawValue: 20260430), today: today) == .offSchedule)
        // A log before the first day still draws.
        try log(.markDone, h, day: thursdayBefore, context)
        #expect(h.state(on: thursdayBefore, today: today) == .loggedOffSchedule)
    }

    @Test func everythingLoggingCanWriteImportsAgain() throws {
        let context = try makeContext()
        let big = addHabit("Steps", .counted, target: nil, in: context)
        let read = addHabit("Read", in: context)
        // At the cap: adds stop there, so Clear stays within it.
        try log(.add(CountText.maximumAmount), big, day: today, context)
        try log(.add(CountText.maximumAmount), big, day: today, context)
        #expect(big.total(on: today) == CountText.maximumAmount)
        try log(.clear, big, day: today, context)
        #expect(big.total(on: today) == 0)
        try log(.markDone, read, day: Periods.earliest, context)
        // A day before 2000 is refused at the write, the same check import makes.
        #expect(throws: LogWriter.Problem.self) { try log(.markDone, read, day: DayKey(rawValue: 19991231), context) }
        read.name = String(repeating: "a", count: ImportLimits.maxTextLength)
        try context.save()

        let data = try ExportFile.make(from: context, appBuild: "1", now: now).encoded()
        let target = try makeContext()
        let plan = try ImportPlan.make(from: data, in: target)
        // The second add at the cap writes nothing: one add, one Clear, one mark done.
        #expect(plan.newLogs.count == 3)
    }

    @Test func writingOnePlanTwiceAddsNothingTheSecondTime() throws {
        let source = try makeContext()
        let h = addHabit("Read", in: source)
        for offset in 1...5 { try log(.markDone, h, day: today.adding(days: -offset), source) }
        let data = try ExportFile.make(from: source, appBuild: "1", now: now).encoded()
        let target = try makeContext()
        let plan = try ImportPlan.make(from: data, in: target)
        let first = try LogWriter.importEvents(plan, in: target)
        let second = try LogWriter.importEvents(plan, in: target)
        #expect(first.logsAdded == 5)
        #expect(second.logsAdded == 0 && second.habitsAdded == 0)
        #expect(try target.fetchCount(FetchDescriptor<LogEvent>()) == 5)
        #expect(try target.fetchCount(FetchDescriptor<Habit>()) == 1)
    }

    @Test func logsForAHabitDeletedHereAreSkipped() throws {
        let source = try makeContext()
        let h = addHabit("Read", in: source)
        try log(.markDone, h, day: today.adding(days: -1), source)
        let data = try ExportFile.make(from: source, appBuild: "1", now: now).encoded()
        let target = try makeContext()
        _ = try LogWriter.importEvents(try ImportPlan.make(from: data, in: target), in: target)
        let here = try #require(try target.fetch(FetchDescriptor<Habit>()).first)
        here.deletedAt = now
        try target.save()
        try log(.markDone, h, day: today.adding(days: -2), source)
        let plan = try ImportPlan.make(from: try ExportFile.make(from: source, appBuild: "1", now: now).encoded(), in: target)
        #expect(plan.newLogs.isEmpty)
        #expect(plan.differing == 0)
    }

    @Test func aLoggedDayAfterTodayIsDrawnByItsState() throws {
        let context = try makeContext()
        let h = addHabit("Read", in: context)
        try log(.markDone, h, day: today.adding(days: 1), context)
        #expect(h.state(on: today.adding(days: 1), today: today) == .done)
        #expect(h.state(on: today.adding(days: 2), today: today) == .blank)
    }

    @Test func theYearViewDrawsEveryDayFromSinceToToday() {
        for since in [DayKey(rawValue: 20260101), DayKey(rawValue: 20261101), DayKey(rawValue: 20260201), DayKey(rawValue: 20250615)] {
            let start = Periods.yearViewStart(since: since)
            var drawn = Set<DayKey>()
            for year in start.year...today.year {
                for month in Periods.yearMonths(year: year, since: since, today: today) {
                    for day in Periods.yearWeeks(of: month).flatMap({ $0 }) {
                        #expect(drawn.insert(day).inserted, "\(day) drawn twice")
                    }
                }
            }
            var day = since
            while day <= today {
                #expect(drawn.contains(day), "\(day) not drawn for since \(since)")
                day = day.adding(days: 1)
            }
        }
    }
}

/// No set days: scheduleMask 0. A valid habit that is never scheduled.
@Suite("No set days")
@MainActor
struct NoSetDaysTests {
    @Test func theFormRuleAcceptsNoDaysAndRefusesAnEmptyName() {
        #expect(HabitForm.problems(HabitDraft(name: "Read", kind: .binary, schedule: [])).isEmpty)
        #expect(HabitForm.problems(HabitDraft(name: "  ", kind: .binary, schedule: .all)) == [.emptyName])
        #expect(HabitForm.problems(HabitDraft(name: "", kind: .binary, schedule: [])) == [.emptyName])
        #expect(HabitForm.problems(HabitDraft(name: "Water", kind: .counted, targetText: "0", tapText: "x")) == [.target, .tapAmount])
        #expect(HabitForm.problems(HabitDraft(name: "Water", kind: .counted, targetText: "", tapText: "")).isEmpty)
    }

    @Test func noDaysIsStoredAsZeroAndEditsApplyFromToday() throws {
        let context = try makeContext()
        let empty = addHabit("Read", schedule: [], in: context)
        #expect(empty.scheduleMask == 0)
        #expect(empty.rules.first?.scheduleMask == 0)

        let habit = addHabit("Walk", schedule: .all, firstDay: today.adding(days: -30), in: context)
        habit.setRule(target: 1, schedule: [], from: today)
        #expect(habit.scheduleMask == 0)
        #expect(habit.isScheduled(on: today.adding(days: -7)))
        #expect(!habit.isScheduled(on: today))
        habit.setRule(target: 1, schedule: [], from: today)
        #expect(habit.rules.filter { $0.fromDay == today.rawValue }.count == 1)
        #expect(habit.rules.count == 2)
    }

    private func file(schedule: Int) throws -> Data {
        let context = try makeContext()
        let habit = addHabit("Read", schedule: [], in: context)
        try log(.markDone, habit, day: today.adding(days: -2), context)
        try context.save()
        var file = try ExportFile.make(from: context, appBuild: "1", now: now)
        file.habits[0].schedule = schedule
        file.habits[0].rules = file.habits[0].rules.map { var r = $0; r.schedule = schedule; return r }
        return try file.encoded()
    }

    @Test func aFileWithNoDaysImportsExportsTheSameAndImportsOnce() throws {
        let data = try file(schedule: 0)
        let target = try makeContext()
        let plan = try ImportPlan.make(from: data, in: target)
        _ = try LogWriter.importEvents(plan, in: target)
        let habit = try #require(try target.fetch(FetchDescriptor<Habit>()).first)
        #expect(habit.scheduleMask == 0)
        #expect(try ExportFile.make(from: target, appBuild: "1", now: now).encoded() == data)
        let again = try ImportPlan.make(from: data, in: target)
        #expect(again.isEmpty)
        _ = try LogWriter.importEvents(again, in: target)
        #expect(try target.fetchCount(FetchDescriptor<Habit>()) == 1)
        #expect(try target.fetchCount(FetchDescriptor<LogEvent>()) == 1)
    }

    @Test func schedulesOutsideTheWeekAreRefusedWithNothingWritten() throws {
        for bad in [128, -1] {
            let data = try file(schedule: bad)
            let target = try makeContext()
            #expect(throws: ImportProblem.damaged) { _ = try ImportPlan.make(from: data, in: target) }
            #expect(try target.fetchCount(FetchDescriptor<Habit>()) == 0)
            #expect(try target.fetchCount(FetchDescriptor<LogEvent>()) == 0)
        }
    }
}

@Suite("No set days on Today")
@MainActor
struct NoSetDaysOrderingTests {
    /// Daily, no days, weekdays only (not Saturday), daily, in that order.
    private func seed(_ context: ModelContext) -> [Habit] {
        let names: [(String, Weekdays)] = [("Water", .all), ("Read", []), ("Scales", Weekdays(rawValue: 0b0111110)), ("Walk", .all)]
        return names.enumerated().map { index, item in
            let habit = addHabit(item.0, schedule: item.1, in: context)
            habit.sortIndex = index
            return habit
        }
    }

    @Test func aNoDaysHabitIsInTodaysListInItsOwnOrderOnEveryWeekday() throws {
        let context = try makeContext()
        let habits = seed(context)
        for offset in 0..<7 {
            let split = Ordering.today(habits, day: today.adding(days: offset))
            #expect(split.scheduled.map(\.name).contains("Read"))
        }
        let saturday = Ordering.today(habits, day: today)
        #expect(saturday.scheduled.map(\.name) == ["Water", "Read", "Walk"])
        #expect(saturday.notScheduled.map(\.name) == ["Scales"])
    }

    @Test func moveUpAndDownPastDailyRowsKeepsAHiddenHabitInPlace() throws {
        let context = try makeContext()
        let habits = seed(context)
        var visible = Ordering.today(habits, day: today).scheduled
        // Move Read up past Water.
        Ordering.move(visible, from: IndexSet(integer: 1), to: 0, all: habits)
        #expect(Ordering.sorted(habits).map(\.name) == ["Read", "Water", "Scales", "Walk"])
        // Move Read down past Water and Walk.
        visible = Ordering.today(habits, day: today).scheduled
        Ordering.move(visible, from: IndexSet(integer: 0), to: 3, all: habits)
        #expect(Ordering.today(habits, day: today).scheduled.map(\.name) == ["Water", "Walk", "Read"])
        // Scales, hidden on Saturday, keeps its slot, third, and the visible rows fill the others.
        #expect(Ordering.sorted(habits).map(\.name) == ["Water", "Walk", "Scales", "Read"])
    }

    @Test func noDaysIsReadFromTodaysRuleNotTheCurrentMask() throws {
        let context = try makeContext()
        let habit = addHabit("Read", schedule: .all, firstDay: today.adding(days: -10), in: context)
        habit.setRule(target: 1, schedule: [], from: today.adding(days: 2))
        #expect(habit.scheduleMask == 0)
        #expect(!habit.hasNoSetDays(on: today))
        #expect(habit.hasNoSetDays(on: today.adding(days: 2)))
    }
}

@Suite("Symbols")
struct SymbolCatalogTests {
    /// People search by what a habit is for, as well as by what a symbol shows.
    @Test func searchFindsIntentWords() {
        for word in ["teeth", "meds", "medication", "therapy", "chores", "laundry", "sleep"] {
            #expect(!SymbolCatalog.search(word).isEmpty, "\(word)")
        }
        #expect(SymbolCatalog.search("teeth").contains { $0.name == "hands.and.sparkles" })
    }

    @Test func elevenGroupsOfTwelveWithNoRepeats() {
        let groups = SymbolCatalog.groups
        #expect(groups.count == 11)
        #expect(groups.allSatisfy { $0.symbols.count == 12 })
        let names = SymbolCatalog.symbols.map(\.name)
        #expect(Set(names).count == 132)
        #expect(SymbolCatalog.firstRow.allSatisfy { names.contains($0) })
        #expect(groups.map(\.title) == groups.map(\.title).sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    /// A missing symbol draws as a blank space with no error, so every name is checked on the platform
    /// the tests run on. `swift test` covers macOS; run the package on the pinned simulator for iOS.
    @Test func everySymbolExistsOnThisSystem() {
        #if canImport(UIKit)
        let missing = SymbolCatalog.symbols.map(\.name).filter { UIImage(systemName: $0) == nil }
        #else
        let missing = SymbolCatalog.symbols.map(\.name).filter { NSImage(systemSymbolName: $0, accessibilityDescription: nil) == nil }
        #endif
        #expect(missing.isEmpty, "\(missing)")
    }

    @Test func searchMatchesLabelsAndGroups() {
        #expect(SymbolCatalog.search("dice").map(\.name) == ["dice"])
        #expect(SymbolCatalog.search("Play").count == 12)
        #expect(SymbolCatalog.search("").count == 132)
    }
}

/// The agreed rule for a habit with no set days, from the behaviour, wording and accessibility lenses.
@Suite("No set days: marks and runs")
@MainActor
struct NoSetDaysMarksAndRunsTests {
    @Test func marksForNoSetDays() throws {
        let context = try makeContext()
        let habit = addHabit("Read", schedule: [], firstDay: today.adding(days: -10), in: context)
        #expect(habit.state(on: today, today: today) == .noSetDays)
        #expect(habit.state(on: today.adding(days: -2), today: today) == .blank)
        #expect(habit.state(on: today.adding(days: -2), today: today, showDaysNotLogged: true) == .blank)
        #expect(habit.state(on: today.adding(days: 1), today: today) == .blank)
        #expect(habit.state(on: today.adding(days: -11), today: today) == .blank)
        try log(.markDone, habit, day: today.adding(days: -3), context)
        #expect(habit.state(on: today.adding(days: -3), today: today) == .done)
        let pause = Pause(habit: habit, start: today.adding(days: -5), end: today.adding(days: -4), reason: .manual)
        context.insert(pause)
        try log(.markDone, habit, day: today.adding(days: -4), context)
        #expect(habit.state(on: today.adding(days: -4), today: today) == .loggedWhilePaused)
        #expect(habit.state(on: today.adding(days: -5), today: today) == .paused)
    }

    @Test func aCountedLogIsPartDoneOrDoneByTheTarget() throws {
        let context = try makeContext()
        let water = addHabit("Water", .counted, target: 8, unit: "glasses", schedule: [], in: context)
        try log(.add(3), water, day: today, context)
        #expect(water.state(on: today, today: today) == .partDone)
        try log(.add(5), water, day: today, context)
        #expect(water.state(on: today, today: today) == .done)
    }

    @Test func aCountedNoSetDaysHabitOverTargetAfterUndoAndAfterATargetChange() throws {
        let context = try makeContext()
        let water = addHabit("Water", .counted, target: 8, unit: "glasses", schedule: [], firstDay: today.adding(days: -5), in: context)
        try log(.add(3), water, day: today, context)
        try log(.add(5), water, day: today, context)
        try log(.add(4), water, day: today, context)
        #expect(water.state(on: today, today: today) == .done)
        try log(.takeAway(12), water, day: today, context)
        #expect(water.state(on: today, today: today) == .noSetDays)

        try log(.add(8), water, day: today.adding(days: -1), context)
        try log(.add(8), water, day: today, context)
        water.setRule(target: 20, schedule: [], from: today)
        #expect(water.state(on: today, today: today) == .partDone)
        #expect(water.state(on: today.adding(days: -1), today: today) == .done)
    }

    /// Recorded behaviour, put to the behavioural scientist: under no set days, two paused logs twenty
    /// days apart count as a run of 2, because a paused log extends a run (invariant 3) and no day between
    /// them can break it.
    @Test func pausedLogsApartUnderNoSetDaysChain() throws {
        let context = try makeContext()
        let habit = addHabit("Read", schedule: [], firstDay: today.adding(days: -60), in: context)
        for offset in [-40, -20] {
            context.insert(Pause(habit: habit, start: today.adding(days: offset), end: today.adding(days: offset), reason: .manual))
            try log(.markDone, habit, day: today.adding(days: offset), context)
        }
        #expect(habit.runSummary(today: today).longest == 2)
    }

    /// Settled by the behavioural scientist and the returning user: choosing no set days on a day already
    /// logged applies from tomorrow, so Longest run never falls. Any other edit applies from today.
    @Test func choosingNoSetDaysAfterLoggingTodayAppliesFromTomorrow() throws {
        let context = try makeContext()
        let habit = addHabit("Walk", schedule: .all, firstDay: today.adding(days: -20), in: context)
        for offset in -9 ... 0 { try log(.markDone, habit, day: today.adding(days: offset), context) }
        #expect(habit.noSetDaysWaitsForTomorrow([], today: today))
        #expect(habit.applyEdit(target: 1, schedule: [], today: today) == today.adding(days: 1))
        #expect(habit.rule(on: today).schedule == .all)
        #expect(habit.rule(on: today.adding(days: 1)).schedule.isEmpty)
        #expect(habit.ruleForEditing(today: today).schedule.isEmpty)
        #expect(habit.runSummary(today: today).longest == 10)
        #expect(habit.runSummary(today: today.adding(days: 1)).longest == 10)
    }

    @Test func choosingNoSetDaysWithNoLogTodayAppliesFromToday() throws {
        let context = try makeContext()
        let habit = addHabit("Walk", schedule: .all, firstDay: today.adding(days: -20), in: context)
        try log(.markDone, habit, day: today.adding(days: -1), context)
        #expect(!habit.noSetDaysWaitsForTomorrow([], today: today))
        #expect(habit.applyEdit(target: 1, schedule: [], today: today) == today)
        #expect(habit.state(on: today, today: today) == .noSetDays)
    }

    @Test func loweringTargetOnALoggedDayAppliesFromToday() throws {
        let context = try makeContext()
        let water = addHabit("Water", .counted, target: 8, schedule: .all, firstDay: today.adding(days: -5), in: context)
        try log(.add(5), water, day: today, context)
        #expect(water.applyEdit(target: 5, schedule: .all, today: today) == today)
        #expect(water.state(on: today, today: today) == .done)
        // A target change and no set days together: the target applies today, the days tomorrow.
        #expect(water.applyEdit(target: 4, schedule: [], today: today) == today.adding(days: 1))
        #expect(water.rule(on: today).target == 4)
        #expect(water.rule(on: today).schedule == .all)
    }

    /// Several edits on one day never stack: back to every day removes the change waiting for tomorrow.
    @Test func editsOnOneDayEndWithTheLastChoice() throws {
        let context = try makeContext()
        let habit = addHabit("Walk", schedule: .all, firstDay: today.adding(days: -20), in: context)
        for offset in -9 ... 0 { try log(.markDone, habit, day: today.adding(days: offset), context) }
        habit.applyEdit(target: 1, schedule: [], today: today)
        habit.applyEdit(target: 1, schedule: .all, today: today)
        #expect(habit.rule(on: today.adding(days: 1)).schedule == .all)
        #expect(habit.runSummary(today: today).longest == 10)
        habit.applyEdit(target: 1, schedule: [], today: today)
        #expect(habit.rule(on: today.adding(days: 1)).schedule.isEmpty)
        #expect(habit.runSummary(today: today).longest == 10)
    }

    /// The returning user's guard: a paused log under no set days never lowers a run.
    @Test func pausedLogUnderNoSetDaysNeverLowersLongest() throws {
        let context = try makeContext()
        let habit = addHabit("Walk", schedule: .all, firstDay: today.adding(days: -40), in: context)
        for offset in -40 ... -31 { try log(.markDone, habit, day: today.adding(days: offset), context) }
        habit.setRule(target: 1, schedule: [], from: today.adding(days: -30))
        context.insert(Pause(habit: habit, start: today.adding(days: -5), end: today.adding(days: -5), reason: .manual))
        try log(.markDone, habit, day: today.adding(days: -5), context)
        #expect(habit.runSummary(today: today).longest >= 10)
    }

    /// Seven different labels in the day buttons, in every locale, right-to-left and CJK included.
    @Test(arguments: ["en_GB", "en_US", "fr_FR", "de_DE", "ar", "ar_SA", "he_IL", "fa_IR", "zh_Hans", "ja_JP", "ko_KR", "ru_RU", "hi_IN", "th_TH"])
    func dayButtonTextsDifferInEveryLocale(identifier: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: identifier)
        let texts = WeekdayText.buttonTexts(calendar: calendar)
        #expect(texts.count == 7)
        #expect(Set(texts).count == 7, "\(identifier): \(texts)")
    }

    /// A no-set-days habit is never owed, so before a log its row shows the target alone.
    @Test func noSetDaysRowShowsTheTargetAloneBeforeALog() {
        let en = Locale(identifier: "en_GB")
        #expect(CountText.todayLine(total: 0, target: 20, unit: "minutes", noSetDays: true, locale: en) == "Target 20 minutes")
        #expect(CountText.todayLine(total: 10, target: 20, unit: "minutes", noSetDays: true, locale: en) == "10 of 20 minutes")
        #expect(CountText.todayLine(total: 0, target: 20, unit: "minutes", noSetDays: false, locale: en) == "0 of 20 minutes")
        #expect(CountText.todayLine(total: 0, target: 20, unit: "", noSetDays: true, locale: en) == "Target 20")
    }

    @Test func aRuleChangeMidWeekKeepsEachSideItsOwnMark() throws {
        let context = try makeContext()
        let habit = addHabit("Walk", schedule: .all, firstDay: today.adding(days: -20), in: context)
        habit.setRule(target: 1, schedule: [], from: today.adding(days: -3))
        #expect(habit.state(on: today.adding(days: -4), today: today, showDaysNotLogged: true) == .notLogged)
        #expect(habit.state(on: today.adding(days: -3), today: today, showDaysNotLogged: true) == .blank)
        #expect(habit.state(on: today, today: today) == .noSetDays)
    }

    @Test func logsMonthsApartAreNotARun() throws {
        let context = try makeContext()
        let habit = addHabit("Read", schedule: [], firstDay: today.adding(days: -60), in: context)
        for offset in [-40, -20, 0] { try log(.markDone, habit, day: today.adding(days: offset), context) }
        let runs = habit.runSummary(today: today)
        #expect(runs == RunSummary(current: 0, longest: 0, daysDone: 3, daysLogged: 3))

        let water = addHabit("Water", .counted, target: 8, schedule: [], firstDay: today.adding(days: -60), in: context)
        for offset in [-40, -20, 0] { try log(.add(1), water, day: today.adding(days: offset), context) }
        #expect(water.runSummary(today: today) == RunSummary(current: 0, longest: 0, daysDone: 0, daysLogged: 3))
    }

    /// Invariant 3 holds under no set days: a paused day with a log extends a run.
    @Test func aPausedDayWithALogExtendsARunUnderNoSetDays() throws {
        let context = try makeContext()
        let habit = addHabit("Read", schedule: [], firstDay: today.adding(days: -60), in: context)
        context.insert(Pause(habit: habit, start: today.adding(days: -1), end: today, reason: .manual))
        try log(.markDone, habit, day: today.adding(days: -1), context)
        try log(.markDone, habit, day: today, context)
        let runs = habit.runSummary(today: today)
        #expect(runs.current == 2)
        #expect(runs.longest == 2)
    }

    @Test func aRunFromSetDaysIsKeptThroughNoSetDays() throws {
        let context = try makeContext()
        let habit = addHabit("Walk", schedule: .all, firstDay: today.adding(days: -30), in: context)
        for offset in -30 ... -20 { try log(.markDone, habit, day: today.adding(days: offset), context) }
        habit.setRule(target: 1, schedule: [], from: today.adding(days: -19))
        for offset in -19 ... 0 { try log(.markDone, habit, day: today.adding(days: offset), context) }
        let runs = habit.runSummary(today: today)
        #expect(runs.current == 11)
        #expect(runs.longest == 11)
        #expect(runs.daysLogged == 31)
    }

    @Test func setDaysToNoneAndBackKeepsTheRun() throws {
        let context = try makeContext()
        let weekdays = Weekdays(rawValue: 0b0111110)
        // Today is a Saturday. Monday to Friday until day -19, then no days, then Monday to Friday from day -1.
        let habit = addHabit("Walk", schedule: weekdays, firstDay: today.adding(days: -30), in: context)
        for offset in -30 ... -20 where weekdays.contains(today.adding(days: offset)) {
            try log(.markDone, habit, day: today.adding(days: offset), context)
        }
        let before = habit.runSummary(today: today.adding(days: -20)).current
        habit.setRule(target: 1, schedule: [], from: today.adding(days: -19))
        habit.setRule(target: 1, schedule: weekdays, from: today.adding(days: -1))
        try log(.markDone, habit, day: today.adding(days: -1), context)
        #expect(habit.runSummary(today: today).current == before + 1)
    }
}
