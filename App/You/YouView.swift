import SwiftUI
import SwiftData
import HabitKit

struct YouView: View {
    /// On the Mac this is the Settings window. Export and Import are in the File menu there.
    var isMacSettings = false
    @Environment(Settings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.style) private var style
    @Query private var habits: [Habit]
    @State private var path: [Page] = LaunchOptions.current.screen.flatMap(Page.init(screen:)).map { [$0] } ?? []

    nonisolated enum Page: Hashable {
        case appearance, dayStart, marks, archived

        init?(screen: LaunchOptions.Screen) {
            switch screen {
            case .appearance: self = .appearance
            case .archived: self = .archived
            case .marks: self = .marks
            default: return nil
            }
        }
    }

    var body: some View {
        @Bindable var settings = settings
        let archivedCount = habits.filter { $0.isArchived && $0.deletedAt == nil }.count

        NavigationStack(path: $path) {
            List {
                if !isMacSettings {
                    Text("You")
                        .font(style.display(.largeTitle, weight: .semibold))
                        .foregroundStyle(style.text, style.secondary, style.tertiary)
                        .accessibilityAddTraits(.isHeader)
                        .listRowBackground(style.paper)
                        .listRowSeparator(.hidden)
                }

                Section("Look") {
                    NavigationLink(value: Page.appearance) {
                        LabeledContent("Appearance", value: appearanceSummary)
                    }
                }
                Section {
                    SettingSwitch(title: "Show runs", isOn: $settings.showRuns)
                    SettingSwitch(title: "Show days not logged", isOn: $settings.showDaysNotLogged)
                } header: {
                    Text("History")
                } footer: {
                    Text("Show runs adds runs and days done to each habit. A run counts the days in a row with any log, even a small one. Days off don't break it. Show days not logged adds an empty outline to past days and the date each habit began.")
                }
                if !isMacSettings {
                    Section {
                        Button("Export a copy") { model.showExport = true }
                        Button("Import a copy") { model.choosingImportFile = true }
                    } header: {
                        Text("Your data")
                    } footer: {
                        Text("Your data lives on this device only.")
                    }
                }
                Section {
                    if !isMacSettings {
                        // Thumb reach has no meaning on the Mac.
                        Toggle("Controls on the left", isOn: $settings.controlsLeading)
                    }
                    NavigationLink(value: Page.dayStart) {
                        LabeledContent("Day starts at", value: DayStartView.label(settings.dayStartHour, clock: settings.clock))
                    }
                } header: {
                    Text("Use")
                }
                Section("Help") {
                    NavigationLink("What the marks mean", value: Page.marks)
                }
                Section("Habits") {
                    NavigationLink(value: Page.archived) {
                        LabeledContent("Archived", value: archivedCount == 0 ? String(localized: "None") : archivedCount.formatted())
                    }
                }
            }
            .listRowBackground(style.paper)
            .frame(maxWidth: 393)
            .frame(maxWidth: .infinity)
            .paperBackground(style)
            .foregroundStyle(style.text, style.secondary, style.tertiary)
            .navigationDestination(for: Page.self) { page in
                switch page {
                case .appearance: AppearanceView()
                case .dayStart: DayStartView()
                case .marks: MarksBoardView()
                case .archived: ArchivedView()
                }
            }
        }
    }

    /// The system switch. At accessibility sizes it sits on its own line with "On" or "Off" in words.
    private struct SettingSwitch: View {
        let title: LocalizedStringKey
        @Binding var isOn: Bool
        @Environment(\.dynamicTypeSize) private var typeSize

        var body: some View {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                    HStack {
                        Toggle(title, isOn: $isOn).labelsHidden()
                        Text(isOn ? "On" : "Off").accessibilityHidden(true)
                    }
                }
                .accessibilityElement(children: .combine)
            } else {
                Toggle(title, isOn: $isOn)
            }
        }
    }

    private var appearanceSummary: String {
        let light: String = switch settings.appearance {
        case .system: String(localized: "System")
        case .paper: String(localized: "Paper")
        case .ink: String(localized: "Ink")
        }
        return [light, settings.accent.displayName].formatted(.list(type: .and, width: .narrow))
    }
}

struct DayStartView: View {
    @Environment(Settings.self) private var settings
    @Environment(\.style) private var style

    static func label(_ hour: Int, clock: HabitClock) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let date = clock.calendar.date(from: components) ?? .now
        return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: clock.calendar.timeZone))
    }

    var body: some View {
        List {
            Section {
                ForEach(Array(HabitClock.dayStartRange), id: \.self) { hour in
                    Button {
                        settings.dayStartHour = hour
                    } label: {
                        HStack {
                            Text(Self.label(hour, clock: settings.clock)).monospacedDigit()
                            Spacer()
                            if settings.dayStartHour == hour {
                                Image(systemName: "checkmark").accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .accessibilityAddTraits(settings.dayStartHour == hour ? .isSelected : [])
                }
            } footer: {
                Text("Logs before this time count for the day before.")
            }
            .listRowBackground(style.paper)
        }
        .foregroundStyle(style.text, style.secondary, style.tertiary)
        .paperBackground(style)
        .navigationTitle("Day starts at")
    }
}

struct ArchivedView: View {
    @Environment(Settings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.style) private var style
    @Environment(\.modelContext) private var context
    @Query private var habits: [Habit]

    var body: some View {
        let archived = habits.filter { $0.isArchived && $0.deletedAt == nil }.sorted { $0.name < $1.name }
        List {
            if archived.isEmpty {
                Text("Nothing archived. An archived habit leaves Today and keeps its history.")
                    .foregroundStyle(style.secondary)
            }
            ForEach(archived) { habit in
                HStack(spacing: 12) {
                    Image(systemName: habit.symbolName).accessibilityHidden(true)
                    Text(habit.name).font(style.display(.body))
                    Spacer()
                    Button("Bring back") {
                        model.bringBack(habit, context: context, all: habits)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .accessibilityLabel(Text("Bring back \(habit.name)"))
                }
                .frame(minHeight: 44)
            }
            .listRowBackground(style.paper)
        }
        .foregroundStyle(style.text, style.secondary, style.tertiary)
        .paperBackground(style)
        .navigationTitle("Archived")
    }
}

/// The marks board. Only marks the app can draw so far are listed. Pausing comes in milestone 3.
struct MarksBoardView: View {
    @Environment(\.style) private var style

    private var rows: [(DayState, Bool, Bool, LocalizedStringResource, LocalizedStringResource)] {
        [
            (.done, true, false, "Done", "The target was met, or a yes-or-no habit was logged."),
            (.partDone, true, true, "Part done", "Some logged, under the target. It still counts."),
            (.blank, true, true, "Adds", "A plus means a tap adds to the count."),
            (.loggedOffSchedule, true, false, "Logged on a day off", "Logged on a day the habit is not set for. It still counts."),
            (.offSchedule, false, false, "Not scheduled", "A dot is a day the habit is not set for."),
            (.blank, true, false, "Today", "The outline marks today. Empty means nothing logged yet."),
        ]
    }

    var body: some View {
        List {
            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        MarkView(state: row.0, isToday: row.1, showsPlus: row.2)
                        // The year view and History month draw this mark smaller and split, so both are shown.
                        // Every row keeps the column, so the labels stay aligned.
                        Group {
                            if row.0 == .loggedOffSchedule { SmallMarkView(state: row.0, size: 12) } else { Color.clear }
                        }
                        .frame(width: 16, height: 16)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.3).font(style.label(.body, weight: .semibold))
                        Text(row.4).font(style.label(.subheadline)).foregroundStyle(style.secondary)
                    }
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
            }
            .listRowBackground(style.paper)
        }
        .foregroundStyle(style.text, style.secondary, style.tertiary)
        .paperBackground(style)
        .navigationTitle("What the marks mean")
    }
}

#Preview("You") {
    YouView().previewEnvironment()
}
