import SwiftUI
import SwiftData
import HabitKit

/// One habit on one day, opened from Habit detail or History. It names the habit and the date.
/// Every change writes through LogHabitIntent, closes the sheet and shows the Undo line.
struct DaySheet: View {
    let habit: Habit
    let day: DayKey

    @Environment(Settings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.style) private var style
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    @Environment(\.sharedPauses) private var sharedPauses
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var amountText = "1"
    @State private var selection: TextSelection?
    @FocusState private var amountFocused: Bool

    private var amount: Int? {
        CountText.parse(amountText).flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        let clock = settings.clock
        let words = DayWords(clock: clock)
        let total = habit.total(on: day)
        let state = habit.state(on: day, today: clock.today, total: total, sharedPauses: sharedPauses)

        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    switch habit.kind {
                    case .binary: binary(total: total, state: state)
                    case .counted: counted(total: total, state: state)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .paperBackground(style)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text(habit.name).font(style.label(.caption2)).foregroundStyle(style.secondary).lineLimit(1)
                        Text(words.long(day)).font(style.label(.subheadline, weight: .semibold)).foregroundStyle(style.text)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
    }

    // MARK: Yes or no

    @ViewBuilder
    private func binary(total: Int, state: DayState) -> some View {
        if total > 0 {
            heading(stateWords(state) ?? String(localized: "Done"))
            textButton("Clear this day") { apply(.clear) }
        } else {
            heading(state == .offSchedule ? String(localized: "Not scheduled") : String(localized: "Nothing logged"))
            if state == .offSchedule { note("A log here still counts.") }
            primaryButton("Mark done") { apply(.markDone) }
        }
    }

    // MARK: Counted

    @ViewBuilder
    private func counted(total: Int, state: DayState) -> some View {
        let target = habit.rule(on: day).target
        if total > 0 {
            Text(total.formatted())
                .font(style.count(.largeTitle))
                .foregroundStyle(style.text)
            Text(CountText.sheetCaption(target: target, unit: habit.unit, dayName: String(localized: "that day")))
                .font(style.label(.subheadline))
                .foregroundStyle(style.secondary)
            if let words = stateWords(state), state == .loggedOffSchedule || state == .loggedWhilePaused {
                note(LocalizedStringKey(words))
            }
        } else {
            // At zero a count reads like a yes-or-no habit. "of 8 glasses" waits for a log.
            heading(state == .offSchedule ? String(localized: "Not scheduled") : String(localized: "Nothing logged"))
            if state == .offSchedule { note("A log here still counts.") }
        }

        Text("Amount to add or take away")
            .font(style.label(.footnote))
            .foregroundStyle(style.secondary)
            .padding(.top, 8)
        TextField("Amount", text: $amountText, selection: $selection)
            .font(style.count(.title))
            .foregroundStyle(style.text)
            .multilineTextAlignment(.center)
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .focused($amountFocused)
            .frame(maxWidth: 120, minHeight: 44)
            .overlay(alignment: .bottom) {
                Rectangle().fill(style.secondary).frame(height: style.ruleWidth * 2)
            }
            .accessibilityLabel(Text("Amount to add or take away"))
            .onSubmit { if let amount { apply(.add(amount)) } }
            .onChange(of: amountFocused) { _, focused in
                guard focused else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(50))
                    selection = TextSelection(range: amountText.startIndex..<amountText.endIndex)
                }
            }
        if amount == nil {
            note("Type a whole number above 0.")
        }
        primaryButton("Add") { if let amount { apply(.add(amount)) } }
            .disabled(amount == nil)

        let stack = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 20))
        stack {
            textButton("Take away") { if let amount { apply(.takeAway(amount)) } }
                .disabled(amount == nil || total == 0)
            if total > 0 {
                textButton("Clear this day") { apply(.clear) }
            }
        }
    }

    // MARK: Parts

    private func stateWords(_ state: DayState) -> String? {
        switch state {
        case .loggedOffSchedule: String(localized: "Logged on a day off")
        case .loggedWhilePaused: String(localized: "Logged while paused")
        case .partDone: String(localized: "Part done")
        case .done: String(localized: "Done")
        default: nil
        }
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(style.display(.title2))
            .foregroundStyle(style.text)
            .multilineTextAlignment(.center)
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(style.label(.footnote))
            .foregroundStyle(style.secondary)
            .multilineTextAlignment(.center)
    }

    private func primaryButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(minWidth: 96, maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, minHeight: 32)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .foregroundStyle(style.paper)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
    }

    private func textButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .underline()
                .font(style.label(.subheadline, weight: .semibold))
                .foregroundStyle(style.text)
                .frame(minWidth: 44, maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func apply(_ action: LogAction) {
        model.log(action, habit: habit, day: day, context: context, clock: settings.clock, undoManager: undoManager)
        dismiss()
    }
}

/// "Add a past day": a date up to today, then the day sheet.
struct PastDayPicker: View {
    let habit: Habit

    @Environment(Settings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.style) private var style
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date = .now

    var body: some View {
        let clock = settings.clock
        NavigationStack {
            Form {
                DatePicker("Day", selection: $date, in: ...clock.date(for: clock.today), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.calendar, clock.calendar)
                    .environment(\.timeZone, clock.calendar.timeZone)
            }
            .scrollContentBackground(.hidden)
            .paperBackground(style)
            .navigationTitle("Add a past day")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Next") {
                        // The picker gives a calendar date, not an instant in a habit day, so read its fields directly.
                        var gregorian = Calendar(identifier: .gregorian)
                        gregorian.timeZone = clock.calendar.timeZone
                        let c = gregorian.dateComponents([.year, .month, .day], from: date)
                        let chosen = min(DayKey(year: c.year ?? 2000, month: c.month ?? 1, day: c.day ?? 1), clock.today)
                        dismiss()
                        Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            model.daySheet = DayRequest(habit: habit, day: chosen)
                        }
                    }
                }
            }
        }
        .onAppear { date = clock.date(for: clock.today.adding(days: -1)) }
    }
}
