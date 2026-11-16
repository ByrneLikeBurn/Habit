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
                        VStack(alignment: .leading, spacing: 6) {
                            Text(kind == .week ? Verb.tapHabitOrDay : Verb.tapHabitMonth)
                            if kind == .week {
                                Text("A dot is a day the habit is not scheduled.")
                            } else {
                                SmallMarkKey()
                            }
                        }
                        .font(style.label(.footnote))
                        .foregroundStyle(style.secondary)
                        .padding(.top, 12)
                    } header: {
                        header(days: days, anchor: anchor, today: today, words: words)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: 393, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .paperBackground(style)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    private func header(days: [DayKey], anchor: DayKey, today: DayKey, words: DayWords) -> some View {
        let clock = settings.clock
        return VStack(alignment: .leading, spacing: 6) {
            Picker("View", selection: $kind) {
                Text("Week").tag(PeriodKind.week)
                Text("Month").tag(PeriodKind.month)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            PeriodHeader(
                title: words.title(kind, anchor: anchor),
                isCurrent: Periods.same(anchor, today, kind: kind, firstWeekday: clock.calendar.firstWeekday),
                canGoForward: !Periods.same(anchor, today, kind: kind, firstWeekday: clock.calendar.firstWeekday) && anchor < today,
                move: { self.anchor = Periods.move(anchor, by: $0, kind: kind) },
                goToCurrent: { self.anchor = today }
            )
            if kind == .week {
                HistoryWeekHeader(days: days, today: today)
            } else {
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

    var body: some View {
        let labels = Dictionary(uniqueKeysWithValues: WeekdayText.labels(calendar: settings.clock.calendar).map { ($0.weekday, $0.short) })
        HStack(spacing: 0) {
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

    var body: some View {
        let totals = habit.dayTotals()
        let states = habit.states(for: days, today: today, totals: totals, sharedPauses: sharedPauses, showDaysNotLogged: settings.showDaysNotLogged)
        let words = DayWords(clock: settings.clock)

        VStack(alignment: .leading, spacing: 2) {
            Button {
                model.openDetail(habit, kind: .week, anchor: days.last.map { min($0, today) } ?? today, from: .history)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: habit.symbolName).font(style.label(.footnote)).accessibilityHidden(true)
                    Text(habit.name).font(style.display(.body)).multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(style.text)
                .frame(minHeight: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            HStack(spacing: 0) {
                ForEach(days.indices, id: \.self) { i in
                    let day = days[i]
                    let mark = MarkView(state: day > today ? .blank : states[i], size: 22)
                        .overlay {
                            if day == today && !archived {
                                Rectangle().strokeBorder(style.text, lineWidth: style.ruleWidth * 2).frame(width: 28, height: 28)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    if day > today || archived {
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
                ForEach(days.filter { $0 <= today }, id: \.self) { day in
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
        let states = days.map { $0 > today ? DayState.blank : habit.state(on: $0, today: today, total: totals[$0.rawValue] ?? 0, sharedPauses: sharedPauses, showDaysNotLogged: settings.showDaysNotLogged) }
        let words = DayWords(clock: settings.clock)
        let sentence = MonthWords.summary(states)

        Button {
            model.openDetail(habit, kind: .month, anchor: min(days.last ?? today, today), from: .history)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: habit.symbolName).font(style.label(.footnote)).accessibilityHidden(true)
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
