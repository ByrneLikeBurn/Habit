import Foundation
import SwiftData
import HabitKit

/// Fixture data for previews and screenshots. Invented, not real data.
/// Logs go through LogHabitIntent like every other log.
@MainActor
enum Fixtures {
    struct Spec {
        var name: String
        var symbol: String
        var kind: HabitKind = .binary
        var target: Int? = 1
        var unit = ""
        var tap: Int? = 1
        var schedule: Weekdays = .all
        var logged = 0
        var archived = false
        /// Days of past logs before today, so performance is checked against a real history.
        var history = 0
        /// The amount logged `offset` days before today, or 0 for none. Used with `history`.
        var pattern: (@Sendable (Int) -> Int)? = nil
    }

    static let weekdaysOnly = Weekdays(rawValue: 0b0111110)
    static let exceptThursday = Weekdays(rawValue: 0b1101111)

    static func specs(_ fixture: LaunchOptions.Fixture) -> [Spec] {
        switch fixture {
        case .empty:
            return []
        case .today:
            // History runs from 28 April 2026, 200 days before the frozen today. All made up.
            return [
                Spec(name: "Drink water", symbol: "drop", kind: .counted, target: 8, unit: "glasses", schedule: exceptThursday, logged: 3,
                     history: 200, pattern: { [8, 8, 3, 8, 10, 0, 8, 5][$0 % 8] }),
                Spec(name: "Read", symbol: "book", logged: 1, history: 200, pattern: { $0 % 5 == 2 || (3...4).contains($0) ? 0 : 1 }),
                Spec(name: "Walk outside", symbol: "leaf", history: 200, pattern: { $0 % 3 == 0 ? 1 : 0 }),
                Spec(name: "Write three lines in the journal before the day gets going", symbol: "pencil", history: 200, pattern: { $0 % 7 == 1 ? 1 : 0 }),
                Spec(name: "Take vitamins", symbol: "pills", logged: 1, history: 200, pattern: { $0 % 11 == 4 ? 0 : 1 }),
                Spec(name: "Stretch before bed", symbol: "moon"),
                Spec(name: "Practise scales", symbol: "music.note", schedule: weekdaysOnly, history: 200, pattern: { $0 % 2 == 0 ? 1 : 0 }),
                Spec(name: "Water the plants", symbol: "sun.max", archived: true, history: 200, pattern: { $0 == 2 || $0 % 9 == 0 ? 1 : 0 }),
            ]
        case .allDone:
            return [
                Spec(name: "Drink water", symbol: "drop", kind: .counted, target: 8, unit: "glasses", logged: 8),
                Spec(name: "Read", symbol: "book", logged: 1),
                Spec(name: "Walk outside", symbol: "leaf", logged: 1),
                Spec(name: "Write three lines in the journal before the day gets going", symbol: "pencil", logged: 1),
                Spec(name: "Take vitamins", symbol: "pills", logged: 1),
                Spec(name: "Stretch before bed", symbol: "moon", logged: 1),
            ]
        case .noDays:
            // A habit with no set days, first in the list so its control shows at the largest text size,
            // beside daily habits and one set for weekdays. It is the only counted habit, so Habit detail opens on it.
            return [
                Spec(name: "Practise guitar", symbol: "guitars", kind: .counted, target: 20, unit: "minutes", tap: 10, schedule: [],
                     history: 200, pattern: { [0, 0, 20, 0, 0, 0, 10, 0, 0, 30, 0, 0, 0][$0 % 13] }),
                Spec(name: "Read", symbol: "book", logged: 1, history: 120, pattern: { $0 % 4 == 3 ? 0 : 1 }),
                Spec(name: "Walk outside", symbol: "", history: 120, pattern: { $0 % 3 == 0 ? 1 : 0 }),
                Spec(name: "Practise scales", symbol: "music.note", schedule: weekdaysOnly),
            ]
        case .noneToday:
            return [
                Spec(name: "Practise scales", symbol: "music.note", schedule: weekdaysOnly),
                Spec(name: "Pack lunch", symbol: "fork.knife", schedule: weekdaysOnly),
            ]
        case .long:
            let symbols = ["drop", "book", "leaf", "pencil", "pills", "moon"]
            return (1...30).map { i in
                Spec(name: "Habit \(i)", symbol: symbols[i % symbols.count],
                     kind: i % 3 == 0 ? .counted : .binary, target: i % 3 == 0 ? 5 : 1,
                     unit: i % 3 == 0 ? "minutes" : "", logged: i % 2, history: 200)
            }
        }
    }

    static func seed(_ fixture: LaunchOptions.Fixture, into context: ModelContext, clock: HabitClock?) {
        let clock = clock ?? HabitClock()
        let today = clock.today
        for (index, spec) in specs(fixture).enumerated() {
            let habit = Habit(
                name: spec.name,
                symbolName: spec.symbol,
                kind: spec.kind,
                target: spec.target,
                unit: spec.unit,
                schedule: spec.schedule,
                tapAmount: spec.tap,
                sortIndex: index,
                createdAt: clock.now().addingTimeInterval(-86_400 * 30),
                firstDay: today.adding(days: -30)
            )
            if spec.archived { habit.archivedAt = clock.now() }
            context.insert(habit)
            if spec.logged > 0 {
                let intent = LogHabitIntent(habitID: habit.id, name: habit.name, action: .add(spec.logged), source: .manual, day: today)
                _ = try? intent.execute(in: context, clock: clock)
            }
            if spec.history > 0 {
                habit.rules = [HabitRule(fromDay: today.adding(days: -spec.history), target: habit.target, schedule: habit.schedule)]
                for offset in 1...spec.history where spec.pattern.map({ $0(offset) > 0 }) ?? ((offset + index) % 4 != 0) {
                    let amount = spec.pattern?(offset) ?? (spec.kind == .counted ? 1 + (offset % 3) : 1)
                    let intent = LogHabitIntent(habitID: habit.id, name: habit.name, action: .add(amount), source: .manual, day: today.adding(days: -offset))
                    _ = try? intent.execute(in: context, clock: clock)
                }
            }
        }
        if fixture == .today {
            // Two days paused for everything, so the month shows the dash and the diamond.
            context.insert(Pause(habit: nil, start: today.adding(days: -9), end: today.adding(days: -8), reason: .vacation))
        }
        try? context.save()
    }

    /// The import sheet at each stage, for screenshots. The file is made up from the fixture store.
    static func importStage(_ screen: LaunchOptions.Screen, context: ModelContext, clock: HabitClock) -> ImportStage? {
        switch screen {
        case .importNotHabit: return .problem(.notAHabitExport)
        case .importNewer: return .problem(.newerVersion)
        case .importNothing, .importPreview, .importDone:
            guard var file = try? ExportFile.make(from: context, appBuild: "1", now: clock.now()) else { return nil }
            if screen != .importNothing, let template = file.habits.first {
                for (i, name) in ["Floss", "Call a friend"].enumerated() {
                    var habit = template
                    habit.id = UUID()
                    habit.name = name
                    habit.kind = HabitKind.binary.rawValue
                    habit.target = 1
                    habit.tapAmount = 1
                    habit.rules = habit.rules.map { .init(fromDay: $0.fromDay, target: 1, schedule: $0.schedule) }
                    file.habits.append(habit)
                    for offset in 1...(i == 0 ? 120 : 92) {
                        file.logs.append(.init(id: UUID(), habit: habit.id, delta: 1, day: clock.today.adding(days: -offset).rawValue, source: "manual", time: clock.now()))
                    }
                }
                file.habits[0].name = "Water"
            }
            guard let data = try? file.encoded() else { return nil }
            let plan = DataTransfer.plan(data: data, context: context)
            if screen == .importDone, case .success(let plan) = plan {
                return .done(LogWriter.ImportResult(habitsAdded: plan.newHabits.count, logsAdded: plan.newLogs.count,
                                                    pausesAdded: plan.newPauses.count, skipped: plan.skippedLogs))
            }
            return plan.map(ImportStage.preview).fold
        default:
            return nil
        }
    }

    /// An in-memory container for SwiftUI previews.
    static func previewContainer(_ fixture: LaunchOptions.Fixture = .today) -> ModelContainer {
        let schema = Schema(versionedSchema: HabitSchemaV1.self)
        let container = try! ModelContainer(
            for: schema,
            migrationPlan: HabitMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        seed(fixture, into: container.mainContext, clock: previewClock)
        return container
    }

    static let previewClock = HabitClock.frozen(
        at: Date(timeIntervalSince1970: 1_794_649_260),
        timeZone: TimeZone(identifier: "Europe/London")!
    )
}
