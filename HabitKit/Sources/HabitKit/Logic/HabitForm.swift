import Foundation

/// What New habit and Edit habit hold before they are saved.
public struct HabitDraft: Sendable, Equatable {
    public var name: String
    public var kind: HabitKind
    /// As typed. Empty means no target.
    public var targetText: String
    /// As typed. Empty means the amount is typed each time.
    public var tapText: String
    /// Any set of days, none included. No set days is a valid habit.
    public var schedule: Weekdays

    public init(name: String, kind: HabitKind, targetText: String = "", tapText: String = "", schedule: Weekdays = .all) {
        self.name = name
        self.kind = kind
        self.targetText = targetText
        self.tapText = tapText
        self.schedule = schedule
    }

    public var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// The form's rule. The form shows each problem under its field and saves only with none.
public enum HabitForm {
    public enum Problem: Sendable, Equatable {
        case emptyName
        case target
        case tapAmount
    }

    /// The schedule is never a problem: a habit may have no set days.
    public static func problems(_ draft: HabitDraft) -> [Problem] {
        var found: [Problem] = []
        if draft.trimmedName.isEmpty { found.append(.emptyName) }
        if draft.kind == .counted {
            if !draft.targetText.isEmpty, (CountText.parse(draft.targetText) ?? 0) <= 0 { found.append(.target) }
            if !draft.tapText.isEmpty, (CountText.parse(draft.tapText) ?? 0) <= 0 { found.append(.tapAmount) }
        }
        return found
    }
}
