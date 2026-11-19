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

@MainActor
private func shared(_ context: ModelContext) throws -> [Pause] { try PauseWriter.sharedPauses(in: context) }

/// The one ending rule and the lines on Today, from docs/spec.md "Milestone 3 screens".
@Suite("Pausing: Today's line and the ending rule")
@MainActor
struct PauseStatusTests {
    @Test func pauseEverythingThenUndoLeavesNoTrace() throws {
        let context = try makeContext()
        let habit = addHabit("Read", in: context)
        let pause = try PauseWriter.pauseEverything(today: today, in: context)
        #expect(SharedPauseStatus.of(try shared(context), today: today) == .everything(startedToday: true))
        #expect(habit.state(on: today, today: today, sharedPauses: try shared(context)) == .paused)
        // "Undo pause": a pause whose first day is today is removed whole.
        #expect(try PauseWriter.end(pause, today: today, in: context) == .removed)
        #expect(try shared(context).isEmpty)
        #expect(SharedPauseStatus.of(try shared(context), today: today) == .none)
        #expect(habit.state(on: today, today: today, sharedPauses: try shared(context)) == .blank)
    }

    /// "Undo pause" on Pause everything, made by mistake during dated pauses: the dates keep their last day.
    @Test func undoPauseEverythingLeavesDatedPausesAlone() throws {
        let context = try makeContext()
        let dates = try PauseWriter.addDates(first: today.adding(days: -4), last: today.adding(days: 13), in: context)
        try PauseWriter.pauseEverything(today: today, in: context)
        let endings = try PauseWriter.endShared(today: today, in: context)
        #expect(endings.count == 1)
        #expect(endings.first?.1 == .removed)
        #expect(dates.endDay == today.adding(days: 13).rawValue)
        #expect(SharedPauseStatus.of(try shared(context), today: today) == .until(today.adding(days: 13), startedToday: false))
        // With no Pause everything, Resume tomorrow ends the dates.
        #expect(try PauseWriter.endShared(today: today, in: context).count == 1)
        #expect(dates.endDay == today.rawValue)
    }

    @Test func resumeTomorrowKeepsTodayPausedAndKeepPausedOpensItAgain() throws {
        let context = try makeContext()
        let habit = addHabit("Read", in: context)
        let pause = Pause(habit: nil, start: today.adding(days: -3), end: nil, reason: .gentle)
        context.insert(pause)
        #expect(SharedPauseStatus.of(try shared(context), today: today) == .everything(startedToday: false))
        #expect(try PauseWriter.end(pause, today: today, in: context) == .endsToday(previousEnd: nil))
        #expect(pause.endDay == today.rawValue)
        #expect(SharedPauseStatus.of(try shared(context), today: today) == .resumesTomorrow(canKeep: true))
        #expect(habit.state(on: today, today: today, sharedPauses: try shared(context)) == .paused)
        #expect(habit.state(on: today.adding(days: 1), today: today.adding(days: 1), sharedPauses: try shared(context)) == .blank)
        // "Keep paused", or turning the switch on again, opens the same pause.
        let again = try PauseWriter.pauseEverything(today: today, in: context)
        #expect(again.id == pause.id)
        #expect(pause.endDay == nil)
        #expect(try shared(context).count == 1)
    }

    @Test func datesShowTheirLastDayAndEverythingOutranksThem() throws {
        let context = try makeContext()
        try PauseWriter.addDates(first: today.adding(days: -2), last: DayKey(rawValue: 20261127), in: context)
        #expect(SharedPauseStatus.of(try shared(context), today: today) == .until(DayKey(rawValue: 20261127), startedToday: false))
        try PauseWriter.pauseEverything(today: today, in: context)
        #expect(SharedPauseStatus.of(try shared(context), today: today) == .everything(startedToday: true))
    }

    @Test func overlappingDatesAreReadAsOne() throws {
        let context = try makeContext()
        try PauseWriter.addDates(first: today.adding(days: -2), last: today.adding(days: 2), in: context)
        try PauseWriter.addDates(first: today, last: today.adding(days: 6), in: context)
        #expect(SharedPauseStatus.of(try shared(context), today: today) == .until(today.adding(days: 6), startedToday: false))
    }

    @Test func aDatedPauseEndingTodayResumesTomorrowWithNoKeep() throws {
        let context = try makeContext()
        try PauseWriter.addDates(first: today.adding(days: -4), last: today, in: context)
        #expect(SharedPauseStatus.of(try shared(context), today: today) == .resumesTomorrow(canKeep: false))
    }

    @Test func resumingDatesThatHaveStartedEndsThemTodayAndKeepRestoresTheLastDay() throws {
        let context = try makeContext()
        let pause = try PauseWriter.addDates(first: today.adding(days: -2), last: today.adding(days: 5), in: context)
        let ending = try PauseWriter.end(pause, today: today, in: context)
        #expect(ending == .endsToday(previousEnd: today.adding(days: 5)))
        try PauseWriter.keep(pause, previousEnd: today.adding(days: 5), in: context)
        #expect(pause.end == today.adding(days: 5))
    }

    @Test func datesNotYetStartedAreRemovedWhole() throws {
        let context = try makeContext()
        let pause = try PauseWriter.addDates(first: today.adding(days: 6), last: today.adding(days: 13), in: context)
        #expect(SharedPauseStatus.of(try shared(context), today: today) == .none)
        #expect(try PauseWriter.end(pause, today: today, in: context) == .removed)
        #expect(try shared(context).isEmpty)
    }

    @Test func aHabitAddedDuringAPauseIsPausedToo() throws {
        let context = try makeContext()
        try PauseWriter.pauseEverything(today: today.adding(days: -2), in: context)
        let habit = addHabit("Stretch", firstDay: today, in: context)
        #expect(habit.state(on: today, today: today, sharedPauses: try shared(context)) == .paused)
    }
}

@Suite("Pausing: one habit")
@MainActor
struct HabitPauseTests {
    @Test func pauseThisHabitUndoAndResume() throws {
        let context = try makeContext()
        let read = addHabit("Read", in: context)
        let walk = addHabit("Walk", in: context)
        let pause = try PauseWriter.pause(read, today: today, in: context)
        #expect(read.ownPauseStatus(today: today) == .paused(since: today, startedToday: true))
        #expect(read.state(on: today, today: today) == .paused)
        #expect(walk.state(on: today, today: today) == .blank)
        // Today's line speaks only of pauses with no habit.
        #expect(SharedPauseStatus.of(try shared(context), today: today) == .none)
        #expect(try PauseWriter.end(pause, today: today, in: context) == .removed)
        #expect(read.ownPauseStatus(today: today) == .none)

        let older = Pause(habit: read, start: today.adding(days: -4), end: nil, reason: .manual)
        context.insert(older)
        #expect(read.ownPauseStatus(today: today) == .paused(since: today.adding(days: -4), startedToday: false))
        try PauseWriter.end(older, today: today, in: context)
        #expect(read.ownPauseStatus(today: today) == .resumesTomorrow)
        #expect(read.state(on: today.adding(days: 1), today: today.adding(days: 1)) == .blank)
        // "Keep paused" opens it again rather than adding a second pause.
        let kept = try PauseWriter.pause(read, today: today, in: context)
        #expect(kept.id == older.id)
        #expect(read.ownPauseStatus(today: today) == .paused(since: today.adding(days: -4), startedToday: false))
    }

    /// Invariant 3, through the writer: a paused day with no log neither breaks nor extends a run.
    /// A paused set day with a log extends it.
    @Test func pausedDaysLeaveTheRunAsItWas() throws {
        let context = try makeContext()
        let habit = addHabit("Read", in: context)
        for offset in -9 ... -5 { try log(.tap, habit, day: today.adding(days: offset), context) }
        context.insert(Pause(habit: habit, start: today.adding(days: -4), end: today.adding(days: -1), reason: .manual))
        try log(.tap, habit, day: today.adding(days: -2), context)
        try log(.tap, habit, day: today, context)
        let runs = habit.runSummary(today: today)
        // Five days, then -4, -3 and -1 paused with no log (neutral), -2 logged while paused (extends), then today.
        #expect(runs.current == 7)
        #expect(runs.longest == 7)
    }

    @Test func aCountedRowWhilePausedNamesTheAmountAlone() {
        let en = Locale(identifier: "en_GB")
        #expect(CountText.todayLine(total: 0, target: 8, unit: "glasses", noSetDays: false, paused: true, locale: en) == "0 glasses")
        #expect(CountText.todayLine(total: 3, target: 8, unit: "glasses", noSetDays: false, paused: true, locale: en) == "3 glasses")
        #expect(CountText.todayLine(total: 3, target: 8, unit: "glasses", noSetDays: false, paused: false, locale: en) == "3 of 8 glasses")
    }
}

@Suite("Pausing: dates form")
@MainActor
struct PauseImpactTests {
    @Test func newDatesCountTheLoggedDaysThatChangeMark() throws {
        let context = try makeContext()
        let read = addHabit("Read", in: context)
        let walk = addHabit("Walk", in: context)
        try log(.tap, read, day: today.adding(days: -5), context)
        try log(.tap, read, day: today.adding(days: -4), context)
        try log(.tap, walk, day: today.adding(days: -10), context)
        let impact = PauseImpact.of(old: nil, new: today.adding(days: -6)...today.adding(days: -3),
                                    habits: [read, walk], otherShared: [], today: today)
        #expect(impact.logsGainPause == 2)
        #expect(impact.daysGainPause == 4)
        #expect(impact.logsLosePause == 0)
    }

    @Test func changingDatesCountsGainAndLossAndSkipsTheFuture() throws {
        let context = try makeContext()
        let read = addHabit("Read", in: context)
        try log(.tap, read, day: today.adding(days: -5), context)
        let impact = PauseImpact.of(old: today.adding(days: -6)...today.adding(days: -4),
                                    new: today.adding(days: -2)...today.adding(days: 5),
                                    habits: [read], otherShared: [], today: today)
        #expect(impact.logsLosePause == 1)
        #expect(impact.daysLosePause == 3)
        // Calendar days -2 to 5, today and later included.
        #expect(impact.daysGainPause == 8)
    }

    @Test func daysAnotherPauseCoversDoNotChange() throws {
        let context = try makeContext()
        let read = addHabit("Read", in: context)
        try log(.tap, read, day: today.adding(days: -3), context)
        let other = Pause(habit: nil, start: today.adding(days: -3), end: today.adding(days: -3), reason: .vacation)
        context.insert(other)
        let impact = PauseImpact.of(old: nil, new: today.adding(days: -3)...today.adding(days: -3),
                                    habits: [read], otherShared: [other], today: today)
        #expect(impact == .none)
    }
}

@Suite("Pausing: bring back")
@MainActor
struct BringBackPauseTests {
    /// The gate from the behavioural scientist and the returning user: a habit archived and brought back with
    /// the offered pause keeps its run.
    @Test func bringingBackWithThePauseKeepsTheRun() throws {
        let context = try makeContext()
        let habit = addHabit("Read", in: context)
        for offset in -12 ... -6 { try log(.tap, habit, day: today.adding(days: offset), context) }
        let archivedOn = today.adding(days: -5)
        let span = try #require(PauseWriter.archivedSpan(of: habit, archivedOn: archivedOn, today: today))
        #expect(span == archivedOn...today.adding(days: -1))
        #expect(habit.runSummary(today: today).current == 0)
        try PauseWriter.pauseArchivedSpan(habit, span: span, in: context)
        try log(.tap, habit, day: today, context)
        let runs = habit.runSummary(today: today)
        #expect(runs.current == 8)
        #expect(runs.longest == 8)
    }

    @Test func archivedTodayHasNothingToPause() throws {
        let context = try makeContext()
        let habit = addHabit("Read", in: context)
        #expect(PauseWriter.archivedSpan(of: habit, archivedOn: today, today: today) == nil)
    }
}

@Suite("Widget snapshot")
@MainActor
struct WidgetSnapshotTests {
    /// The gate from the senior software engineer and QA: the widget follows the no-set-days rule.
    @Test func aNoSetDaysHabitShowsEveryDayWithTheDotUntilLogged() throws {
        let context = try makeContext()
        let guitar = addHabit("Guitar", .counted, target: 20, unit: "minutes", schedule: [], in: context)
        let read = addHabit("Read", schedule: Weekdays(weekday: 2), in: context)
        var snapshot = WidgetSnapshot.make(habits: [guitar, read], sharedPauses: [], today: today, locale: Locale(identifier: "en_GB"))
        #expect(snapshot.rows.map(\.name) == ["Guitar"])
        #expect(snapshot.rows.first?.state == .noSetDays)
        #expect(snapshot.rows.first?.countLine == "Target 20 minutes")
        try log(.add(10), guitar, day: today, context)
        snapshot = WidgetSnapshot.make(habits: [guitar, read], sharedPauses: [], today: today, locale: Locale(identifier: "en_GB"))
        #expect(snapshot.rows.first?.state == .partDone)
        #expect(snapshot.rows.first?.total == 10)
        try log(.add(10), guitar, day: today, context)
        snapshot = WidgetSnapshot.make(habits: [guitar, read], sharedPauses: [], today: today)
        #expect(snapshot.rows.first?.state == .done)
    }

    @Test func rowsKeepTodaysOrderAndTheHeaderSaysPaused() throws {
        let context = try makeContext()
        let a = addHabit("A", in: context), b = addHabit("B", in: context)
        a.sortIndex = 1; b.sortIndex = 0
        let water = addHabit("Water", .counted, target: 8, unit: "glasses", in: context)
        water.sortIndex = 2
        try PauseWriter.pauseEverything(today: today, in: context)
        try log(.tap, a, day: today, context)
        let snapshot = WidgetSnapshot.make(habits: [a, b, water], sharedPauses: try shared(context), today: today, locale: Locale(identifier: "en_GB"))
        #expect(snapshot.rows.map(\.name) == ["B", "A", "Water"])
        #expect(snapshot.paused)
        #expect(snapshot.rows.map(\.state) == [.paused, .loggedWhilePaused, .paused])
        #expect(snapshot.rows.last?.countLine == "0 glasses")
    }

    /// The intent carries the day the widget showed and the total it drew. On a mismatch it writes nothing.
    @Test func aStaleWidgetTapWritesNothing() {
        #expect(WidgetSnapshot.accepts(shownDay: today.rawValue, shownTotal: 0, today: today, currentTotal: 0))
        // Drawn yesterday, tapped after the day turned over.
        #expect(!WidgetSnapshot.accepts(shownDay: today.adding(days: -1).rawValue, shownTotal: 0, today: today, currentTotal: 0))
        // Logged in the app since the widget drew: a tap would take that log back.
        #expect(!WidgetSnapshot.accepts(shownDay: today.rawValue, shownTotal: 0, today: today, currentTotal: 1))
    }

    @Test func noHabitsAtAll() throws {
        let snapshot = WidgetSnapshot.make(habits: [], sharedPauses: [], today: today)
        #expect(!snapshot.hasHabits)
        #expect(snapshot.rows.isEmpty)
    }

    /// The timeline has an entry at each day start. Pause edges are day starts, so they are covered.
    @Test(arguments: [0, 4, 6])
    func entriesFallOnDayStarts(hour: Int) {
        let london = TimeZone(identifier: "Europe/London")!
        // Saturday 14 November 2026, 09:41.
        let clock = HabitClock.frozen(at: Date(timeIntervalSince1970: 1_794_649_260), timeZone: london, dayStartHour: hour)
        let dates = WidgetSnapshot.entryDates(clock: clock, days: 2)
        #expect(dates.count == 3)
        #expect(clock.dayKey(for: dates[1]) == DayKey(rawValue: 20261115))
        #expect(clock.dayKey(for: dates[1].addingTimeInterval(-1)) == DayKey(rawValue: 20261114))
        #expect(clock.dayKey(for: dates[2]) == DayKey(rawValue: 20261116))
    }

    /// Before the day start, today is still yesterday, and the next entry is this morning's day start.
    @Test func beforeTheDayStartTheNextEntryIsThisMorning() {
        let london = TimeZone(identifier: "Europe/London")!
        // Saturday 14 November 2026, 03:00, with the day starting at 06:00.
        let clock = HabitClock.frozen(at: Date(timeIntervalSince1970: 1_794_625_200), timeZone: london, dayStartHour: 6)
        let dates = WidgetSnapshot.entryDates(clock: clock, days: 2)
        #expect(clock.dayKey(for: dates[0]) == DayKey(rawValue: 20261113))
        #expect(clock.dayKey(for: dates[1]) == DayKey(rawValue: 20261114))
        #expect(dates[1].timeIntervalSince(dates[0]) == 3 * 3600)
    }

    /// The night clocks go back: 01:00 happens twice. The day turns over once.
    @Test func aDayStartOnTheNightClocksGoBack() {
        let newYork = TimeZone(identifier: "America/New_York")!
        let saturdayEvening = Date(timeIntervalSince1970: 1_793_494_800) // 31 October 2026, 21:00 EDT
        let clock = HabitClock.frozen(at: saturdayEvening, timeZone: newYork, dayStartHour: 1)
        let dates = WidgetSnapshot.entryDates(clock: clock, days: 2)
        #expect(dates.count == 3)
        #expect(clock.dayKey(for: dates[1]) == DayKey(rawValue: 20261101))
        #expect(clock.dayKey(for: dates[2]) == DayKey(rawValue: 20261102))
        #expect(dates[2].timeIntervalSince(dates[1]) == 25 * 3600)
    }

    @Test func aDayStartOnTheDaylightSavingNight() {
        // Sunday 29 March 2026 in London: 01:00 does not exist. The day still turns over once.
        let london = TimeZone(identifier: "Europe/London")!
        let saturdayEvening = Date(timeIntervalSince1970: 1_774_731_600) // 28 March 2026, 21:00 GMT
        let clock = HabitClock.frozen(at: saturdayEvening, timeZone: london, dayStartHour: 1)
        let next = clock.nextDayStart(after: clock.now())
        #expect(clock.dayKey(for: next) == DayKey(rawValue: 20260329))
        #expect(next.timeIntervalSince(saturdayEvening) < 6 * 3600)
    }
}

/// Travel across a pause edge, owed from docs/spec.md "Milestone 3 screens". A pause covers whole days,
/// read in the time zone the device is in now.
@Suite("Pausing: travel across a pause edge")
@MainActor
struct PauseTravelTests {
    private func clock(_ zone: String, at date: Date) -> HabitClock {
        HabitClock.frozen(at: date, timeZone: TimeZone(identifier: zone)!, dayStartHour: 4)
    }

    @Test func flyingEastPassesTheLastPausedDayEarly() throws {
        let context = try makeContext()
        let habit = addHabit("Read", in: context)
        try PauseWriter.addDates(first: DayKey(rawValue: 20261110), last: DayKey(rawValue: 20261114), in: context)
        // 23:30 in London on Saturday 14 November, the last paused day.
        let instant = Date(timeIntervalSince1970: 1_794_699_000)
        let london = clock("Europe/London", at: instant)
        let tokyo = clock("Asia/Tokyo", at: instant)
        #expect(london.today == DayKey(rawValue: 20261114))
        #expect(SharedPauseStatus.of(try shared(context), today: london.today) == .resumesTomorrow(canKeep: false))
        #expect(habit.state(on: london.today, today: london.today, sharedPauses: try shared(context)) == .paused)
        // In Tokyo it is already 08:30 on Sunday: the pause is over there.
        #expect(tokyo.today == DayKey(rawValue: 20261115))
        #expect(SharedPauseStatus.of(try shared(context), today: tokyo.today) == .none)
        #expect(habit.state(on: tokyo.today, today: tokyo.today, sharedPauses: try shared(context)) == .blank)
    }

    @Test func flyingWestKeepsTheDayBeforeTheFirstPausedDayUnpaused() throws {
        let context = try makeContext()
        let habit = addHabit("Read", in: context)
        try PauseWriter.addDates(first: DayKey(rawValue: 20261115), last: DayKey(rawValue: 20261120), in: context)
        // 05:00 in London on Sunday 15 November, the first paused day. In New York it is 00:00, before the 04:00
        // day start, so it is still Saturday there, which is not paused.
        let instant = Date(timeIntervalSince1970: 1_794_718_800)
        let london = clock("Europe/London", at: instant)
        let newYork = clock("America/New_York", at: instant)
        #expect(london.today == DayKey(rawValue: 20261115))
        #expect(newYork.today == DayKey(rawValue: 20261114))
        #expect(SharedPauseStatus.of(try shared(context), today: london.today) == .until(DayKey(rawValue: 20261120), startedToday: true))
        #expect(SharedPauseStatus.of(try shared(context), today: newYork.today) == .none)
        try log(.tap, habit, day: newYork.today, context)
        #expect(habit.state(on: newYork.today, today: newYork.today, sharedPauses: try shared(context)) == .done)
    }

    /// A log written for a paused day stays a paused day's log after travel moves today, so a run never jumps.
    @Test func aLogMadeOnAPausedDayKeepsItsMarkAfterTravel() throws {
        let context = try makeContext()
        let habit = addHabit("Read", in: context)
        try PauseWriter.addDates(first: today, last: today, in: context)
        try log(.tap, habit, day: today, context)
        let later = today.adding(days: 1)
        #expect(habit.state(on: today, today: later, sharedPauses: try shared(context)) == .loggedWhilePaused)
        #expect(habit.state(on: today, today: today.adding(days: -1), sharedPauses: try shared(context)) == .loggedWhilePaused)
    }
}
