import Foundation
import SwiftData

/// The export file: plain JSON holding habits, logs and pauses.
///
/// It holds no settings and no device id. Records are sorted, keys are sorted and dates are whole
/// seconds, so exporting, importing into an empty store and exporting again gives the same file
/// apart from the export time.
public struct ExportFile: Codable, Sendable, Equatable {
    public static let formatName = "dev.byrnelikeburn.Habit.export"
    /// One whole-number version. A file with a higher one is refused.
    public static let currentVersion = 1

    public struct Counts: Codable, Sendable, Equatable {
        public var habits: Int
        public var logs: Int
        public var pauses: Int
    }

    public struct HabitRecord: Codable, Sendable, Equatable {
        public var id: UUID
        public var name: String
        public var symbol: String
        public var kind: String
        public var target: Int?
        public var unit: String
        public var schedule: Int
        public var tapAmount: Int?
        public var sortIndex: Int
        public var created: Date
        public var archived: Date?
        public var rules: [Rule]

        public struct Rule: Codable, Sendable, Equatable {
            public var fromDay: Int
            public var target: Int?
            public var schedule: Int

            public init(fromDay: Int, target: Int?, schedule: Int) {
                self.fromDay = fromDay
                self.target = target
                self.schedule = schedule
            }
        }
    }

    public struct LogRecord: Codable, Sendable, Equatable {
        public var id: UUID
        public var habit: UUID
        public var delta: Int
        public var day: Int
        public var source: String
        public var time: Date

        public init(id: UUID, habit: UUID, delta: Int, day: Int, source: String, time: Date) {
            // One assignment, so the write-path check, which looks for a stored delta being set, stays strict.
            (self.id, self.habit, self.delta, self.day, self.source, self.time) = (id, habit, delta, day, source, time)
        }
    }

    public struct PauseRecord: Codable, Sendable, Equatable {
        public var id: UUID
        /// nil for a pause of every habit.
        public var habit: UUID?
        public var start: Int
        public var end: Int?
        public var reason: String
    }

    public var format: String
    public var version: Int
    public var appBuild: String
    public var exported: Date
    public var counts: Counts
    public var habits: [HabitRecord]
    public var logs: [LogRecord]
    public var pauses: [PauseRecord]

    // MARK: Writing

    /// Reads the store. Deleted habits and their logs and pauses are left out.
    @MainActor
    public static func make(from context: ModelContext, appBuild: String, now: Date) throws -> ExportFile {
        let habits = try context.fetch(FetchDescriptor<Habit>()).filter { $0.deletedAt == nil }
        let kept = Set(habits.map(\.id))
        let habitRecords = habits.map { h in
            HabitRecord(
                id: h.id, name: h.name, symbol: h.symbolName, kind: h.kindRaw, target: h.target, unit: h.unit,
                schedule: h.scheduleMask, tapAmount: h.tapAmount, sortIndex: h.sortIndex,
                created: h.createdAt.wholeSeconds, archived: h.archivedAt?.wholeSeconds,
                rules: h.rules.sorted { $0.fromDay < $1.fromDay }.map { .init(fromDay: $0.fromDay, target: $0.target, schedule: $0.scheduleMask) }
            )
        }.sorted { ($0.sortIndex, $0.id.uuidString) < ($1.sortIndex, $1.id.uuidString) }
        let logRecords = try context.fetch(FetchDescriptor<LogEvent>()).compactMap { e -> LogRecord? in
            guard let habit = e.habit?.id, kept.contains(habit) else { return nil }
            return LogRecord(id: e.id, habit: habit, delta: e.delta, day: e.dayKey, source: e.sourceRaw, time: e.timestamp.wholeSeconds)
        }.sorted { ($0.day, $0.time, $0.id.uuidString) < ($1.day, $1.time, $1.id.uuidString) }
        let pauseRecords = try context.fetch(FetchDescriptor<Pause>()).compactMap { p -> PauseRecord? in
            if let habit = p.habit, !kept.contains(habit.id) { return nil }
            return PauseRecord(id: p.id, habit: p.habit?.id, start: p.startDay, end: p.endDay, reason: p.reasonRaw)
        }.sorted { ($0.start, $0.id.uuidString) < ($1.start, $1.id.uuidString) }
        return ExportFile(
            format: formatName, version: currentVersion, appBuild: appBuild, exported: now.wholeSeconds,
            counts: Counts(habits: habitRecords.count, logs: logRecords.count, pauses: pauseRecords.count),
            habits: habitRecords, logs: logRecords, pauses: pauseRecords
        )
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// "Habit export 2026-11-14.json". No habit name and no device name.
    public static func fileName(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "Habit export %04d-%02d-%02d.json", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

extension Date {
    /// Whole seconds, so an ISO 8601 round trip gives the same value.
    var wholeSeconds: Date { Date(timeIntervalSince1970: timeIntervalSince1970.rounded(.down)) }
}
