import Foundation
import HabitKit

/// Launch arguments for deterministic screenshots: a fixture store, a frozen clock, a screen to open.
///
/// `-fixture today|empty|none-today|long` `-screen new|newCount|count|edit|you|appearance|archived|marks|notScheduled`
/// `-appearance paper|ink`
struct LaunchOptions: Sendable {
    enum Fixture: String, Sendable {
        case today, empty, noneToday = "none-today", allDone = "all-done", long
    }

    enum Screen: String, Sendable {
        case new, newCount, count, edit, you, appearance, archived, marks, notScheduled, undo
        case history, historyMonth, detailWeek, detailMonth, detailYear, detailEmpty, detailRuns
        case day, dayCount, dayOff, dayDone, export, importPreview, importDone, importNothing, importNotHabit, importNewer, contrast
    }

    var fixture: Fixture?
    var screen: Screen?
    var appearance: AppearanceChoice?
    /// `-showRuns` turns Show runs on for screenshots.
    var showRuns = false
    /// `-showDaysNotLogged` turns Show days not logged on for screenshots.
    var showDaysNotLogged = false

    /// Saturday 14 November 2026, 09:41 in London.
    var clock: HabitClock? {
        guard fixture != nil else { return nil }
        let instant = Date(timeIntervalSince1970: 1_794_649_260)
        return .frozen(at: instant, timeZone: TimeZone(identifier: "Europe/London")!)
    }

    nonisolated static let current: LaunchOptions = {
        let arguments = ProcessInfo.processInfo.arguments
        func value(_ flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        return LaunchOptions(
            fixture: value("-fixture").flatMap(Fixture.init(rawValue:)),
            screen: value("-screen").flatMap(Screen.init(rawValue:)),
            appearance: value("-appearance").flatMap(AppearanceChoice.init(rawValue:)),
            showRuns: arguments.contains("-showRuns"),
            showDaysNotLogged: arguments.contains("-showDaysNotLogged")
        )
    }()
}
