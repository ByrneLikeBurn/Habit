import Foundation

public enum Ordering {
    /// Active habits in manual order. Done rows stay where they are, so a row never moves under a thumb.
    public static func sorted(_ habits: [Habit]) -> [Habit] {
        habits.filter(\.isActive).sorted {
            ($0.sortIndex, $0.createdAt) < ($1.sortIndex, $1.createdAt)
        }
    }

    /// Splits Today: habits set for today, then the ones that are not.
    public static func today(_ habits: [Habit], day: DayKey) -> (scheduled: [Habit], notScheduled: [Habit]) {
        let ordered = sorted(habits)
        return (ordered.filter { $0.isScheduled(on: day) }, ordered.filter { !$0.isScheduled(on: day) })
    }

    /// Moves `source` rows to `destination` within `subset` and rewrites sort indexes for all active habits.
    /// `subset` is the visible list. Hidden habits keep their places relative to each other.
    public static func move(_ subset: [Habit], from source: IndexSet, to destination: Int, all: [Habit]) {
        let moving = source.map { subset[$0] }
        var visible = subset.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let insertAt = destination - source.filter { $0 < destination }.count
        visible.insert(contentsOf: moving, at: insertAt)
        let ordered = sorted(all)
        let visibleIDs = Set(visible.map(\.id))
        var iterator = visible.makeIterator()
        let merged = ordered.map { visibleIDs.contains($0.id) ? iterator.next()! : $0 }
        for (index, habit) in merged.enumerated() where habit.sortIndex != index {
            habit.sortIndex = index
        }
    }

    /// The sort index for a new habit: after every other.
    public static func nextIndex(_ habits: [Habit]) -> Int {
        (habits.map(\.sortIndex).max() ?? -1) + 1
    }
}
