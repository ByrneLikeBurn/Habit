import SwiftUI
import SwiftData
import HabitKit

@main
struct HabitApp: App {
    @State private var settings = Settings()
    #if os(macOS)
    /// The Settings window's own model, kept across redraws.
    @State private var settingsModel = AppModel()
    #endif

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
            WindowRoot()
                .environment(settings)
                .preferredColorScheme(settings.preferredColorScheme)
        }
        #if os(macOS)
        .defaultSize(width: 720, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                FileCommands()
            }
            CommandGroup(before: .sidebar) {
                ViewCommands()
            }
        }
        #endif

        #if os(macOS)
        // On the Mac, settings live in a Settings window, opened with Command-comma.
        SwiftUI.Settings {
            Group {
                if case .success(let container) = SharedStore.container {
                    // Bring back in Archived shows its Undo line here.
                    StyledScreen {
                        YouView(isMacSettings: true)
                            .undoLineInset(.today)
                            // An Undo left from an earlier visit would act on a habit used since.
                            .onDisappear { settingsModel.undoLine = nil }
                    }
                        .modelContainer(container)
                }
            }
            .environment(settings)
            .environment(settingsModel)
            .preferredColorScheme(settings.preferredColorScheme)
            .frame(minWidth: 460, minHeight: 520)
        }
        #endif
    }
}

/// One window. Each window has its own model, so a sheet or panel opens in one window only.
private struct WindowRoot: View {
    @State private var model = AppModel()

    var body: some View {
        Group {
            switch SharedStore.container {
            case .success(let container):
                RootView()
                    .modelContainer(container)
            case .failure:
                StoreErrorView()
            }
        }
        .environment(model)
        .focusedSceneValue(model)
    }
}

#if os(macOS)
/// Menu commands act on the focused window, and are off when no window is open.
private struct FileCommands: View {
    @FocusedValue(AppModel.self) private var model

    var body: some View {
        Button("New Habit") { model?.showNewHabit = true }
            .keyboardShortcut("n")
            .disabled(model == nil)
        Divider()
        Button("Export a Copy…") { model?.showExport = true }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(model == nil)
        Button("Import a Copy…") { model?.choosingImportFile = true }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(model == nil)
    }
}

private struct ViewCommands: View {
    @FocusedValue(AppModel.self) private var model

    var body: some View {
        Button("Today") { model?.tab = .today }
            .keyboardShortcut("1")
            .disabled(model == nil)
        Button("History") { model?.tab = .history }
            .keyboardShortcut("2")
            .disabled(model == nil)
        Divider()
    }
}
#endif

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
