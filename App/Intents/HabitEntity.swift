import AppIntents
import Foundation
import SwiftData
import HabitKit

struct HabitEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"
    static let defaultQuery = HabitQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct HabitQuery: EntityStringQuery {
    @MainActor
    private func habits() throws -> [Habit] {
        let context = try SharedStore.container.get().mainContext
        return Ordering.sorted(try context.fetch(FetchDescriptor<Habit>()))
    }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [HabitEntity] {
        let wanted = Set(identifiers)
        let context = try SharedStore.container.get().mainContext
        return try context.fetch(FetchDescriptor<Habit>())
            .filter { wanted.contains($0.id) && $0.deletedAt == nil }
            .map { HabitEntity(id: $0.id, name: $0.name) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [HabitEntity] {
        try habits()
            .filter { $0.name.localizedStandardContains(string) }
            .map { HabitEntity(id: $0.id, name: $0.name) }
    }

    @MainActor
    func suggestedEntities() async throws -> [HabitEntity] {
        try habits().map { HabitEntity(id: $0.id, name: $0.name) }
    }
}
