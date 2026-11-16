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
