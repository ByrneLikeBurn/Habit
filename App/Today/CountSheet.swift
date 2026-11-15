import SwiftUI
import SwiftData
import HabitKit

/// The total, an amount field that starts at the tap amount, and Take away and Add.
/// Each button applies the change and closes the sheet. Cancel closes it with no change.
struct CountSheet: View {
    let habit: Habit
    let day: DayKey

    @Environment(Settings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.style) private var style
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager
    @State private var amountText: String
    @State private var selection: TextSelection?
    @FocusState private var amountFocused: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    init(habit: Habit, day: DayKey) {
        self.habit = habit
        self.day = day
        _amountText = State(initialValue: habit.tapAmount.map { $0.formatted() } ?? "")
    }

    private var amount: Int? {
        CountText.parse(amountText).flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        let clock = settings.clock
        let total = habit.total(on: day)
        let target = habit.rule(on: day).target
        let dayName: String? = day == clock.today ? nil : clock.date(for: day).formatted(.dateTime.weekday(.wide).day().month(.wide))

        NavigationStack {
            ScrollView {
                VStack(spacing: 6) {
                    Text(total.formatted())
                        .font(style.count(.largeTitle))
                        .foregroundStyle(style.text)
                        .contentTransition(.numericText())
                    Text(CountText.sheetCaption(target: target, unit: habit.unit, dayName: dayName))
                        .font(style.label(.subheadline))
                        .foregroundStyle(style.secondary)
                        .multilineTextAlignment(.center)

                    Text("Amount to add or take away")
                        .font(style.label(.footnote))
                        .foregroundStyle(style.secondary)
                        .padding(.top, 16)
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
                    if amount == nil {
                        Text("Type a whole number above 0.")
                            .font(style.label(.footnote))
                            .foregroundStyle(style.secondary)
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) { buttons(total: total, clock: clock) }
                        VStack(spacing: 12) { buttons(total: total, clock: clock) }
                    }
                    .padding(.top, 16)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .paperBackground(style)
            .navigationTitle(habit.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        // At accessibility sizes the sheet opens full height and the keyboard waits for a tap,
        // so the total is never hidden.
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .task {
            // The amount starts selected, so typing replaces it and Add works at once.
            guard !typeSize.isAccessibilitySize else { return }
            try? await Task.sleep(for: .milliseconds(350))
            amountFocused = true
        }
        .onChange(of: amountFocused) { _, focused in
            guard focused else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(50))
                selection = TextSelection(range: amountText.startIndex..<amountText.endIndex)
            }
        }
    }

    @ViewBuilder
    private func buttons(total: Int, clock: HabitClock) -> some View {
        Button {
            apply(.takeAway(amount ?? 0), clock: clock)
        } label: {
            Text("Take away")
                .foregroundStyle(style.text)
                .frame(minWidth: 96, minHeight: 32)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .overlay(Capsule().strokeBorder(style.text, lineWidth: style.outlineWidth))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(amount == nil || total == 0)

        Button {
            apply(.add(amount ?? 0), clock: clock)
        } label: {
            Text("Add").frame(minWidth: 96, minHeight: 32)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .foregroundStyle(style.paper)
        .disabled(amount == nil)
    }

    private func apply(_ action: LogAction, clock: HabitClock) {
        model.log(action, habit: habit, day: day, context: context, clock: clock, undoManager: undoManager)
        dismiss()
    }
}

#Preview("Count sheet") {
    let container = Fixtures.previewContainer()
    let habit = try! container.mainContext.fetch(FetchDescriptor<Habit>()).first { $0.kind == .counted }!
    return Color.clear
        .sheet(isPresented: .constant(true)) {
            CountSheet(habit: habit, day: Fixtures.previewClock.today)
        }
        .modelContainer(container)
        .previewEnvironment()
}
