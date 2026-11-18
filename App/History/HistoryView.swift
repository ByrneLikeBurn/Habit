import SwiftUI
import SwiftData
import HabitKit

/// The History tab: every habit across a week or a month. Week opens on the current week.
/// It is not a place to log today, so a tap on a name opens Habit detail.
struct HistoryView: View {
    @Environment(Settings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.style) private var style
    @Query private var habits: [Habit]
    @State private var kind: PeriodKind = LaunchOptions.current.screen == .historyMonth ? .month : .week
    @State private var anchor: DayKey?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let clock = settings.clock
        let today = clock.today
        let anchor = anchor ?? today
        let words = DayWords(clock: clock)
        let active = Ordering.sorted(habits)
        let days = kind == .week ? Periods.week(of: anchor, firstWeekday: clock.calendar.firstWeekday) : Periods.monthDays(of: anchor)
        let range = (days.first?.rawValue ?? 0)...(days.last?.rawValue ?? 0)
        // An archived habit shows only in a period where it has a log.
        let archived = habits
            .filter { $0.isArchived && $0.deletedAt == nil && ($0.events ?? []).contains { range.contains($0.dayKey) && $0.delta != 0 } }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Text("History")
                    .font(style.display(.largeTitle, weight: .semibold))
                    .foregroundStyle(style.text)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, 8)

                if active.isEmpty && archived.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        EmptyLine(title: String(localized: "No habits yet"), detail: String(localized: "Add a habit and its days will show here."))
                        Button("Add a habit") { model.showNewHabit = true }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .foregroundStyle(style.paper)
                            .controlSize(.large)
                    }
                } else {
                    Section {
                        // How to use the rows, above them, so it is seen before the list runs under the tab bar.
                        Text(kind == .week ? Verb.tapHabitOrDay : Verb.tapHabitMonth)
                            .font(style.label(.footnote))
                            .foregroundStyle(style.secondary)
                            .padding(.top, 4)
                        if kind == .week {
                            NavigationLink {
                                MarksBoardView()
                            } label: {
                                Text("What the marks mean")
                                    .font(style.label(.footnote, weight: .semibold))
                                    .underline()
                                    .foregroundStyle(style.text)
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        if kind == .month && !typeSize.isAccessibilitySize {
                            SmallMarkKey().padding(.vertical, 6)
                        }
                        ForEach(active) { habit in
                            row(habit, days: days, today: today, archived: false)
                        }
                        if !archived.isEmpty {
                            Text("Archived")
                                .font(style.label(.footnote, weight: .semibold))
                                .textCase(.uppercase)
                                .foregroundStyle(style.secondary)
                                .padding(.top, 16)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(archived) { habit in
                                row(habit, days: days, today: today, archived: true)
                            }
                        }

                    } header: {
                        header(days: days, anchor: anchor, today: today, words: words)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: WideLayout.contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .paperBackground(style)
        .navigationTitle("History")
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    private func header(days: [DayKey], anchor: DayKey, today: DayKey, words: DayWords) -> some View {
        let clock = settings.clock
        return VStack(alignment: .leading, spacing: 6) {
            PeriodPicker(kind: $kind, kinds: [.week, .month])
            PeriodHeader(
                title: words.title(kind, anchor: anchor),
                isCurrent: Periods.same(anchor, today, kind: kind, firstWeekday: clock.calendar.firstWeekday),
                canGoForward: !Periods.same(anchor, today, kind: kind, firstWeekday: clock.calendar.firstWeekday) && anchor < today,
                move: { self.anchor = Periods.move(anchor, by: $0, kind: kind) },
                goToCurrent: { self.anchor = today }
            )
            if kind == .week {
                HistoryWeekHeader(days: days, today: today)
            } else if !typeSize.isAccessibilitySize {
                // At accessibility sizes the rows are sentences, so there is no strip to date.
                HistoryMonthHeader(days: days, words: words)
            }
        }
        .padding(.vertical, 6)
        .background(style.paper)
    }

    @ViewBuilder
    private func row(_ habit: Habit, days: [DayKey], today: DayKey, archived: Bool) -> some View {
        if kind == .week {
            HistoryWeekRow(habit: habit, days: days, today: today, archived: archived)
        } else {
            HistoryMonthRow(habit: habit, days: days, today: today, archived: archived)
        }
    }
}

private struct HistoryWeekHeader: View {
    let days: [DayKey]
    let today: DayKey
    @Environment(Settings.self) private var settings
    @Environment(\.style) private var style
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isWide: Bool { sizeClass == .regular }
    #else
    private let isWide = true
    #endif

    var body: some View {
        let labels = Dictionary(uniqueKeysWithValues: WeekdayText.labels(calendar: settings.clock.calendar).map { ($0.weekday, $0.short) })
        HStack(spacing: 0) {
            if isWide { Spacer(minLength: 0) }
            ForEach(days, id: \.self) { day in
                // Today is marked once in the header and by a thin outline in the cell.
                Text(labels[day.weekday] ?? "")
                    .font(style.label(.caption, weight: day == today ? .bold : .regular))
                    .underline(day == today)
                    .foregroundStyle(day > today ? style.tertiary : style.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: 44)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityHidden(true)
    }
}

private struct HistoryMonthHeader: View {
    let days: [DayKey]
    let words: DayWords
    @Environment(\.style) private var style

    var body: some View {
        // The date above each Monday, placed where that Monday sits in the strip.
        GeometryReader { geometry in
            let layout = StripLayout(days: days, width: geometry.size.width)
            ForEach(days.filter { $0.weekday == 2 }, id: \.self) { monday in
                Text(monday.day.formatted())
                    .font(style.label(.caption2).monospacedDigit())
                    .foregroundStyle(style.secondary)
                    .fixedSize()
                    .position(x: layout.cell(for: monday).midX, y: 8)
            }
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }
}

/// Where each day of a month sits in a strip: equal cells with a little extra space before each Monday.
struct StripLayout {
    let days: [DayKey]
    let width: CGFloat

    private var gaps: Int { days.dropFirst().filter { $0.weekday == 2 }.count }
    private var gap: CGFloat { 3 }
    var cellWidth: CGFloat { max(1, (width - CGFloat(gaps) * gap) / CGFloat(max(days.count, 1))) }

    func cell(for day: DayKey) -> CGRect {
        guard let index = days.firstIndex(of: day) else { return .zero }
        let mondaysBefore = days[1..<max(1, index + 1)].filter { $0.weekday == 2 }.count
        let x = CGFloat(index) * cellWidth + CGFloat(mondaysBefore) * gap
        return CGRect(x: x, y: 0, width: cellWidth, height: cellWidth)
    }
}

/// One habit across a week: the name above seven 44 point cells.
/// For VoiceOver the row is one element: it opens Habit detail, with one action per day.
private struct HistoryWeekRow: View {
    let habit: Habit
    let days: [DayKey]
    let today: DayKey
    let archived: Bool

    @Environment(Settings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.style) private var style
    @Environment(\.sharedPauses) private var sharedPauses
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isWide: Bool { sizeClass == .regular }
    #else
    private let isWide = true
    #endif

    var body: some View {
        let totals = habit.dayTotals()
        let states = habit.states(for: days, today: today, totals: totals, sharedPauses: sharedPauses, showDaysNotLogged: settings.showDaysNotLogged)
        let words = DayWords(clock: settings.clock)

        let layout = isWide ? AnyLayout(HStackLayout(alignment: .center, spacing: 12)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
        layout {
            Button {
                model.openDetail(habit, kind: .week, anchor: days.last.map { min($0, today) } ?? today, from: .history)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    HabitSymbol(name: habit.symbolName)
                    Text(habit.name).font(style.display(.body)).multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(style.text)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            HStack(spacing: 0) {
                ForEach(days.indices, id: \.self) { i in
                    let day = days[i]
                    let mark = MarkView(state: states[i], size: 22)
                        .overlay {
                            if day == today && !archived {
                                Rectangle().strokeBorder(style.text, lineWidth: style.ruleWidth * 2).frame(width: 28, height: 28)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    // A future day is not a target, unless it already holds a log.
                    if (day > today && (totals[day.rawValue] ?? 0) <= 0) || archived {
                        mark
                    } else {
                        Button { model.daySheet = DayRequest(habit: habit, day: day) } label: { mark }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(style.rule).frame(height: style.ruleWidth) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(habit.name))
        .accessibilityValue(Text(summary(states: states, words: words)))
        .accessibilityHint(Text("Opens the habit"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            model.openDetail(habit, kind: .week, anchor: min(days.last ?? today, today), from: .history)
        }
        .accessibilityActions {
            if !archived {
                ForEach(days.filter { $0 <= today || (totals[$0.rawValue] ?? 0) > 0 }, id: \.self) { day in
                    Button(String(localized: "Open \(words.long(day))")) {
                        model.daySheet = DayRequest(habit: habit, day: day)
                    }
                }
            }
        }
    }

    private func summary(states: [DayState], words: DayWords) -> String {
        zip(days, states).filter { $0.0 <= today }.compactMap { day, state in
            DayWords.state(state).map { "\(words.long(day)): \($0)" }
        }.joined(separator: ". ")
    }
}

/// One habit across a month: the name above one strip of small shapes. The row is one button
/// that opens Habit detail on the same month. Days are not targets here.
private struct HistoryMonthRow: View {
    let habit: Habit
    let days: [DayKey]
    let today: DayKey
    let archived: Bool

    @Environment(Settings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.style) private var style
    @Environment(\.sharedPauses) private var sharedPauses
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let totals = habit.dayTotals()
        let states = days.map { habit.state(on: $0, today: today, total: totals[$0.rawValue] ?? 0, sharedPauses: sharedPauses, showDaysNotLogged: settings.showDaysNotLogged) }
        let words = DayWords(clock: settings.clock)
        let sentence = MonthWords.summary(states)

        Button {
            model.openDetail(habit, kind: .month, anchor: min(days.last ?? today, today), from: .history)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    HabitSymbol(name: habit.symbolName)
                    Text(habit.name).font(style.display(.body)).multilineTextAlignment(.leading)
                }
                .foregroundStyle(style.text)
                if typeSize.isAccessibilitySize {
                    Text(sentence).font(style.label(.body)).foregroundStyle(style.secondary)
                } else {
                    Canvas { context, size in
                        let layout = StripLayout(days: days, width: size.width)
                        for (day, state) in zip(days, states) {
                            let cell = layout.cell(for: day)
                            let rect = CGRect(x: cell.minX, y: (size.height - cell.width) / 2, width: cell.width, height: cell.width).insetBy(dx: 0.5, dy: 0.5)
                            SmallMark.draw(state, isToday: day == today && !archived, in: rect, context: &context, style: style)
                        }
                    }
                    .frame(height: 14)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) { Rectangle().fill(style.rule).frame(height: style.ruleWidth) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(habit.name). \(words.month(days.first ?? today)). \(sentence)"))
        .accessibilityHint(Text("Opens the month"))
        .accessibilityAddTraits(.isButton)
    }
}

/// A habit's symbol in a column of one width, so names share a left edge. It sits on the first line of a wrapped name.
private struct HabitSymbol: View {
    let name: String
    @Environment(\.style) private var style
    @ScaledMetric(relativeTo: .footnote) private var width: CGFloat = 18

    var body: some View {
        HabitSymbolImage(name: name)
            .font(style.label(.footnote))
            .frame(width: width)
            .accessibilityHidden(true)
    }
}

/// Content width for History and Habit detail: the phone column on a phone, about 720 points on iPad and Mac.
enum WideLayout {
    static let contentWidth: CGFloat = 720
}
