import SwiftUI
import SwiftData
import HabitKit

struct RootView: View {
    @Environment(Settings.self) private var settings
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        StyledScreen {
            TabView {
                Tab("Today", systemImage: "calendar") {
                    NavigationStack { TodayView() }
                }
                Tab("You", systemImage: "person.crop.circle") {
                    YouView()
                }
            }
            .tabViewStyle(.sidebarAdaptable)
            .sheet(isPresented: $model.showNewHabit) {
                HabitFormView(habit: nil)
            }
            .sheet(item: $model.editing) { habit in
                HabitFormView(habit: habit)
            }
            .sheet(item: $model.counting) { request in
                CountSheet(habit: request.habit, day: request.day)
            }
        }
        .onAppear(perform: openLaunchScreen)
    }

    /// Opens the screen named by `-screen`, for screenshots.
    private func openLaunchScreen() {
        guard let screen = LaunchOptions.current.screen else { return }
        switch screen {
        case .new, .newCount: model.showNewHabit = true
        default: break
        }
    }
}

/// Resolves the style for the current appearance and contrast setting, and lays paper behind the content.
struct StyledScreen<Content: View>: View {
    @Environment(Settings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @ViewBuilder var content: Content

    var body: some View {
        let style = settings.resolvedStyle(colorScheme: colorScheme, increaseContrast: contrast == .increased)
        content
            .environment(\.style, style)
            .tint(style.text)
            .background(style.paper)
            .transaction { transaction in
                if LaunchOptions.current.fixture != nil { transaction.disablesAnimations = true }
            }
    }
}
