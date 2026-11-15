import SwiftUI
import SwiftData
import HabitKit

struct TodayView: View {
    @Environment(Settings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.style) private var style
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    @Environment(\.scenePhase) private var scenePhase

    @Query private var habits: [Habit]
    @State private var showNotScheduled = LaunchOptions.current.screen == .notScheduled
    @State private var headingScrolled = false
    /// Changes when the day turns over or passes midnight, so Today redraws.
    @State private var dayMark = ""
    #if os(iOS)
    @State private var editMode: EditMode = .inactive
    #endif

    var body: some View {
        let clock = settings.clock
        let today = clock.today
        let split = Ordering.today(habits, day: today)
        let active = Ordering.sorted(habits)

        List {
            TodayHeading(clock: clock)
                .plainRow(style)
                .id(dayMark)

            if active.isEmpty {
                FirstRunView()
                    .plainRow(style)
            } else if split.scheduled.isEmpty {
                EmptyLine(
                    title: String(localized: "Nothing set for today"),
                    detail: String(localized: "Your habits are set for other days.")
                )
                .plainRow(style)
            }

            ForEach(split.scheduled) { habit in
                HabitRow(habit: habit, day: today, actions: actions(for: habit, in: split.scheduled, clock: clock))
                    .habitRow(style, leading: settings.controlsLeading)
            }
            .onMove { source, destination in
                Ordering.move(split.scheduled, from: source, to: destination, all: active)
                try? context.save()
            }

            if !split.notScheduled.isEmpty {
                DisclosureGroup(isExpanded: $showNotScheduled) {
                    ForEach(split.notScheduled) { habit in
                        HabitRow(habit: habit, day: today, actions: actions(for: habit, in: split.notScheduled, clock: clock))
                            .habitRow(style, leading: settings.controlsLeading)
                    }
                    .onMove { source, destination in
                        Ordering.move(split.notScheduled, from: source, to: destination, all: active)
                        try? context.save()
                    }
                } label: {
                    Text("Not scheduled today")
                        .font(style.label(.body))
                        .foregroundStyle(style.secondary)
                        .frame(minHeight: 44)
                }
                .listRowBackground(style.paper)
                .listRowSeparatorTint(style.rule)
            }
        }
        .listStyle(.plain)
        .frame(maxWidth: 393)
        .frame(maxWidth: .infinity)
        .paperBackground(style)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 44
        } action: { _, scrolled in
            headingScrolled = scrolled
        }
        .navigationTitle(headingScrolled ? String(localized: "Today") : "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $editMode)
        .onChange(of: model.isReordering) { _, reordering in
            editMode = reordering ? .active : .inactive
        }
        #endif
        .toolbar {
            if model.isReordering {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { model.isReordering = false }
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        model.showNewHabit = true
                    } label: {
                        Label("New habit", systemImage: "plus")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let line = model.undoLine {
                UndoLineView(line: line)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.feedback)
        .task(id: scenePhase) {
            // Redraw when the day turns over or passes midnight. Nothing is drawn per frame.
            while !Task.isCancelled {
                let c = settings.clock
                let mark = "\(c.today)-\(c.isBeforeDayStart)"
                if mark != dayMark { dayMark = mark }
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    private func actions(for habit: Habit, in list: [Habit], clock: HabitClock) -> HabitRow.Actions {
        let active = Ordering.sorted(habits)
        let index = list.firstIndex { $0.id == habit.id }
        return HabitRow.Actions(
            log: { action in
                model.log(action, habit: habit, context: context, clock: clock, undoManager: undoManager)
            },
            openCount: { model.counting = CountRequest(habit: habit, day: clock.today) },
            edit: { model.editing = habit },
            archive: { model.archive(habit, context: context, clock: clock) },
            move: { model.isReordering = true },
            moveUp: index.flatMap { $0 > 0 ? $0 : nil }.map { i in
                { Ordering.move(list, from: IndexSet(integer: i), to: i - 1, all: active); try? context.save() }
            },
            moveDown: index.flatMap { $0 < list.count - 1 ? $0 : nil }.map { i in
                { Ordering.move(list, from: IndexSet(integer: i), to: i + 2, all: active); try? context.save() }
            }
        )
    }
}

/// The screen heading is content in the display font. It scrolls with the page.
struct TodayHeading: View {
    let clock: HabitClock
    @Environment(\.style) private var style

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Today")
                .font(style.display(.largeTitle, weight: .semibold))
                .foregroundStyle(style.text)
                .accessibilityAddTraits(.isHeader)
            Text(clock.date(for: clock.today).formatted(
                Date.FormatStyle(date: .complete, time: .omitted, locale: clock.calendar.locale ?? .autoupdatingCurrent, calendar: clock.calendar, timeZone: clock.calendar.timeZone)
                    .year(.omitted)
            ))
            .font(style.label(.subheadline))
            .foregroundStyle(style.secondary)
            if clock.isBeforeDayStart {
                Text("Until \(clock.dayStartTimeToday.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: clock.calendar.timeZone)))")
                    .font(style.label(.subheadline))
                    .foregroundStyle(style.secondary)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
    }
}

struct EmptyLine: View {
    let title: String
    let detail: String
    @Environment(\.style) private var style

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(style.display(.title3))
                .foregroundStyle(style.secondary)
            Text(detail)
                .font(style.label(.subheadline))
                .foregroundStyle(style.secondary)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

/// First run: one line of text and one button.
struct FirstRunView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.style) private var style

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            EmptyLine(
                title: String(localized: "Nothing to track yet"),
                detail: String(localized: "Add one small thing you would like to do most days.")
            )
            Button("Add a habit") { model.showNewHabit = true }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .foregroundStyle(style.paper)
                .controlSize(.large)
        }
        .padding(.bottom, 12)
    }
}

/// One line with Undo for a few seconds. With VoiceOver on it stays until the next action.
struct UndoLineView: View {
    let line: UndoLine
    @Environment(AppModel.self) private var model
    @Environment(\.style) private var style
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    var body: some View {
        HStack(spacing: 12) {
            Text(line.message)
                .font(style.label(.subheadline))
                .foregroundStyle(style.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Undo") {
                line.undo()
                model.undoLine = nil
            }
            .font(style.label(.subheadline, weight: .semibold))
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(style.paper)
        .overlay(alignment: .top) {
            Rectangle().fill(style.rule).frame(height: style.ruleWidth)
        }
        .frame(maxWidth: 393)
        .task(id: line.id) {
            guard !voiceOver else { return }
            try? await Task.sleep(for: .seconds(5))
            if model.undoLine?.id == line.id { model.undoLine = nil }
        }
    }
}

extension View {
    func plainRow(_ style: ResolvedStyle) -> some View {
        listRowBackground(style.paper)
            .listRowSeparator(.hidden)
            .moveDisabled(true)
    }

    func habitRow(_ style: ResolvedStyle, leading: Bool) -> some View {
        listRowBackground(style.paper)
            .listRowSeparatorTint(style.rule)
            .listRowInsets(EdgeInsets(top: 0, leading: leading ? 0 : 16, bottom: 0, trailing: leading ? 16 : 0))
    }
}

#Preview("Today") {
    NavigationStack { TodayView() }
        .previewEnvironment()
}

#Preview("Today, Ink") {
    NavigationStack { TodayView() }
        .previewEnvironment(appearance: .ink)
}

#Preview("First run") {
    NavigationStack { TodayView() }
        .previewEnvironment(.empty)
}

#Preview("Nothing set for today") {
    NavigationStack { TodayView() }
        .previewEnvironment(.noneToday)
}
