import SwiftUI
import SwiftData
import HabitKit

struct RootView: View {
    @Environment(Settings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @State private var tab = LaunchOptions.current.screen?.opensYou == true ? Section.you : .today

    enum Section: Hashable { case today, you }

    var body: some View {
        @Bindable var model = model
        StyledScreen {
            TabView(selection: $tab) {
                Tab("Today", systemImage: "calendar", value: Section.today) {
                    NavigationStack { TodayScreen() }
                }
                Tab("You", systemImage: "person.crop.circle", value: Section.you) {
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
        let habits = Ordering.sorted((try? context.fetch(FetchDescriptor<Habit>())) ?? [])
        let clock = settings.clock
        switch screen {
        case .new, .newCount:
            model.showNewHabit = true
        case .edit:
            model.editing = habits.first
        case .count:
            if let habit = habits.first(where: { $0.kind == .counted }) {
                model.counting = CountRequest(habit: habit, day: clock.today)
            }
        case .undo:
            // A real take-back, so the mark and the line agree.
            if let habit = habits.first(where: { $0.kind == .binary && $0.total(on: clock.today) > 0 }) {
                model.log(.tap, habit: habit, day: clock.today, context: context, clock: clock, undoManager: nil)
            }
        default:
            break
        }
    }
}

extension LaunchOptions.Screen {
    var opensYou: Bool {
        switch self {
        case .you, .appearance, .archived, .marks: true
        default: false
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
