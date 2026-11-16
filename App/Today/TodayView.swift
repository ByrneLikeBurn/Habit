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
    /// Only today's events are fetched, so Today costs the same on day 1 and day 1,000.
    @Query private var todaysEvents: [LogEvent]
    @State private var showNotScheduled = LaunchOptions.current.screen == .notScheduled
    @State private var headingScrolled = false
    /// Changes when the day turns over or passes midnight, so Today redraws.
    @State private var dayMark = ""
    #if os(iOS)
    @State private var editMode: EditMode = .inactive
    #endif

    /// The day this list shows. TodayScreen rebuilds the view when it changes.
    private let day: DayKey

    init(day: DayKey) {
        self.day = day
        let key = day.rawValue
        _todaysEvents = Query(filter: #Predicate<LogEvent> { $0.dayKey == key })
    }

    var body: some View {
        let clock = settings.clock
        let today = day
        let split = Ordering.today(habits, day: today)
        let active = Ordering.sorted(habits)
        let totals = DayTotals(day: today, events: todaysEvents).totals

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
                let rowActions = actions(for: habit, in: split.scheduled, day: today, clock: clock)
                HabitRow(habit: habit, day: today, total: totals[habit.id] ?? 0, actions: rowActions)
                    .habitRow(style, leading: settings.controlsLeading)
                    .rowSwipeActions(rowActions)
            }
            .onMove { source, destination in
                Ordering.move(split.scheduled, from: source, to: destination, all: active)
                try? context.save()
            }

            if !split.notScheduled.isEmpty {
                DisclosureGroup(isExpanded: $showNotScheduled) {
                    ForEach(split.notScheduled) { habit in
                        let rowActions = actions(for: habit, in: split.notScheduled, day: today, clock: clock)
                        HabitRow(habit: habit, day: today, total: totals[habit.id] ?? 0, actions: rowActions)
                            .habitRow(style, leading: settings.controlsLeading)
                            .rowSwipeActions(rowActions)
                    }
                    .onMove { source, destination in
                        Ordering.move(split.notScheduled, from: source, to: destination, all: active)
                        try? context.save()
                    }
                    Text("A log here still counts.")
                        .font(style.label(.footnote))
                        .foregroundStyle(style.secondary)
                        .padding(.vertical, 8)
                        .plainRow(style)
                } label: {
                    HStack {
                        Text("Not scheduled today")
                        Spacer(minLength: 12)
                        Text(split.notScheduled.count.formatted())
                            .monospacedDigit()
                    }
                    .font(style.label(.body))
                    .foregroundStyle(style.secondary)
                    .frame(minHeight: 44)
                    .accessibilityElement(children: .combine)
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

    private func actions(for habit: Habit, in list: [Habit], day: DayKey, clock: HabitClock) -> HabitRow.Actions {
        let active = Ordering.sorted(habits)
        let index = list.firstIndex { $0.id == habit.id }
        return HabitRow.Actions(
            // The row logs the day it shows, even if the day turns over before the next redraw.
            log: { action in
                model.log(action, habit: habit, day: day, context: context, clock: clock, undoManager: undoManager)
            },
            openCount: { model.counting = CountRequest(habit: habit, day: day) },
            details: { model.openDetail(habit, kind: .month, anchor: day, from: .today) },
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
            // A second, quiet way in for someone moving from another device.
            Button {
                model.choosingImportFile = true
            } label: {
                Text("Import a copy")
                    .underline()
                    .font(style.label(.subheadline))
                    .foregroundStyle(style.text)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 12)
    }
}

/// One line with Undo, drawn as a capsule in reversed ink and paper. It stays until the next
/// action, so no one has to beat a timer to reach it.
struct UndoLineView: View {
    let line: UndoLine
    @Environment(AppModel.self) private var model
    @Environment(\.style) private var style

    var body: some View {
        HStack(spacing: 12) {
            Text(line.message)
                .font(style.label(.subheadline))
                .frame(maxWidth: .infinity, alignment: .leading)
            if let undo = line.undo {
                Button {
                    undo()
                    model.undoLine = nil
                } label: {
                    Text("Undo").underline()
                }
                .buttonStyle(.plain)
                .font(style.label(.subheadline, weight: .semibold))
                .frame(minWidth: 44, minHeight: 44)
            }
        }
        // Reversed text and paper keep the fixed text contrast in both appearances.
        .foregroundStyle(style.paper)
        .padding(.leading, 20)
        .padding(.trailing, 12)
        .padding(.vertical, 2)
        .background(style.text, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: 393)
    }
}

extension View {
    func plainRow(_ style: ResolvedStyle) -> some View {
        listRowBackground(style.paper)
            .listRowSeparator(.hidden)
            .moveDisabled(true)
    }

    /// Edit and Archive, the visible way to reach them now that a tap on the name logs.
    /// Neither uses the destructive role: the app never picks red, and Archive can be undone.
    func rowSwipeActions(_ actions: HabitRow.Actions) -> some View {
        swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Archive", systemImage: "archivebox", action: actions.archive)
            Button("Edit", systemImage: "pencil", action: actions.edit)
            Button("Details", systemImage: "calendar", action: actions.details)
        }
    }

    func habitRow(_ style: ResolvedStyle, leading: Bool) -> some View {
        listRowBackground(style.paper)
            .listRowSeparatorTint(style.rule)
            .listRowInsets(EdgeInsets(top: 0, leading: leading ? 0 : 16, bottom: 0, trailing: leading ? 16 : 0))
    }
}

#Preview("Today") {
    NavigationStack { TodayScreen() }
        .previewEnvironment()
}

#Preview("Today, Ink") {
    NavigationStack { TodayScreen() }
        .previewEnvironment(appearance: .ink)
}

#Preview("First run") {
    NavigationStack { TodayScreen() }
        .previewEnvironment(.empty)
}

#Preview("Nothing set for today") {
    NavigationStack { TodayScreen() }
        .previewEnvironment(.noneToday)
}

/// Raw totals for one day from that day's events, keyed by habit id.
struct DayTotals {
    let totals: [UUID: Int]

    init(day: DayKey, events: [LogEvent]) {
        var totals: [UUID: Int] = [:]
        for event in events where event.dayKey == day.rawValue {
            guard let id = event.habit?.id else { continue }
            let (sum, overflow) = (totals[id] ?? 0).addingReportingOverflow(event.delta)
            totals[id] = overflow ? (event.delta > 0 ? .max : .min) : sum
        }
        self.totals = totals
    }
}

/// Rebuilds Today when the day changes, so its query follows the new day.
struct TodayScreen: View {
    @Environment(Settings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @State private var day: DayKey?

    var body: some View {
        let today = day ?? settings.clock.today
        TodayView(day: today)
            .id(today)
            .task(id: scenePhase) {
                while !Task.isCancelled {
                    let now = settings.clock.today
                    if now != day { day = now }
                    try? await Task.sleep(for: .seconds(30))
                }
            }
            .onChange(of: settings.dayStartHour) { day = settings.clock.today }
    }
}
