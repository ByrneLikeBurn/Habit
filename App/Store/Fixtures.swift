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
    }

    static let weekdaysOnly = Weekdays(rawValue: 0b0111110)

    static func specs(_ fixture: LaunchOptions.Fixture) -> [Spec] {
        switch fixture {
        case .empty:
            return []
        case .today:
            return [
                Spec(name: "Drink water", symbol: "drop", kind: .counted, target: 8, unit: "glasses", logged: 3),
                Spec(name: "Read", symbol: "book", logged: 1),
                Spec(name: "Walk outside", symbol: "leaf"),
                Spec(name: "Write three lines in the journal before the day gets going", symbol: "pencil"),
                Spec(name: "Take vitamins", symbol: "pills", logged: 1),
                Spec(name: "Stretch before bed", symbol: "moon"),
                Spec(name: "Practise scales", symbol: "music.note", schedule: weekdaysOnly),
                Spec(name: "Water the plants", symbol: "sun.max", archived: true),
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
                for offset in 1...spec.history where (offset + index) % 4 != 0 {
                    let amount = spec.kind == .counted ? 1 + (offset % 3) : 1
                    let intent = LogHabitIntent(habitID: habit.id, name: habit.name, action: .add(amount), source: .manual, day: today.adding(days: -offset))
                    _ = try? intent.execute(in: context, clock: clock)
                }
            }
        }
        try? context.save()
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
