import SwiftUI
import SwiftData
import HabitKit

@main
struct HabitApp: App {
    @State private var settings = Settings()
    @State private var model = AppModel()

    init() {
        #if os(iOS)
        // Screenshots run with animations off, system sheets included.
        if LaunchOptions.current.fixture != nil { UIView.setAnimationsEnabled(false) }
        #endif
        // An export file left behind by a share that never finished.
        DataTransfer.sweep()
    }

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
                Divider()
                Button("Export a Copy…") { model.showExport = true }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("Import a Copy…") { model.choosingImportFile = true }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
            }
            CommandGroup(before: .sidebar) {
                Button("Today") { model.tab = .today }
                    .keyboardShortcut("1")
                Button("History") { model.tab = .history }
                    .keyboardShortcut("2")
                Divider()
            }
        }
        #endif

        #if os(macOS)
        // On the Mac, settings live in a Settings window, opened with Command-comma.
        SwiftUI.Settings {
            Group {
                if case .success(let container) = SharedStore.container {
                    StyledScreen { YouView(isMacSettings: true) }
                        .modelContainer(container)
                }
            }
            .environment(settings)
            .environment(model)
            .preferredColorScheme(settings.preferredColorScheme)
            .frame(minWidth: 460, minHeight: 520)
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
