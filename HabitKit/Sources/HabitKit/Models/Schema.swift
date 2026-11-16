import Foundation
import SwiftData

// Schema rules, from CLAUDE.md and docs/spec.md:
// - Additive only, forever. Never rename or retype a stored property.
// - Every property is optional or has a default, and the default lives on the property.
// - Relationships are optional. Nothing is marked unique. CloudKit needs this later.
// - A new schema version is needed only when the set of @Model types changes.

public enum HabitSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [Habit.self, LogEvent.self, Pause.self]
    }
}

public enum HabitMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [HabitSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public typealias Habit = HabitSchemaV1.Habit
public typealias LogEvent = HabitSchemaV1.LogEvent
public typealias Pause = HabitSchemaV1.Pause

public enum HabitKind: String, Codable, Sendable, CaseIterable {
    case binary
    case counted
}

public enum LogSource: String, Codable, Sendable, CaseIterable {
    case manual, watch, widget, shortcut, siri, control
}

public enum PauseReason: String, Codable, Sendable, CaseIterable {
    case vacation, gentle, manual
}

/// The target and schedule that apply from one day onward.
/// A change applies from the day it is made. Earlier days keep the rule they had.
public struct HabitRule: Codable, Hashable, Sendable {
    public var fromDay: Int
    /// nil for a counted habit with no target. 1 for a yes-or-no habit.
    public var target: Int?
    public var scheduleMask: Int

    public init(fromDay: DayKey, target: Int?, schedule: Weekdays) {
        self.fromDay = fromDay.rawValue
        self.target = target
        self.scheduleMask = schedule.rawValue
    }

    public var schedule: Weekdays { Weekdays(rawValue: scheduleMask) }
}

extension HabitSchemaV1 {
    @Model
    public final class Habit {
        public var id: UUID = UUID()
        public var name: String = ""
        public var symbolName: String = "drop"
        public var kindRaw: String = HabitKind.binary.rawValue
        /// The current target. nil for a counted habit with no target. Earlier days read `rules`.
        public var target: Int? = 1
        /// Shown as typed. Empty for none.
        public var unit: String = ""
        /// The current schedule. Earlier days read `rules`.
        public var scheduleMask: Int = 127
        /// What one tap on Today adds. nil means a tap opens the count sheet.
        public var tapAmount: Int? = 1
        public var sortIndex: Int = 0
        public var createdAt: Date = Date.now
        public var archivedAt: Date? = nil
        public var deletedAt: Date? = nil
        /// Target and schedule history, oldest first.
        public var rules: [HabitRule] = []

        @Relationship(deleteRule: .cascade, inverse: \LogEvent.habit)
        public var events: [LogEvent]? = []

        @Relationship(deleteRule: .cascade, inverse: \Pause.habit)
        public var pauses: [Pause]? = []

        public init(
            name: String,
            symbolName: String,
            kind: HabitKind,
            target: Int?,
            unit: String = "",
            schedule: Weekdays = .all,
            tapAmount: Int? = 1,
            sortIndex: Int = 0,
            createdAt: Date,
            firstDay: DayKey
        ) {
            self.name = name
            self.symbolName = symbolName
            self.kindRaw = kind.rawValue
            self.target = kind == .binary ? 1 : target
            self.unit = unit
            self.scheduleMask = schedule.rawValue
            self.tapAmount = kind == .binary ? 1 : tapAmount
            self.sortIndex = sortIndex
            self.createdAt = createdAt
            self.rules = [HabitRule(fromDay: firstDay, target: self.target, schedule: schedule)]
        }
    }

    @Model
    public final class LogEvent {
        /// Stable across export and import. Import skips an id already in the store.
        public var id: UUID = UUID()
        /// Any whole number. Positive adds, negative takes away. No event stores a total.
        public var delta: Int = 0
        public var habit: Habit? = nil
        /// yyyymmdd, fixed at write time.
        public var dayKey: Int = 0
        public var sourceRaw: String = LogSource.manual.rawValue
        public var timestamp: Date = Date.now
        public var deviceID: String = ""

        /// Import passes nil and attaches a habit's events in one assignment, which keeps a large import linear.
        public init(delta: Int, habit: Habit?, day: DayKey, source: LogSource, timestamp: Date, deviceID: String) {
            self.delta = delta
            self.habit = habit
            self.dayKey = day.rawValue
            self.sourceRaw = source.rawValue
            self.timestamp = timestamp
            self.deviceID = deviceID
        }
    }

    @Model
    public final class Pause {
        public var id: UUID = UUID()
        public var habit: Habit? = nil
        public var startDay: Int = 0
        /// nil is open-ended.
        public var endDay: Int? = nil
        public var reasonRaw: String = PauseReason.manual.rawValue

        public init(habit: Habit?, start: DayKey, end: DayKey?, reason: PauseReason) {
            self.habit = habit
            self.startDay = start.rawValue
            self.endDay = end?.rawValue
            self.reasonRaw = reason.rawValue
        }
    }
}
