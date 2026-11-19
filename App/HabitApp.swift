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
            CommandMenu("Habit") {
                HabitCommands(settings: settings)
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
                            // Read on open, and on the post when the window is already open.
                            .onAppear(perform: openPendingArchived)
                            .onReceive(NotificationCenter.default.publisher(for: .showArchivedInSettings)) { _ in openPendingArchived() }
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
        let kinds = model?.periodKinds ?? []
        Button("Week") { request(.show(.week)) }
            .keyboardShortcut("1", modifiers: [.command, .option])
            .disabled(!kinds.contains(.week))
        Button("Month") { request(.show(.month)) }
            .keyboardShortcut("2", modifiers: [.command, .option])
            .disabled(!kinds.contains(.month))
        Button("Year") { request(.show(.year)) }
            .keyboardShortcut("3", modifiers: [.command, .option])
            .disabled(!kinds.contains(.year))
        Divider()
        Button("Previous Period") { request(.move(-1)) }
            .keyboardShortcut(.leftArrow, modifiers: [.command])
            .disabled(kinds.isEmpty)
        Button("Next Period") { request(.move(1)) }
            .keyboardShortcut(.rightArrow, modifiers: [.command])
            .disabled(kinds.isEmpty)
        Button("Go to Today") { request(.current) }
            .keyboardShortcut("t", modifiers: [.command])
            .disabled(kinds.isEmpty)
        Divider()
        Button("Back") { model?.goBack() }
            .keyboardShortcut("[", modifiers: [.command])
            .disabled(model?.currentPath.isEmpty ?? true)
        Divider()
    }

    private func request(_ command: PeriodRequest.Command) {
        model?.periodRequest = PeriodRequest(command: command)
    }
}

/// The Habit menu. It acts on the row selected on Today, or on the habit Habit detail shows.
/// The window-wide pause commands need no selection.
private struct HabitCommands: View {
    let settings: Settings
    @FocusedValue(AppModel.self) private var model

    var body: some View {
        let habit = model?.menuHabit.flatMap { $0.isActive ? $0 : nil }
        let clock = settings.clock
        let today = clock.today
        Button("Log") {
            guard let model, let habit, let context = habit.modelContext else { return }
            if habit.kind == .counted && (habit.tapAmount ?? 0) <= 0 {
                model.counting = CountRequest(habit: habit, day: today)
            } else {
                model.log(.tap, habit: habit, day: today, context: context, clock: clock, undoManager: model.undoManager)
            }
        }
        .keyboardShortcut("l", modifiers: [.command])
        .disabled(habit == nil)
        Button("Add an Amount…") {
            guard let habit else { return }
            model?.counting = CountRequest(habit: habit, day: today)
        }
        .keyboardShortcut("l", modifiers: [.command, .option])
        .disabled(habit?.kind != .counted)
        Button("Add a Past Day…") { model?.pickingPastDay = habit }
            .disabled(habit == nil)
        Divider()
        Button("Show Details") {
            guard let habit else { return }
            model?.openDetail(habit, kind: .month, anchor: today, from: .today)
        }
        .keyboardShortcut("i", modifiers: [.command])
        .disabled(habit == nil || !(model?.currentPath.isEmpty ?? false))
        Button("Edit Habit…") { model?.editing = habit }
            .keyboardShortcut("e", modifiers: [.command])
            .disabled(habit == nil)
        Divider()
        if let habit, let context = habit.modelContext, let model {
            switch habit.ownPauseStatus(today: today) {
            case .none:
                Button("Pause This Habit") { model.pause(habit, context: context, clock: clock) }
            case .paused(_, let startedToday):
                Button(startedToday ? "Undo Pause" : "Resume Tomorrow") { model.resume(habit, context: context, clock: clock) }
            case .resumesTomorrow:
                Button("Keep Paused") { model.pause(habit, context: context, clock: clock) }
            }
        } else {
            Button("Pause This Habit") {}.disabled(true)
        }
        Button("Archive Habit") {
            guard let model, let habit, let context = habit.modelContext else { return }
            model.archive(habit, context: context, clock: clock)
            model.selectedHabit = nil
        }
        .disabled(habit == nil)
        Divider()
        everythingButton(clock: clock)
        Button("Pause for Dates…") { model?.pauseForm = PauseRequest(pause: nil) }
            .disabled(model == nil)
    }

    /// "Pause Everything", or what Today's pause line offers while everything is paused.
    @ViewBuilder
    private func everythingButton(clock: HabitClock) -> some View {
        if let model, case .success(let container) = SharedStore.container {
            let context = container.mainContext
            let status = SharedPauseStatus.of((try? PauseWriter.sharedPauses(in: context)) ?? [], today: clock.today)
            switch status {
            case .none:
                Button("Pause Everything") { model.pauseEverything(context: context, clock: clock) }
            case .everything(let startedToday), .until(_, let startedToday):
                Button(startedToday ? "Resume Everything Now" : "Resume Everything Tomorrow") { model.resumeShared(context: context, clock: clock) }
            case .resumesTomorrow(let canKeep):
                Button("Keep Everything Paused") { model.keepShared(context: context, clock: clock, status: status) }
                    .disabled(!canKeep && model.resumedShared.isEmpty)
            }
        } else {
            Button("Pause Everything") {}.disabled(true)
        }
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

#if os(macOS)
extension HabitApp {
    func openPendingArchived() {
        guard SettingsOpens.archived else { return }
        SettingsOpens.archived = false
        settingsModel.showArchived = true
    }
}
#endif

/// Set by "Show archived habits" before the Settings window opens.
@MainActor
enum SettingsOpens {
    static var archived = false
}

extension Notification.Name {
    /// "Show archived habits" on the Mac's empty Today: the Settings window opens on Archived.
    static let showArchivedInSettings = Notification.Name("showArchivedInSettings")
}
