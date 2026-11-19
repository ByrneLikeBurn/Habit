import SwiftUI
import SwiftData
import HabitKit

/// You's Gentle Mode section: "Pause everything" and "Pause for dates", each with one line saying what it does.
struct GentleModeSection: View {
    @Environment(Settings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.style) private var style
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(filter: #Predicate<Pause> { $0.habit == nil }) private var shared: [Pause]
    let datesPage: YouView.Page

    var body: some View {
        let clock = settings.clock
        let today = clock.today
        let everythingOn = shared.contains { $0.isEverything && $0.covers(today) && $0.endDay == nil }
        let resumesTomorrow = shared.contains { $0.isEverything && $0.endDay == today.rawValue }
        Section {
            Toggle(isOn: Binding(
                get: { everythingOn },
                set: { on in
                    if on { model.pauseEverything(context: context, clock: clock) }
                    else { model.resumeEverything(context: context, clock: clock) }
                }
            )) {
                TwoLines(
                    title: String(localized: "Pause everything"),
                    detail: resumesTomorrow && !everythingOn
                        ? String(localized: "Resumes tomorrow. Today stays paused.")
                        : String(localized: "Until you turn it off.")
                )
            }
            .accessibilityIdentifier("you-pause-everything")
            NavigationLink(value: datesPage) {
                TwoLines(title: String(localized: "Pause for dates"), detail: datesDetail(today: today, clock: clock))
            }
        } header: {
            Label {
                Text("Gentle Mode", comment: "Feature name. Translate as a concept (rest, easy days). Do not translate 'Mode' literally.")
            } icon: {
                Image(systemName: "pause.circle").accessibilityHidden(true)
            }
        } footer: {
            Text(PauseText.helper(showRuns: settings.showRuns))
        }
    }

    /// The coming or current dates, if any. Otherwise what the row does.
    private func datesDetail(today: DayKey, clock: HabitClock) -> String {
        let coming = shared.filter { $0.isDates && ($0.end ?? today) >= today }.sorted { $0.startDay < $1.startDay }
        guard let next = coming.first else {
            return String(localized: "Choose a first and last day. Dates can be in the past.")
        }
        return PauseText.range(next, clock: clock)
    }
}

/// A row title with one line of description under it.
struct TwoLines: View {
    let title: String
    let detail: String
    @Environment(\.style) private var style

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(style.label(.body))
            Text(detail).font(style.label(.footnote)).foregroundStyle(style.secondary)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

/// "Pause for dates": dated pauses coming and earlier, and "Pause everything" pauses that have ended.
/// Each can be opened and changed.
struct PauseDatesView: View {
    @Environment(Settings.self) private var settings
    @Environment(\.style) private var style
    @Query(filter: #Predicate<Pause> { $0.habit == nil }, sort: \Pause.startDay, order: .reverse) private var shared: [Pause]
    @State private var request: PauseRequest? = LaunchOptions.current.screen == .pauseDatesNew ? PauseRequest(pause: nil) : nil

    var body: some View {
        let clock = settings.clock
        let today = clock.today
        let coming = shared.filter { ($0.end ?? today) >= today }.sorted { $0.startDay < $1.startDay }
        let earlier = shared.filter { ($0.end ?? today) < today }
        List {
            if shared.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No dates yet. Choose a first and last day, and every habit is paused on those days.")
                        .font(style.label(.body))
                        .foregroundStyle(style.secondary)
                    Button("Choose dates") { request = PauseRequest(pause: nil) }
                        .buttonStyle(.outlinedCapsule)
                }
                .padding(.vertical, 8)
            }
            if !coming.isEmpty {
                Section("Now and coming") { rows(coming, clock: clock) }
            }
            if !earlier.isEmpty {
                Section {
                    rows(earlier, clock: clock)
                } header: {
                    Text("Earlier")
                } footer: {
                    Text("Open one to change its dates.")
                }
            }
        }
        .listRowBackground(style.paper)
        .foregroundStyle(style.text, style.secondary, style.tertiary)
        .paperBackground(style)
        .navigationTitle("Pause for dates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    request = PauseRequest(pause: nil)
                } label: {
                    Label("Add dates", systemImage: "plus")
                }
            }
        }
        .sheet(item: $request) { PauseDatesForm(pause: $0.pause, clock: clock) }
        .task {
            // Screenshots: the form for the coming pause.
            if LaunchOptions.current.screen == .pauseForm, request == nil, let first = coming.first(where: \.isDates) { request = PauseRequest(pause: first) }
        }
    }

    private func rows(_ pauses: [Pause], clock: HabitClock) -> some View {
        ForEach(pauses) { pause in
            Button {
                request = PauseRequest(pause: pause)
            } label: {
                HStack {
                    Text(PauseText.range(pause, clock: clock)).font(style.label(.body))
                    Spacer(minLength: 12)
                    Image(systemName: "chevron.forward").font(style.label(.footnote)).foregroundStyle(style.tertiary).accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Opens its dates"))
        }
    }
}

/// The form for a new or existing pause with no habit. Save is off until the last day is set and is not
/// before the first. The form says what the dates would change.
struct PauseDatesForm: View {
    let pause: Pause?
    @Environment(Settings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.style) private var style
    @Query private var habits: [Habit]
    @Query(filter: #Predicate<Pause> { $0.habit == nil }) private var shared: [Pause]
    @State private var first: Date
    @State private var last: Date?

    init(pause: Pause?, clock: HabitClock) {
        self.pause = pause
        _first = State(initialValue: clock.date(for: pause?.start ?? clock.today))
        _last = State(initialValue: pause?.end.map { clock.date(for: $0) })
    }

    var body: some View {
        let clock = settings.clock
        let firstDay = clock.dayKey(for: first)
        let lastDay = last.map { clock.dayKey(for: $0) }
        let canSave = lastDay.map { $0 >= firstDay } ?? (pause != nil && pause?.endDay == nil)
        // Worked out once per draw, for the footer and for Save's VoiceOver hint.
        let impact = lastDay.flatMap { $0 >= firstDay ? impactLines(firstDay...$0, clock: clock) : nil } ?? []
        NavigationStack {
            Form {
                Section {
                    if let pause, pause.start <= clock.today {
                        // A pause that has begun keeps its first day on or before today, so ending it
                        // always goes through the ending rule.
                        DatePicker("First day", selection: $first, in: ...clock.date(for: clock.today), displayedComponents: .date)
                    } else {
                        DatePicker("First day", selection: $first, displayedComponents: .date)
                    }
                    if let lastBinding = Binding($last) {
                        DatePicker("Last day", selection: lastBinding, in: first..., displayedComponents: .date)
                    } else {
                        LabeledContent("Last day") {
                            // A first day in the past most often starts a gap that ran to yesterday.
                            Button("Choose a date") {
                                last = clock.dayKey(for: first) < clock.today ? clock.date(for: clock.today.adding(days: -1)) : first
                            }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("choose-last-day")
                        }
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        // The helper is said once, in You's Gentle Mode section, not again on this path.
                        if pause == nil {
                            Text("Every habit is paused on these days. The dates can be in the past.")
                        } else {
                            Text("Every habit is paused on these days.")
                        }
                        // Save is off until the dates make a pause. This says why.
                        if lastDay == nil && pause == nil {
                            Text("Choose a last day to save.")
                        } else if let lastDay, lastDay < firstDay {
                            Text("The last day is before the first day. Move one of them to save.")
                        }
                        ForEach(impact, id: \.self) { Text($0) }
                    }
                }
                .listRowBackground(style.paper)
                if let pause { endSection(pause, clock: clock) }
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(style.text, style.secondary, style.tertiary)
            .paperBackground(style)
            .environment(\.calendar, clock.calendar)
            .environment(\.timeZone, clock.calendar.timeZone)
            .navigationTitle("Pause for dates")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    // The impact lines change as dates are picked. VoiceOver hears them on Save.
                    Button("Save") { save(firstDay, lastDay) }
                        .disabled(!canSave)
                        .accessibilityHint(Text(impact.joined(separator: " ")))
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 320)
        #endif
    }

    /// A pause that has started offers "Resume tomorrow". One that has not, or has ended, offers "Remove".
    @ViewBuilder
    private func endSection(_ pause: Pause, clock: HabitClock) -> some View {
        let today = clock.today
        let running = pause.start < today && (pause.end ?? today) >= today
        Section {
            Button(running ? "Resume tomorrow" : "Remove") {
                if running {
                    model.resumeDates(pause, context: context, clock: clock)
                } else {
                    model.removePause(pause, context: context)
                }
                dismiss()
            }
            .buttonStyle(.outlinedCapsule)
            .accessibilityIdentifier("pause-form-end")
        } footer: {
            if running {
                Text("Today stays paused. Every habit starts again tomorrow.")
            } else {
                // The Undo line after Remove says it can be undone.
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(impactLines(nil, clock: clock), id: \.self) { Text($0) }
                }
            }
        }
        .listRowBackground(style.paper)
    }

    /// What saving, or with `range` nil removing, would change.
    private func impactLines(_ range: ClosedRange<DayKey>?, clock: HabitClock) -> [String] {
        let old = pause.map { $0.start...max($0.start, $0.end ?? clock.today) }
        let others = shared.filter { $0.id != pause?.id }
        let impact = PauseImpact.of(old: old, new: range, habits: habits, otherShared: others, today: clock.today)
        var lines: [String] = []
        if impact.logsGainPause > 0 {
            lines.append(String(localized: "With these dates, \(impact.logsGainPause) logged days will show as logged while paused.", comment: "Pause for dates form. The number is how many logged days, across all habits, change mark."))
        }
        if impact.logsLosePause > 0 {
            lines.append(String(localized: "\(impact.logsLosePause) logged days will show as they were before the pause.", comment: "Pause for dates form, when dates are moved or shortened. The number is how many logged days change back."))
        }
        if pause != nil {
            if impact.daysGainPause > 0 {
                lines.append(String(localized: "\(impact.daysGainPause) more days will be paused.", comment: "Pause for dates form, when changing dates. The number is calendar days."))
            }
            if impact.daysLosePause > 0 {
                lines.append(String(localized: "\(impact.daysLosePause) days will no longer be paused.", comment: "Pause for dates form, when changing or removing dates. The number is calendar days."))
            }
            // Days before today that lose their pause may have no log, so a run through them may get shorter.
            if let old, impact.daysLosePause > 0, old.lowerBound < clock.today, range.map({ old.lowerBound < $0.lowerBound || old.upperBound > $0.upperBound }) ?? true {
                lines.append(String(localized: "A run through these days may get shorter."))
            }
        }
        return lines
    }

    private func save(_ first: DayKey, _ last: DayKey?) {
        model.saveDates(pause, first: first, last: last, context: context)
        dismiss()
    }
}

