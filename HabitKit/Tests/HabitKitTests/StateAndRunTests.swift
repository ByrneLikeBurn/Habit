import Foundation
import Testing
@testable import HabitKit

private func day(_ total: Int, kind: HabitKind = .binary, target: Int? = 1, scheduled: Bool = true, paused: Bool = false, _ relation: DayRelation = .past) -> DayInput {
    DayInput(total: total, kind: kind, target: target, scheduled: scheduled, paused: paused, relation: relation)
}

@Suite("Day state")
struct DayStateTests {
    @Test func yesOrNo() {
        #expect(DayState.resolve(day(1)) == .done)
        #expect(DayState.resolve(day(3)) == .done)
        #expect(DayState.resolve(day(0)) == .blank)
    }

    @Test func counted() {
        #expect(DayState.resolve(day(3, kind: .counted, target: 8)) == .partDone)
        #expect(DayState.resolve(day(8, kind: .counted, target: 8)) == .done)
        #expect(DayState.resolve(day(12, kind: .counted, target: 8)) == .done)
    }

    @Test func countedWithNoTargetIsDoneWithAnyLog() {
        #expect(DayState.resolve(day(1, kind: .counted, target: nil)) == .done)
        #expect(DayState.resolve(day(0, kind: .counted, target: nil)) == .blank)
    }

    @Test func aLogOnAPausedDayIsLoggedWhilePausedWhateverTheCount() {
        #expect(DayState.resolve(day(1, kind: .counted, target: 8, paused: true)) == .loggedWhilePaused)
        #expect(DayState.resolve(day(8, kind: .counted, target: 8, paused: true)) == .loggedWhilePaused)
        #expect(DayState.resolve(day(0, paused: true)) == .paused)
    }

    @Test func aLogOnAnOffScheduleDayIsCredited() {
        #expect(DayState.resolve(day(1, scheduled: false)) == .loggedOffSchedule)
        #expect(DayState.resolve(day(0, scheduled: false)) == .offSchedule)
        #expect(DayState.resolve(day(0, scheduled: false, .future)) == .blank)
    }

    @Test func aPastDayWithNoLogDrawsNothingUnlessTheUserOptsIn() {
        #expect(DayState.resolve(day(0, .past)) == .blank)
        #expect(DayState.resolve(day(0, .past), showDaysNotLogged: true) == .notLogged)
        #expect(DayState.resolve(day(0, .today), showDaysNotLogged: true) == .blank)
        // A day to come draws nothing.
        #expect(DayState.resolve(day(0, .future)) == .blank)
    }
}

@Suite("Runs")
struct RunTests {
    // Invariant 3, asserted directly.
    @Test func aPausedDayWithNoLogNeitherBreaksNorExtends() {
        #expect(Runs.effect(of: day(0, paused: true)) == .neutral)
        let summary = Runs.summarise([day(1), day(1), day(0, paused: true), day(1, .today)])
        #expect(summary.current == 3)
        #expect(summary.longest == 3)
    }

    @Test func aPausedDayWithALogExtends() {
        #expect(Runs.effect(of: day(1, paused: true)) == .extend)
        let summary = Runs.summarise([day(1), day(1, paused: true), day(1, .today)])
        #expect(summary.current == 3)
    }

    @Test func aRunOfOnlyPausedDaysIsZero() {
        let summary = Runs.summarise([day(0, paused: true), day(0, paused: true), day(0, paused: true, .today)])
        #expect(summary.current == 0 && summary.longest == 0)
    }

    @Test func aPartDoneDayNeverBreaksARun() {
        let summary = Runs.summarise([
            day(8, kind: .counted, target: 8),
            day(3, kind: .counted, target: 8),
            day(8, kind: .counted, target: 8, .today),
        ])
        #expect(summary.current == 3)
        #expect(summary.daysDone == 2)
        #expect(summary.daysLogged == 3)
    }

    @Test func anOffScheduleDayIsNeutralAndALogOnItExtends() {
        #expect(Runs.summarise([day(1), day(0, scheduled: false), day(1, .today)]).current == 2)
        #expect(Runs.summarise([day(1), day(1, scheduled: false), day(1, .today)]).current == 3)
    }

    @Test func aScheduledPastDayWithNoLogBreaksTheCurrentRunButNotTheLongest() {
        let summary = Runs.summarise([day(1), day(1), day(1), day(0), day(1, .today)])
        #expect(summary.current == 1)
        #expect(summary.longest == 3)
    }

    @Test func anEmptyTodayDoesNotBreakTheRun() {
        #expect(Runs.summarise([day(1), day(1), day(0, .today)]).current == 2)
    }
}
