import SwiftUI
import SwiftData
import HabitKit

@main
struct HabitApp: App {
    @State private var settings = Settings()
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            Group {
                switch SharedStore.container {
                case .success(let container):
                    RootView()
                        .modelContainer(container)
                case .failure:
                    StoreErrorView()
                }
            }
            .environment(settings)
            .environment(model)
            .preferredColorScheme(settings.preferredColorScheme)
        }
        #if os(macOS)
        .defaultSize(width: 720, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Habit") { model.showNewHabit = true }
                    .keyboardShortcut("n")
            }
        }
        #endif
    }
}

/// Shown if the store cannot open. Nothing is written, so nothing is lost.
struct StoreErrorView: View {
    @Environment(\.style) private var style

    var body: some View {
        StyledScreen {
            VStack(alignment: .leading, spacing: 12) {
                Text("Habit could not open its data")
                    .font(style.display(.title2))
                    .foregroundStyle(style.text)
                Text("Your habits are still on this device. Quit Habit and open it again. If this keeps happening, restart the device.")
                    .font(style.label(.body))
                    .foregroundStyle(style.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
