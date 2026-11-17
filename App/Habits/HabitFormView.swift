import SwiftUI
import SwiftData
import HabitKit

/// New habit and Edit habit, as drawn in `sheet-new-habit.png`. One column on every platform:
/// labels above their fields. The name is the only required field, and a habit may have no set days.
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
    @State private var showUnitPage = false
    @State private var confirmDiscard = false
    @FocusState private var nameFocused: Bool

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
            // No symbol until one is chosen. Every input is optional.
            symbol: habit?.symbolName ?? (startCounted ? "drop" : ""),
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
    }

    private var isEdit: Bool { habit != nil }
    private var kindLocked: Bool { habit?.hasLogs ?? false }
    private var current: Snapshot {
        Snapshot(name: name, symbol: symbol, targetText: targetText, unit: unit, tapText: tapText, kind: kind, schedule: schedule)
    }
    private var hasChanges: Bool { current != original }

    private var draft: HabitDraft {
        HabitDraft(name: name, kind: kind, targetText: targetText, tapText: tapText, schedule: schedule)
    }
    private var target: Int? { CountText.parse(targetText) }
    private var tapAmount: Int? { CountText.parse(tapText) }

    /// The rule lives in HabitKit. The form only places each problem under its field.
    private var problems: [HabitForm.Problem] { HabitForm.problems(draft) }
    private var canSave: Bool { problems.isEmpty }
    private var nameProblem: String? {
        problems.contains(.emptyName) ? String(localized: "Add a name to continue.") : nil
    }
    private var targetProblem: String? {
        problems.contains(.target) ? String(localized: "Type a whole number above 0, or leave it empty.") : nil
    }
    private var tapProblem: String? {
        problems.contains(.tapAmount) ? String(localized: "Type a whole number above 0, or leave it empty.") : nil
    }

    private var title: String { isEdit ? String(localized: "Edit habit") : String(localized: "New habit") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    #if os(macOS)
                    Text(title)
                        .font(style.label(.headline, weight: .semibold))
                        .accessibilityAddTraits(.isHeader)
                    #endif
                    nameSection
                    symbolSection
                    loggingSection
                    daysSection
                    if let habit { archiveSection(habit) }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .foregroundStyle(style.text, style.secondary, style.tertiary)
            .paperBackground(style)
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(isPresented: $showUnitPage) { unitPage }
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
                // The default log amount follows the target until the user types one.
                if !tapEdited { tapText = CountText.defaultTapAmount(forTarget: target)?.formatted() ?? "" }
            }
            .task {
                guard !isEdit else { return }
                // Focus after the sheet has settled; earlier focus is dropped.
                try? await Task.sleep(for: .milliseconds(350))
                nameFocused = true
            }
        }
        #if os(macOS)
        // One column, 420 points wide, 24-point margins. Cancel and Add sit at the bottom right.
        .frame(width: 420)
        .frame(minHeight: 520, idealHeight: 660)
        #endif
    }

    // MARK: Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel("Name")
            TextField(
                String(localized: "Name"),
                text: $name,
                prompt: Text("For example, stretch after brushing teeth").foregroundStyle(style.tertiary),
                axis: .vertical
            )
            .lineLimit(1...4)
            .textFieldStyle(.plain)
            .font(style.display(.body))
            .focused($nameFocused)
            .submitLabel(.done)
            // The same length import accepts, so a habit made here always exports and imports.
            .onChange(of: name) { _, value in
                if value.count > ImportLimits.maxTextLength { name = String(value.prefix(ImportLimits.maxTextLength)) }
            }
            .frame(minHeight: 44)
            FieldRule()
            if let nameProblem, !isEdit || hasChanges { hint(nameProblem) }
        }
    }

    private var symbolSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            FieldLabel("Symbol")
            SymbolRow(selection: $symbol)
        }
    }

    private var loggingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel("Logging")
            if kindLocked {
                Text(kind == .counted ? "Count" : "Mark done").font(style.label(.body))
                hint(String(localized: "This cannot change once the habit has logs."))
            } else {
                KindChooser(kind: $kind)
                hint(kind == .counted
                     ? String(localized: "Each log adds to the day's total.")
                     : String(localized: "Log once and it is done for the day."))
            }
            if kind == .counted { countFields }
        }
    }

    private var countFields: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Target each day").font(style.label(.body))
                Spacer(minLength: 12)
                TextField(String(localized: "Target each day"), text: $targetText, prompt: Text("None").foregroundStyle(style.tertiary))
                    .textFieldStyle(.plain)
                    .font(style.count(.body))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .padding(.bottom, 4)
                    .overlay(alignment: .bottom) { FieldRule() }
            }
            .frame(minHeight: 48)
            hint(targetProblem ?? String(localized: "With no target, any amount counts as done."))
            FieldRule().padding(.top, 8)
            Button { showUnitPage = true } label: {
                HStack {
                    Text("Unit and log amount").font(style.label(.body)).foregroundStyle(style.text)
                    Spacer(minLength: 12)
                    Text(unitSummary).font(style.label(.body)).foregroundStyle(style.secondary).lineLimit(1)
                    Image(systemName: "chevron.forward").foregroundStyle(style.secondary).accessibilityHidden(true)
                }
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let tapProblem { hint(tapProblem) }
            FieldRule()
        }
    }

    private var daysSection: some View {
        let calendar = settings.clock.calendar
        return VStack(alignment: .leading, spacing: 8) {
            FieldLabel("Repeats on")
            DayButtons(selection: $schedule, calendar: calendar)
            hint(Self.summary(for: schedule, calendar: calendar))
            DayShortcuts(selection: $schedule, calendar: calendar)
            if isEdit { hint(String(localized: "A change applies from today. Earlier days keep what they had.")) }
        }
    }

    private func archiveSection(_ habit: Habit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            FieldRule()
            Button {
                dismiss()
                model.archive(habit, context: context, clock: settings.clock)
            } label: {
                Text("Archive habit")
                    .underline()
                    .font(style.label(.body))
                    .foregroundStyle(style.text)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            hint(String(localized: "You can bring it back at any time. Its history is kept."))
        }
    }

    /// Unit and log amount, one step in from the form.
    private var unitPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel("Unit")
                    TextField(String(localized: "Unit"), text: $unit, prompt: Text("None").foregroundStyle(style.tertiary))
                        .textFieldStyle(.plain)
                        .font(style.label(.body))
                        .frame(minHeight: 44)
                        .onChange(of: unit) { _, value in
                            if value.count > ImportLimits.maxTextLength { unit = String(value.prefix(ImportLimits.maxTextLength)) }
                        }
                    FieldRule()
                }
                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel("One log adds")
                    TextField(
                        String(localized: "One log adds"),
                        text: Binding(get: { tapText }, set: { tapText = $0; tapEdited = true }),
                        prompt: Text("Type each time").foregroundStyle(style.tertiary)
                    )
                    .textFieldStyle(.plain)
                    .font(style.count(.body))
                    .frame(minHeight: 44)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    FieldRule()
                    hint(tapProblem ?? (tapText.isEmpty
                        ? String(localized: "Leave it empty to type an amount each time.")
                        : String(localized: "Each log on Today adds this much.")))
                }
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(style.text, style.secondary, style.tertiary)
        .paperBackground(style)
        .navigationTitle("Unit and log amount")
    }

    private var unitSummary: String {
        let unitPart = unit.trimmingCharacters(in: .whitespaces).isEmpty ? String(localized: "No unit") : unit
        let amountPart = tapText.isEmpty ? String(localized: "Type each time") : tapText
        return [unitPart, amountPart].formatted(.list(type: .and, width: .narrow))
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(style.label(.footnote))
            .foregroundStyle(style.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The line under the day buttons. The read-only sentence in Habit detail comes from `WeekdayText`.
    static func summary(for days: Weekdays, calendar: Calendar) -> String {
        if days == .all {
            return String(localized: "Every day. Choose a day to leave it out.", comment: "Under the day buttons when all seven are chosen. \"Leave it out\" means stop the habit repeating on that day: choosing a chosen day clears it.")
        }
        if days.isEmpty {
            return String(localized: "No set days. Log it on any day.", comment: "Under the day buttons when none is chosen. The habit can still be saved, and shows on Today every day.")
        }
        return WeekdayText.sentence(for: days, calendar: calendar)
    }

    private func save() {
        guard canSave else { return }
        let clock = settings.clock
        let resolvedTap: Int? = kind == .binary ? 1 : tapAmount
        let resolvedTarget: Int? = kind == .binary ? 1 : target
        if let habit {
            habit.name = draft.trimmedName
            habit.symbolName = symbol
            if !kindLocked { habit.kind = kind }
            habit.unit = unit.trimmingCharacters(in: .whitespaces)
            habit.tapAmount = resolvedTap
            habit.setRule(target: resolvedTarget, schedule: schedule, from: clock.today)
        } else {
            let new = Habit(
                name: draft.trimmedName,
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

/// "Mark done" and "Count". The segments fill the width. A segmented control does not grow with the
/// text, so accessibility sizes get two full-width buttons with a checkmark on the chosen one.
struct KindChooser: View {
    @Binding var kind: HabitKind
    @Environment(\.style) private var style
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 0) {
                option(.binary, "Mark done")
                option(.counted, "Count")
            }
        } else {
            Picker("Logging", selection: $kind) {
                Text("Mark done").tag(HabitKind.binary)
                Text("Count").tag(HabitKind.counted)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
        }
    }

    private func option(_ value: HabitKind, _ title: LocalizedStringKey) -> some View {
        Button { kind = value } label: {
            HStack {
                Text(title).font(style.label(.body, weight: kind == value ? .semibold : .regular))
                Spacer()
                if kind == value { Image(systemName: "checkmark").accessibilityHidden(true) }
            }
            .foregroundStyle(style.text)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(kind == value ? .isSelected : [])
    }
}

#Preview("New habit") {
    Color.clear.sheet(isPresented: .constant(true)) { HabitFormView(habit: nil) }
        .previewEnvironment()
}
