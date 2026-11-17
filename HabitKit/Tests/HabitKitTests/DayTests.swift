import Foundation
import Testing
@testable import HabitKit

private func instant(_ iso: String) -> Date {
    try! Date(iso, strategy: .iso8601)
}

private let london = TimeZone(identifier: "Europe/London")!
private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
private let newYork = TimeZone(identifier: "America/New_York")!

@Suite("Day keys")
struct DayKeyTests {
    @Test func keyIsYearMonthDay() {
        let key = DayKey(year: 2026, month: 11, day: 14)
        #expect(key.rawValue == 20261114)
        #expect(key.year == 2026 && key.month == 11 && key.day == 14)
    }

    @Test func arithmeticCrossesMonthsYearsAndLeapDays() {
        #expect(DayKey(rawValue: 20261231).adding(days: 1) == DayKey(rawValue: 20270101))
        #expect(DayKey(rawValue: 20280228).adding(days: 1) == DayKey(rawValue: 20280229))
        #expect(DayKey(rawValue: 20270301).adding(days: -1) == DayKey(rawValue: 20270228))
        #expect(DayKey(rawValue: 20261101).days(to: DayKey(rawValue: 20261114)) == 13)
    }

    @Test func weekdayIsGregorian() {
        // 14 November 2026 is a Saturday.
        #expect(DayKey(rawValue: 20261114).weekday == 7)
        #expect(DayKey(rawValue: 20261115).weekday == 1)
    }

    @Test(arguments: [0, 4, 6])
    func dayTurnsOverAtTheDayStartHour(start: Int) {
        let before = HabitClock.frozen(at: instant(String(format: "2026-11-14T%02d:59:00Z", max(start - 1, 0))), timeZone: london, dayStartHour: start)
        let at = HabitClock.frozen(at: instant(String(format: "2026-11-14T%02d:00:00Z", start)), timeZone: london, dayStartHour: start)
        #expect(at.today == DayKey(rawValue: 20261114))
        if start == 0 {
            #expect(before.today == DayKey(rawValue: 20261114))
            #expect(!before.isBeforeDayStart)
        } else {
            #expect(before.today == DayKey(rawValue: 20261113))
            #expect(before.isBeforeDayStart)
        }
    }

    @Test func lateNightBelongsToTheDayBefore() {
        let clock = HabitClock.frozen(at: instant("2026-11-15T02:30:00Z"), timeZone: london, dayStartHour: 4)
        #expect(clock.today == DayKey(rawValue: 20261114))
        #expect(clock.isBeforeDayStart)
    }

    @Test func dayStartHourIsClamped() {
        #expect(HabitClock(dayStartHour: 12).dayStartHour == 8)
        #expect(HabitClock(dayStartHour: -3).dayStartHour == 0)
    }

    @Test func missingDayStartHourUsesTheNextValidTime() {
        // London springs forward on 29 March 2026: 01:00 GMT becomes 02:00 BST. 01:xx never happens.
        let justBefore = HabitClock.frozen(at: instant("2026-03-29T00:59:00Z"), timeZone: london, dayStartHour: 1)
        let justAfter = HabitClock.frozen(at: instant("2026-03-29T01:00:00Z"), timeZone: london, dayStartHour: 1)
        #expect(justBefore.today == DayKey(rawValue: 20260328))
        #expect(justAfter.today == DayKey(rawValue: 20260329))
    }

    @Test func repeatedHourOnFallBackStaysOnOneDay() {
        // New York falls back on 1 November 2026: 01:00 to 02:00 happens twice.
        let first = HabitClock.frozen(at: instant("2026-11-01T05:30:00Z"), timeZone: newYork, dayStartHour: 1)
        let second = HabitClock.frozen(at: instant("2026-11-01T06:30:00Z"), timeZone: newYork, dayStartHour: 1)
        #expect(first.today == DayKey(rawValue: 20261101))
        #expect(second.today == DayKey(rawValue: 20261101))
    }

    @Test func travelChangesTodayButNotStoredKeys() {
        let moment = instant("2026-11-14T20:00:00Z")
        let home = HabitClock.frozen(at: moment, timeZone: london)
        let away = HabitClock.frozen(at: moment, timeZone: tokyo)
        #expect(home.today == DayKey(rawValue: 20261114))
        #expect(away.today == DayKey(rawValue: 20261115))
    }
}

@Suite("Weekdays")
struct WeekdayTests {
    private var britain: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        calendar.firstWeekday = 2
        return calendar
    }

    @Test func labelsFollowTheCalendarAndUseTwoLettersWhereInitialsRepeat() {
        let labels = WeekdayText.labels(calendar: britain)
        #expect(labels.map(\.weekday) == [2, 3, 4, 5, 6, 7, 1])
        #expect(labels.map(\.short) == ["M", "Tu", "W", "Th", "F", "Sa", "Su"])
        #expect(labels.first?.full == "Monday")
    }

    @Test func sundayFirstCalendar() {
        var us = Calendar(identifier: .gregorian)
        us.locale = Locale(identifier: "en_US")
        us.firstWeekday = 1
        #expect(WeekdayText.labels(calendar: us).map(\.weekday) == [1, 2, 3, 4, 5, 6, 7])
    }

    @Test func sentences() {
        #expect(WeekdayText.sentence(for: .all, calendar: britain) == "Every day")
        var noThursday = Weekdays.all
        noThursday.remove(Weekdays(weekday: 5))
        #expect(WeekdayText.sentence(for: noThursday, calendar: britain) == "Every day except Thursday")
        let mwf = Weekdays([Weekdays(weekday: 2), Weekdays(weekday: 4), Weekdays(weekday: 6)])
        #expect(WeekdayText.sentence(for: mwf, calendar: britain) == "Monday, Wednesday and Friday")
        #expect(WeekdayText.sentence(for: [], calendar: britain) == "No set days")
    }

    @Test func maskBits() {
        #expect(Weekdays.all.rawValue == 127)
        #expect(Weekdays(weekday: 1).rawValue == 1)
        #expect(Weekdays(weekday: 7).rawValue == 64)
        #expect(Weekdays.all.contains(DayKey(rawValue: 20261114)))
    }
}
