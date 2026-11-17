import SwiftUI
import SwiftData
import HabitKit

struct RootView: View {
    @Environment(Settings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Pause> { $0.habit == nil }) private var sharedPauses: [Pause]

    var body: some View {
        if LaunchOptions.current.screen == .contrast {
            StyledScreen { ContrastBoard() }
        } else {
            main
        }
    }

    private var main: some View {
        @Bindable var model = model
        return StyledScreen {
            TabView(selection: $model.tab) {
                Tab("Today", systemImage: "calendar", value: AppTab.today) {
                    NavigationStack(path: $model.todayPath) {
                        TodayScreen()
                            .navigationDestination(for: DetailRoute.self) { HabitDetailView(route: $0, tab: .today) }
                    }
                    .undoLineInset(.today)
                }
                Tab("History", systemImage: "square.grid.2x2", value: AppTab.history) {
                    NavigationStack(path: $model.historyPath) {
                        HistoryView()
                            .navigationDestination(for: DetailRoute.self) { HabitDetailView(route: $0, tab: .history) }
                    }
                    .undoLineInset(.history)
                }
                #if !os(macOS)
                Tab("You", systemImage: "person.crop.circle", value: AppTab.you) {
                    YouView()
                }
                #endif
            }
            .tabViewStyle(.sidebarAdaptable)
            .environment(\.sharedPauses, sharedPauses)
            .modifier(ImportPresenter())
            .sheet(isPresented: $model.showNewHabit) {
                HabitFormView(habit: nil, today: settings.clock.today)
            }
            .sheet(item: $model.editing) { habit in
                HabitFormView(habit: habit, today: settings.clock.today)
            }
            .sheet(item: $model.counting) { request in
                CountSheet(habit: request.habit, day: request.day)
            }
            .sheet(item: $model.daySheet) { request in
                DaySheet(habit: request.habit, day: request.day)
            }
            .sheet(item: $model.pickingPastDay, onDismiss: {
                // The day sheet opens once the picker has gone, with no timer.
                if let next = model.pastDayChosen {
                    model.pastDayChosen = nil
                    model.daySheet = next
                }
            }) { habit in
                PastDayPicker(habit: habit)
            }
        }
        .onAppear {
            if LaunchOptions.current.screen?.opensYou == true { model.tab = .you }
            if LaunchOptions.current.screen?.opensHistory == true { model.tab = .history }
            openLaunchScreen()
        }
    }

    /// Opens the screen named by `-screen`, for screenshots.
    private func openLaunchScreen() {
        guard let screen = LaunchOptions.current.screen else { return }
        let habits = Ordering.sorted((try? context.fetch(FetchDescriptor<Habit>())) ?? [])
        let clock = settings.clock
        switch screen {
        case .new, .newCount, .symbols:
            model.showNewHabit = true
        case .edit, .editDays:
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
        case .undoLong:
            // The longest fixture name, so the line is checked at its longest.
            if let habit = habits.filter({ !$0.isArchived }).max(by: { $0.name.count < $1.name.count }) {
                model.archive(habit, context: context, clock: clock)
            }
        case .undoLongPast:
            // The longest name, cleared on a past day: the line with the longest status.
            if let habit = habits.filter({ !$0.isArchived }).max(by: { $0.name.count < $1.name.count }) {
                // A day in the last week with a log, so the tap clears it. With none, no line shows,
                // and the UI test that uses this screen fails on the fixture, not on the view.
                if let day = (1...7).map({ clock.today.adding(days: -$0) }).first(where: { habit.total(on: $0) > 0 }) {
                    model.log(.tap, habit: habit, day: day, context: context, clock: clock, undoManager: nil)
                }
            }
        case .undoCount:
            if let habit = habits.first(where: { $0.kind == .counted && !$0.isArchived }) {
                model.log(.tap, habit: habit, day: clock.today, context: context, clock: clock, undoManager: nil)
            }
        case .history, .historyMonth:
            break
        case .detailWeek, .detailMonth, .detailYear, .detailRuns:
            // Runs are shown in the week view, where the stats fit on one screen.
            let kind: PeriodKind = screen == .detailWeek || screen == .detailRuns ? .week : (screen == .detailYear ? .year : .month)
            if let habit = habits.first(where: { $0.kind == .counted }) {
                model.openDetail(habit, kind: kind, anchor: clock.today, from: .today)
            }
        case .detailEmpty:
            if let habit = habits.first(where: { !$0.hasLogs }) {
                model.openDetail(habit, anchor: clock.today, from: .today)
            }
        case .day, .dayDone, .dayOff, .dayCount:
            let past = (1...30).map { clock.today.adding(days: -$0) }
            let pick: (Habit, DayKey)?
            switch screen {
            case .dayCount:
                pick = habits.first { $0.kind == .counted }.flatMap { h in past.first { h.total(on: $0) > 0 }.map { (h, $0) } }
            case .dayDone:
                pick = habits.first { $0.kind == .binary && $0.schedule == .all }.flatMap { h in past.first { h.total(on: $0) > 0 }.map { (h, $0) } }
            case .dayOff:
                pick = habits.first { $0.schedule != .all && $0.kind == .binary }.flatMap { h in past.first { !h.isScheduled(on: $0) && h.total(on: $0) == 0 }.map { (h, $0) } }
            default:
                pick = habits.first { $0.kind == .binary && $0.schedule == .all }.flatMap { h in past.first { h.total(on: $0) == 0 }.map { (h, $0) } }
            }
            if let (habit, day) = pick {
                model.openDetail(habit, anchor: clock.today, from: .today)
                model.daySheet = DayRequest(habit: habit, day: day)
            }
        case .export:
            model.showExport = true
        case .importPreview, .importDone, .importNothing, .importNotHabit, .importNewer:
            model.importStage = Fixtures.importStage(screen, context: context, clock: clock)
        case .contrast:
            break
        default:
            break
        }
    }
}

extension LaunchOptions.Screen {
    var opensYou: Bool {
        switch self {
        case .you, .appearance, .archived, .marks, .export, .importPreview, .importDone, .importNothing, .importNotHabit, .importNewer: true
        default: false
        }
    }

    var opensHistory: Bool {
        switch self {
        case .history, .historyMonth: true
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
