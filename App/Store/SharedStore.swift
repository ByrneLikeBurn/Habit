import Foundation
import SwiftData
import HabitKit

/// The one SwiftData store, in the App Group container so widgets, intents and the Watch can share it.
enum SharedStore {
    static let groupID = "group.dev.byrnelikeburn.Habit"

    /// Settings shared with the widget and intents. Screenshots use a separate, throwaway domain.
    static let defaults: UserDefaults = {
        if LaunchOptions.current.fixture != nil {
            let domain = "dev.byrnelikeburn.Habit.fixture"
            UserDefaults.standard.removePersistentDomain(forName: domain)
            return UserDefaults(suiteName: domain) ?? .standard
        }
        return UserDefaults(suiteName: groupID) ?? .standard
    }()

    static let container: Result<ModelContainer, StoreError> = makeContainer()

    enum StoreError: Error {
        case noGroupContainer
        case openFailed(String)
    }

    private static func makeContainer() -> Result<ModelContainer, StoreError> {
        let schema = Schema(versionedSchema: HabitSchemaV1.self)
        if let fixture = LaunchOptions.current.fixture {
            do {
                let container = try ModelContainer(
                    for: schema,
                    migrationPlan: HabitMigrationPlan.self,
                    configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                )
                Fixtures.seed(fixture, into: container.mainContext, clock: LaunchOptions.current.clock)
                return .success(container)
            } catch {
                return .failure(.openFailed(String(describing: error)))
            }
        }
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            return .failure(.noGroupContainer)
        }
        // SwiftData does not create this folder in a group container, and logs errors without it.
        let support = groupURL.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        do {
            let configuration = ModelConfiguration(
                "Habit",
                schema: schema,
                groupContainer: .identifier(groupID),
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, migrationPlan: HabitMigrationPlan.self, configurations: configuration)
            return .success(container)
        } catch {
            return .failure(.openFailed(String(describing: error)))
        }
    }

    /// A random id for this install, stored in the shared settings. It never leaves the device.
    static var deviceID: String {
        if let id = defaults.string(forKey: SettingKey.deviceID) { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: SettingKey.deviceID)
        return id
    }
}
