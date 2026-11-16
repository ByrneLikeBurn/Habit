import Foundation
import SwiftData

/// Why a file was refused. Every case changes nothing.
public enum ImportProblem: Error, Sendable, Equatable {
    /// Not JSON, or not this app's export format.
    case notAHabitExport
    /// Written by a newer version of the app.
    case newerVersion
    /// Over the size or count limits.
    case tooLarge
    /// A Habit export with a record that fails a check: a bad day key, an amount over the cap,
    /// an unknown kind or source, or a log whose habit is missing.
    case damaged
}

/// Limits on what one import may hold. A file over any of them is refused with nothing written.
public enum ImportLimits {
    /// 64 MB. A log is about 150 bytes of compact JSON, so the log limit fits with room to spare.
    public static let maxBytes = 64 * 1024 * 1024
    public static let maxHabits = 1_000
    public static let maxLogs = 300_000
    public static let maxPauses = 10_000
    /// The longest habit name, unit or symbol name accepted.
    public static let maxTextLength = 500
}

/// What an import would do. Built from a checked file and the store, before anything is written.
public struct ImportPlan: Sendable {
    public var fileHabits: Int
    public var fileLogs: Int
    public var newHabits: [ExportFile.HabitRecord]
    /// Habits whose id is here with different details. This device's version is kept.
    public var differing: Int
    public var newLogs: [ExportFile.LogRecord]
    /// Logs whose id is already here.
    public var skippedLogs: Int
    public var newPauses: [ExportFile.PauseRecord]

    public var isEmpty: Bool { newHabits.isEmpty && newLogs.isEmpty && newPauses.isEmpty }

    /// Reads and checks a whole file, then compares it with the store. Writes nothing.
    /// Parse errors never carry file content.
    @MainActor
    public static func make(from data: Data, in context: ModelContext) throws(ImportProblem) -> ImportPlan {
        let file = try decode(data)
        try check(file)

        let existing: [Habit]
        let logIDs: Set<UUID>
        let pauseIDs: Set<UUID>
        do {
            existing = try context.fetch(FetchDescriptor<Habit>())
            logIDs = Set(try context.fetch(FetchDescriptor<LogEvent>()).map(\.id))
            pauseIDs = Set(try context.fetch(FetchDescriptor<Pause>()).map(\.id))
        } catch {
            throw .damaged
        }
        let here = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let fileHabitIDs = Set(file.habits.map(\.id))

        // Every log and pause must name a habit in the file or in the store.
        for log in file.logs where !fileHabitIDs.contains(log.habit) && here[log.habit] == nil {
            throw .damaged
        }
        for pause in file.pauses {
            if let habit = pause.habit, !fileHabitIDs.contains(habit), here[habit] == nil { throw .damaged }
        }

        var differing = 0
        var newHabits: [ExportFile.HabitRecord] = []
        for record in file.habits {
            if let habit = here[record.id] {
                if !habit.matches(record) { differing += 1 }
            } else {
                newHabits.append(record)
            }
        }
        // A log id may appear once only.
        var seen = Set<UUID>()
        var newLogs: [ExportFile.LogRecord] = []
        var skipped = 0
        for log in file.logs {
            guard seen.insert(log.id).inserted else { throw .damaged }
            if logIDs.contains(log.id) { skipped += 1 } else { newLogs.append(log) }
        }
        let newPauses = file.pauses.filter { !pauseIDs.contains($0.id) }
        return ImportPlan(
            fileHabits: file.habits.count, fileLogs: file.logs.count,
            newHabits: newHabits, differing: differing,
            newLogs: newLogs, skippedLogs: skipped, newPauses: newPauses
        )
    }

    static func decode(_ data: Data) throws(ImportProblem) -> ExportFile {
        guard data.count <= ImportLimits.maxBytes else { throw .tooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Read the header first, so a newer file is named as newer even if its records changed shape.
        struct Header: Decodable { var format: String; var version: Int }
        guard let header = try? decoder.decode(Header.self, from: data), header.format == ExportFile.formatName else {
            throw .notAHabitExport
        }
        guard header.version <= ExportFile.currentVersion else { throw .newerVersion }
        guard header.version >= 1 else { throw .damaged }
        do {
            return try decoder.decode(ExportFile.self, from: data)
        } catch {
            throw .damaged
        }
    }

    static func check(_ file: ExportFile) throws(ImportProblem) {
        guard file.habits.count <= ImportLimits.maxHabits,
              file.logs.count <= ImportLimits.maxLogs,
              file.pauses.count <= ImportLimits.maxPauses else { throw .tooLarge }
        let cap = CountText.maximumAmount
        let schedule = 0...Weekdays.all.rawValue
        func text(_ s: String) -> Bool { s.count <= ImportLimits.maxTextLength }
        var habitIDs = Set<UUID>()
        for h in file.habits {
            guard habitIDs.insert(h.id).inserted,
                  let kind = HabitKind(rawValue: h.kind),
                  !h.name.trimmingCharacters(in: .whitespaces).isEmpty, text(h.name), text(h.unit), text(h.symbol),
                  schedule.contains(h.schedule),
                  h.target.map({ (1...cap).contains($0) }) ?? (kind == .counted),
                  h.tapAmount.map({ (1...cap).contains($0) }) ?? (kind == .counted),
                  !h.rules.isEmpty,
                  h.rules.allSatisfy({ Periods.isValid($0.fromDay) && schedule.contains($0.schedule) && ($0.target.map { (1...cap).contains($0) } ?? (kind == .counted)) })
            else { throw .damaged }
        }
        for log in file.logs {
            guard Periods.isValid(log.day), abs(log.delta) <= cap, LogSource(rawValue: log.source) != nil else { throw .damaged }
        }
        var pauseIDs = Set<UUID>()
        for p in file.pauses {
            guard pauseIDs.insert(p.id).inserted, Periods.isValid(p.start), PauseReason(rawValue: p.reason) != nil,
                  p.end.map({ Periods.isValid($0) && $0 >= p.start }) ?? true
            else { throw .damaged }
        }
    }
}

extension Habit {
    /// True when the store's habit has the same details as the file's record.
    func matches(_ r: ExportFile.HabitRecord) -> Bool {
        name == r.name && symbolName == r.symbol && kindRaw == r.kind && target == r.target && unit == r.unit
            && scheduleMask == r.schedule && tapAmount == r.tapAmount && (archivedAt == nil) == (r.archived == nil)
            && deletedAt == nil
            && rules.sorted { $0.fromDay < $1.fromDay }.map { ExportFile.HabitRecord.Rule(fromDay: $0.fromDay, target: $0.target, schedule: $0.scheduleMask) } == r.rules
    }
}
