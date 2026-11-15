import SwiftUI
import SwiftData
import HabitKit

/// New habit and Edit habit. The name is the only required field.
struct HabitFormView: View {
    let habit: Habit?

    @Environment(Settings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.style) private var style
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var habits: [Habit]

    @State private var name: String
    @State private var symbol: String
    @State private var kind: HabitKind
    @State private var targetText: String
    @State private var unit: String
    @State private var tapText: String
    @State private var tapEdited: Bool
    @State private var schedule: Weekdays
    @State private var showMore: Bool
    @State private var confirmDiscard = false
    @FocusState private var nameFocused: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    private let original: Snapshot

    private struct Snapshot: Equatable {
        var name, symbol, targetText, unit, tapText: String
        var kind: HabitKind
        var schedule: Weekdays
    }

    init(habit: Habit?) {
        self.habit = habit
        let startCounted = habit == nil && LaunchOptions.current.screen == .newCount
        let snapshot = Snapshot(
            name: habit?.name ?? (startCounted ? "Drink water" : ""),
            symbol: habit?.symbolName ?? SymbolPicker.symbols[0].name,
            targetText: habit.flatMap { $0.kind == .counted ? $0.target?.formatted() : nil } ?? (startCounted ? "8" : ""),
            unit: habit?.unit ?? (startCounted ? "glasses" : ""),
            tapText: habit.map { $0.tapAmount?.formatted() ?? "" } ?? "1",
            kind: habit?.kind ?? (startCounted ? .counted : .binary),
            schedule: habit?.schedule ?? .all
        )
        original = snapshot
        _name = State(initialValue: snapshot.name)
        _symbol = State(initialValue: snapshot.symbol)
        _kind = State(initialValue: snapshot.kind)
        _targetText = State(initialValue: snapshot.targetText)
        _unit = State(initialValue: snapshot.unit)
        _tapText = State(initialValue: snapshot.tapText)
        _tapEdited = State(initialValue: habit != nil)
        _schedule = State(initialValue: snapshot.schedule)
        // Unit and One tap adds sit under More in New habit, and are open in Edit.
        _showMore = State(initialValue: habit != nil || startCounted)
    }

    private var isEdit: Bool { habit != nil }
    private var kindLocked: Bool { habit?.hasLogs ?? false }
    private var current: Snapshot {
        Snapshot(name: name, symbol: symbol, targetText: targetText, unit: unit, tapText: tapText, kind: kind, schedule: schedule)
    }
    private var hasChanges: Bool { current != original }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var target: Int? { CountText.parse(targetText) }
    private var tapAmount: Int? { CountText.parse(tapText) }

    // Each problem is shown under the field that causes it.
    private var nameProblem: String? {
        trimmedName.isEmpty ? String(localized: "Add a name to continue.") : nil
    }
    private var targetProblem: String? {
        guard kind == .counted, !targetText.isEmpty else { return nil }
        guard let target, target > 0 else { return String(localized: "Type a whole number above 0, or leave it empty.") }
        return nil
    }
    private var tapProblem: String? {
        guard kind == .counted, !tapText.isEmpty else { return nil }
        guard let tapAmount, tapAmount > 0 else { return String(localized: "Type a whole number above 0, or leave it empty.") }
        return nil
    }
    private var scheduleProblem: String? {
        schedule.isEmpty ? String(localized: "Choose at least one day.") : nil
    }
    private var canSave: Bool {
        [nameProblem, targetProblem, tapProblem, scheduleProblem].allSatisfy { $0 == nil }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Stretch after brushing teeth", text: $name, axis: .vertical)
                        .font(style.display(.body))
                        .focused($nameFocused)
                        .submitLabel(.done)
                } header: {
                    Text("Name")
                } footer: {
                    if let nameProblem, !isEdit || hasChanges { Text(nameProblem) }
                }

                Section("Symbol") {
                    SymbolPicker(selection: $symbol)
                }

                Section {
                    if kindLocked {
                        LabeledContent {
                            Text("Cannot change once it has logs")
                                .font(style.label(.footnote))
                        } label: {
                            Text(kind == .counted ? "Count" : "Yes or no")
                        }
                    } else {
                        // A segmented control does not grow with the text, so large sizes get a list.
                        if typeSize.isAccessibilitySize {
                            kindPicker.pickerStyle(.inline)
                        } else {
                            kindPicker.pickerStyle(.segmented)
                        }
                    }
                } header: {
                    Text("Kind")
                }

                if kind == .counted {
                    Section {
                        NumberRow(title: String(localized: "Target each day"), placeholder: String(localized: "None"), text: $targetText)
                    } footer: {
                        Text(targetProblem ?? String(localized: "With no target, any amount counts as done."))
                    }

                    Section {
                        if isEdit {
                            moreFields
                        } else {
                            DisclosureGroup("More", isExpanded: $showMore) { moreFields }
                        }
                    } footer: {
                        if showMore {
                            Text(tapProblem ?? (tapText.isEmpty
                                ? String(localized: "Leave it empty to type an amount each time.")
                                : String(localized: "Each tap on Today adds this much.")))
                        }
                    }
                }

                Section {
                    DayPicker(selection: $schedule, calendar: settings.clock.calendar)
                } header: {
                    Text("Days")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(scheduleProblem ?? WeekdayText.sentence(for: schedule, calendar: settings.clock.calendar))
                        if isEdit { Text("A change applies from today. Earlier days keep what they had.") }
                    }
                }

                if let habit {
                    Section {
                        Button("Archive habit") {
                            dismiss()
                            model.archive(habit, context: context, clock: settings.clock)
                        }
                        .foregroundStyle(style.text, style.secondary, style.tertiary)
                    } footer: {
                        Text("You can bring it back at any time. Its history is kept.")
                    }
                }
            }
            .foregroundStyle(style.text, style.secondary, style.tertiary)
            .paperBackground(style)
            .navigationTitle(isEdit ? String(localized: "Edit habit") : String(localized: "New habit"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges { confirmDiscard = true } else { dismiss() }
                    }
                    .confirmationDialog("Discard changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                        Button("Discard changes", role: .destructive) { dismiss() }
                        Button("Keep editing", role: .cancel) {}
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEdit ? String(localized: "Save") : String(localized: "Add")) { save() }
                        .disabled(!canSave)
                }
            }
            .interactiveDismissDisabled(hasChanges)
            .onChange(of: targetText) {
                // The default tap amount follows the target until the user types one.
                if !tapEdited { tapText = CountText.defaultTapAmount(forTarget: target)?.formatted() ?? "" }
            }
            .onAppear { if !isEdit { nameFocused = true } }
        }
    }

    private var kindPicker: some View {
        Picker("Kind", selection: $kind) {
            Text("Yes or no").tag(HabitKind.binary)
            Text("Count").tag(HabitKind.counted)
        }
        .labelsHidden()
    }

    @ViewBuilder
    private var moreFields: some View {
        LabeledContent {
            TextField("Unit", text: $unit, prompt: Text("None"))
                .multilineTextAlignment(.trailing)
        } label: {
            Text("Unit")
        }
        NumberRow(
            title: String(localized: "One tap adds"),
            placeholder: String(localized: "Type each time"),
            text: Binding(get: { tapText }, set: { tapText = $0; tapEdited = true })
        )
    }

    private func save() {
        guard canSave else { return }
        let clock = settings.clock
        let resolvedTap: Int? = kind == .binary ? 1 : tapAmount
        let resolvedTarget: Int? = kind == .binary ? 1 : target
        if let habit {
            habit.name = trimmedName
            habit.symbolName = symbol
            if !kindLocked { habit.kind = kind }
            habit.unit = unit.trimmingCharacters(in: .whitespaces)
            habit.tapAmount = resolvedTap
            habit.setRule(target: resolvedTarget, schedule: schedule, from: clock.today)
        } else {
            let new = Habit(
                name: trimmedName,
                symbolName: symbol,
                kind: kind,
                target: resolvedTarget,
                unit: unit.trimmingCharacters(in: .whitespaces),
                schedule: schedule,
                tapAmount: resolvedTap,
                sortIndex: Ordering.nextIndex(habits),
                createdAt: clock.now(),
                firstDay: clock.today
            )
            context.insert(new)
        }
        try? context.save()
        dismiss()
    }
}

/// A labelled number that can be typed. Arrows are never the only way to reach a number.
struct NumberRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    @Environment(\.style) private var style

    var body: some View {
        LabeledContent {
            TextField(title, text: $text, prompt: Text(placeholder))
                .font(style.count(.body))
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
        } label: {
            Text(title)
        }
    }
}

#Preview("New habit") {
    Color.clear.sheet(isPresented: .constant(true)) { HabitFormView(habit: nil) }
        .previewEnvironment()
}
