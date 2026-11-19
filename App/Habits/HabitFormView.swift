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
    @Environment(\.dynamicTypeSize) private var typeSize
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
    @FocusState private var targetFocused: Bool
    @FocusState private var tapFocused: Bool
    @State private var confirmArchive = false

    private let original: Snapshot

    private struct Snapshot: Equatable {
        var name, symbol, targetText, unit, tapText: String
        var kind: HabitKind
        var schedule: Weekdays
    }

    init(habit: Habit?, today: DayKey) {
        self.habit = habit
        // The form starts from the rule Today shows, not the latest stored values, which may begin later.
        let rule = habit?.ruleForEditing(today: today)
        let startCounted = habit == nil && LaunchOptions.current.screen == .newCount
        let snapshot = Snapshot(
            name: habit?.name ?? (startCounted ? "Drink water" : ""),
            // No symbol until one is chosen. Every input is optional.
            symbol: habit?.symbolName ?? (startCounted ? "drop" : ""),
            targetText: habit.flatMap { $0.kind == .counted ? rule?.target?.formatted() : nil } ?? (startCounted ? "8" : ""),
            unit: habit?.unit ?? (startCounted ? "glasses" : ""),
            tapText: habit.map { $0.tapAmount?.formatted() ?? "" } ?? "1",
            kind: habit?.kind ?? (startCounted ? .counted : .binary),
            schedule: LaunchOptions.current.screen == .editWaits ? [] : (rule?.schedule ?? .all)
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
          ScrollViewReader { reader in
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
                    daysSection.id("days")
                    if let habit {
                        pauseSection(habit)
                        archiveSection(habit)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                // The editDays screenshot opens the form at Repeats on.
                if [.editDays, .editWaits].contains(LaunchOptions.current.screen) { reader.scrollTo("days", anchor: .top) }
            }
          }
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
            #if os(iOS)
            // The number pad has no return key, so Done above the keyboard puts it away.
            .toolbar {
                // Only the number pad lacks a return key, so Done shows for Target alone.
                ToolbarItemGroup(placement: .keyboard) {
                    if targetFocused {
                        Spacer()
                        Button("Done") { targetFocused = false }
                    }
                }
            }
            #endif
            .onChange(of: targetText) {
                // The default log amount follows the target until the user types one.
                if !tapEdited { tapText = CountText.defaultTapAmount(forTarget: target)?.formatted() ?? "" }
            }
            .task {
                guard !isEdit, LaunchOptions.current.screen != .symbolsNew else { return }
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
            // A prompt is cut to one line, so the example is drawn under the empty field, where it wraps.
            // Both sit in one stack, so the field is as tall as the example.
            ZStack(alignment: .topLeading) {
                if name.isEmpty {
                    Text("For example, stretch after brushing teeth")
                        .font(style.display(.body))
                        .foregroundStyle(style.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityHidden(true)
                }
                TextField(String(localized: "Name"), text: $name, prompt: Text(verbatim: ""), axis: .vertical)
                    // At accessibility sizes four lines hold three words, so a long name gets room to show.
                    .lineLimit(typeSize.isAccessibilitySize ? 1...12 : 1...4)
                    .textFieldStyle(.plain)
                    .font(style.display(.body))
                    .focused($nameFocused)
                    .submitLabel(.done)
                    // The same length import accepts, so a habit made here always exports and imports.
                    .onChange(of: name) { _, value in
                        // The field wraps but a name is one line: Return finishes it, as the Done key says.
                        if value.contains(where: \.isNewline) {
                            name = value.filter { !$0.isNewline }
                            nameFocused = false
                            return
                        }
                        if value.count > ImportLimits.maxTextLength { name = String(value.prefix(ImportLimits.maxTextLength)) }
                    }
                    .accessibilityHint(Text("For example, stretch after brushing teeth"))
                    .accessibilityIdentifier("habit-name")
            }
            .frame(minHeight: 44, alignment: .leading)
            FieldRule()
            if let nameProblem, !isEdit || hasChanges { hint(nameProblem) }
        }
    }

    private var symbolSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            FieldLabel("Symbol")
            SymbolRow(selection: $symbol, willChoose: { nameFocused = false })
        }
    }

    private var loggingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel("Logging")
            if kindLocked {
                Text(kind == .counted ? "Count" : "Mark done").font(style.label(.body))
                hint(kind == .counted
                     ? String(localized: "This stays as it is once a habit has logs. To mark it done instead, add a new habit.", comment: "Edit habit, under Logging. \"This\" is how the habit logs: counted. It cannot change once there are logs")
                     : String(localized: "This stays as it is once a habit has logs. To count instead, add a new habit.", comment: "Edit habit, under Logging. \"This\" is how the habit logs: marked done. It cannot change once there are logs"))
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
            // At accessibility sizes the label sits above the field, so neither is split.
            let targetLayout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout())
            targetLayout {
                Text("Target").font(style.label(.body))
                if !typeSize.isAccessibilitySize { Spacer(minLength: 12) }
                TextField(String(localized: "Target"), text: $targetText, prompt: Text("Optional", comment: "Placeholder in an empty Target field. Says the field may stay empty, not that a value is set.").foregroundStyle(style.tertiary))
                    .textFieldStyle(.plain)
                    .font(style.label(.body).monospacedDigit())
                    .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
                    .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : 90)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .focused($targetFocused)
                    .padding(.bottom, 4)
                    .overlay(alignment: .bottom) { FieldRule() }
            }
            .frame(minHeight: 48)
            // The whole row focuses the field, the word "Target" included.
            .contentShape(Rectangle())
            .onTapGesture { targetFocused = true }
            hint(targetProblem ?? (targetText.trimmingCharacters(in: .whitespaces).isEmpty
                ? String(localized: "With no target, any amount counts as done.")
                : String(localized: "A day is done when its total reaches the target.", comment: "New and Edit habit, under a typed target")))
            FieldRule().padding(.top, 8)
            #if os(macOS)
            // A Mac sheet has no back button, so Unit and the log amount sit in the form itself.
            unitFields.padding(.top, 12)
            #else
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
            #endif
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
            // Said once the days or the target change, not before.
            if let habit, schedule != original.schedule || targetText != original.targetText {
                hint(habit.noSetDaysWaitsForTomorrow(schedule, today: settings.clock.today)
                     ? String(localized: "Today is logged, so this applies from tomorrow.", comment: "Edit habit, under the days, when no set days is chosen on a day already logged. The change starts the next day.")
                     : String(localized: "A change applies from today. Earlier days keep what they had."))
            }
        }
    }

    /// Pause acts at once, as Archive does, and needs no Save. Its own section, away from Archive, so a slip
    /// between the two does not happen.
    private func pauseSection(_ habit: Habit) -> some View {
        let clock = settings.clock
        let status = habit.ownPauseStatus(today: clock.today)
        return VStack(alignment: .leading, spacing: 8) {
            FieldRule()
            FieldLabel("Pause")
            switch status {
            case .none:
                pauseButton("Pause this habit") { model.pause(habit, context: context, clock: clock) }
                hint(String(localized: "It stays paused until you resume it. Paused days leave your runs as they are. You can still log."))
            case .paused(let since, let startedToday):
                if !startedToday {
                    LabeledContent {
                        Text(PauseText.short(since, clock: clock)).foregroundStyle(style.secondary)
                    } label: {
                        Text("Paused since")
                    }
                    .font(style.label(.body))
                    .frame(minHeight: 44)
                }
                pauseButton(startedToday ? "Undo pause" : "Resume tomorrow") { model.resume(habit, context: context, clock: clock) }
                hint(startedToday
                     ? String(localized: "Paused from today. Undo pause takes it away, and today draws as it was.")
                     : String(localized: "It starts again tomorrow. You can still log today."))
            case .resumesTomorrow:
                pauseButton("Keep paused") { model.pause(habit, context: context, clock: clock) }
                hint(String(localized: "Resumes tomorrow. Today stays paused. You can still log."))
            }
        }
        .padding(.top, 16)
    }

    private func pauseButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .font(style.label(.body, weight: .semibold))
            .frame(minHeight: 44)
            .accessibilityIdentifier("habit-pause")
    }

    private func archiveSection(_ habit: Habit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            FieldRule()
            Button {
                // With unsaved changes, Archive asks what to do with them, as Cancel does.
                if hasChanges { confirmArchive = true } else { archive(habit) }
            } label: {
                Text("Archive habit")
                    .underline()
                    .font(style.label(.body))
                    .foregroundStyle(style.text)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .confirmationDialog(
                canSave ? String(localized: "Archive with your changes?") : String(localized: "Archive without your changes?", comment: "Edit habit, Archive with unsaved changes that cannot be saved, such as an empty name"),
                isPresented: $confirmArchive,
                titleVisibility: .visible
            ) {
                if canSave {
                    Button("Save changes and archive") { applyChanges(); archive(habit) }
                }
                Button("Archive without changes", role: .destructive) { archive(habit) }
                Button("Keep editing", role: .cancel) {}
            }
            hint(String(localized: "You can bring it back at any time. Its history is kept."))
        }
        // Set apart from the day shortcuts above, which look alike, so a slip does not reach it.
        .padding(.top, 16)
    }

    private func archive(_ habit: Habit) {
        dismiss()
        model.archive(habit, context: context, clock: settings.clock)
    }

    /// Unit and log amount, one step in from the form on iPhone and iPad.
    private var unitPage: some View {
        ScrollView {
            unitFields
                .padding(24)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(style.text, style.secondary, style.tertiary)
        .paperBackground(style)
        .navigationTitle("Unit and log amount")
        #if os(iOS)
        // A pushed page does not show the form's keyboard Done, so it has its own.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if tapFocused {
                    Spacer()
                    Button("Done") { tapFocused = false }
                }
            }
        }
        #endif
    }

    private var unitFields: some View {
        VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel("Unit")
                    TextField(String(localized: "Unit"), text: $unit, prompt: Text("Optional", comment: "Placeholder in an empty Unit field. Says the field may stay empty, not that a value is set.").foregroundStyle(style.tertiary))
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
                    .font(style.label(.body).monospacedDigit())
                    .frame(minHeight: 44)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .focused($tapFocused)
                    FieldRule()
                    hint(tapProblem ?? (tapText.isEmpty
                        ? String(localized: "Leave it empty to type an amount each time.")
                        : String(localized: "Each log on Today adds this much.")))
                }
        }
    }

    /// One string per case, so translators see the whole phrase.
    private var unitSummary: String {
        let unitText = unit.trimmingCharacters(in: .whitespaces)
        switch (unitText.isEmpty, tapAmount) {
        case (false, let n?):
            return String(localized: "\(unitText), adds \(n)", comment: "Unit and log amount row: the unit as typed, and how much one log adds")
        case (false, nil):
            return String(localized: "\(unitText), typed each time", comment: "Unit and log amount row: the unit as typed; the amount is typed at each log")
        case (true, let n?):
            return String(localized: "No unit, adds \(n)", comment: "Unit and log amount row: no unit, and how much one log adds")
        case (true, nil):
            return String(localized: "No unit, typed each time", comment: "Unit and log amount row: no unit; the amount is typed at each log")
        }
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
        applyChanges()
        dismiss()
    }

    private func applyChanges() {
        let clock = settings.clock
        let resolvedTap: Int? = kind == .binary ? 1 : tapAmount
        let resolvedTarget: Int? = kind == .binary ? 1 : target
        if let habit {
            habit.name = draft.trimmedName
            habit.symbolName = symbol
            if !kindLocked { habit.kind = kind }
            habit.unit = unit.trimmingCharacters(in: .whitespaces)
            habit.tapAmount = resolvedTap
            habit.applyEdit(target: resolvedTarget, schedule: schedule, today: clock.today)
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
    Color.clear.sheet(isPresented: .constant(true)) { HabitFormView(habit: nil, today: Fixtures.previewClock.today) }
        .previewEnvironment()
}
