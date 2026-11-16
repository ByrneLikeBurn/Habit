import SwiftUI
import SwiftData
import HabitKit

/// Habit detail: week, month and year around one anchor day, then the stats.
struct HabitDetailView: View {
    let route: DetailRoute
    /// The tab this was opened from, so Back and the day sheet stay in place.
    let tab: AppTab

    @Query private var habits: [Habit]

    init(route: DetailRoute, tab: AppTab) {
        self.route = route
        self.tab = tab
        let id = route.habitID
        _habits = Query(filter: #Predicate<Habit> { $0.id == id })
    }

    var body: some View {
        if let habit = habits.first, habit.deletedAt == nil {
            HabitDetailPage(habit: habit, route: route, tab: tab)
        } else {
            EmptyLine(title: String(localized: "This habit is not here any more"), detail: "")
                .padding()
        }
    }
}

private struct HabitDetailPage: View {
    let habit: Habit
    let tab: AppTab

    @Environment(Settings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.style) private var style
    @Environment(\.sharedPauses) private var sharedPauses
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var kind: PeriodKind
    @State private var anchor: DayKey

    init(habit: Habit, route: DetailRoute, tab: AppTab) {
        self.habit = habit
        self.tab = tab
        _kind = State(initialValue: route.kind)
        _anchor = State(initialValue: route.anchor)
    }

    var body: some View {
        let clock = settings.clock
        let today = clock.today
        let totals = habit.dayTotals()
        let stats = habit.stats(today: today, sharedPauses: sharedPauses)
        let words = DayWords(clock: clock)
        let hasLogs = totals.values.contains { $0 > 0 }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.name)
                        .font(style.display(.largeTitle, weight: .semibold))
                        .foregroundStyle(style.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(ruleSentence(clock: clock))
                        .font(style.label(.subheadline))
                        .foregroundStyle(style.secondary)
                }

                if hasLogs {
                    periodPicker
                    PeriodHeader(
                        title: words.title(kind, anchor: anchor),
                        isCurrent: Periods.same(anchor, today, kind: kind, firstWeekday: clock.calendar.firstWeekday),
                        canGoBack: kind == .year
                            ? anchor.year > Periods.yearViewStart(since: stats.since).year
                            : Periods.move(anchor, by: -1, kind: kind) >= Periods.earliest || anchor > Periods.earliest.adding(days: 6),
                        canGoForward: !Periods.same(anchor, today, kind: kind, firstWeekday: clock.calendar.firstWeekday) && anchor < today,
                        move: { anchor = Periods.move(anchor, by: $0, kind: kind) },
                        goToCurrent: { anchor = today }
                    )
                    switch kind {
                    case .week:
                        WeekGrid(habit: habit, anchor: anchor, today: today, totals: totals, tab: tab)
                    case .month:
                        MonthGrid(habit: habit, anchor: anchor, today: today, totals: totals) { week in
                            kind = .week
                            anchor = week
                        }
                    case .year:
                        YearGrid(habit: habit, year: anchor.year, since: stats.since, today: today, totals: totals) { month in
                            kind = .month
                            anchor = month
                        }
                    }
                    if kind == .year {
                        Text(Verb.tapMonth).font(style.label(.footnote)).foregroundStyle(style.secondary)
                        SmallMarkKey()
                    } else {
                        Text(Verb.tapPastDay).font(style.label(.footnote)).foregroundStyle(style.secondary)
                    }
                    if kind == .week {
                        WeekTotalLine(habit: habit, days: Periods.week(of: anchor, firstWeekday: clock.calendar.firstWeekday), totals: totals)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nothing logged so far")
                            .font(style.display(.title3))
                            .foregroundStyle(style.secondary)
                        Text("Days you log will show here. You can also add a past day.")
                            .font(style.label(.subheadline))
                            .foregroundStyle(style.secondary)
                    }
                }

                Button {
                    model.pickingPastDay = habit
                } label: {
                    Text("Add a past day")
                        .font(style.label(.subheadline, weight: .semibold))
                        .foregroundStyle(hasLogs ? style.text : style.paper)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background {
                            if hasLogs { Capsule().strokeBorder(style.text, lineWidth: style.outlineWidth) } else { Capsule().fill(style.text) }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if hasLogs {
                    StatsBlock(habit: habit, stats: stats, words: words, showRuns: settings.showRuns)
                    NavigationLink {
                        MarksBoardView()
                    } label: {
                        HStack {
                            Text("What the marks mean").font(style.label(.body)).foregroundStyle(style.text)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(style.secondary).accessibilityHidden(true)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: 393, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .paperBackground(style)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { model.editing = habit }
            }
        }
    }

    private var periodPicker: some View {
        PeriodPicker(kind: $kind, kinds: PeriodKind.allCases)
    }

    /// "8 glasses a day. Every day except Thursday."
    private func ruleSentence(clock: HabitClock) -> String {
        let schedule = WeekdayText.sentence(for: habit.schedule, calendar: clock.calendar)
        guard habit.kind == .counted, let target = habit.target else { return schedule + "." }
        let amount = CountText.line(total: target, target: nil, unit: habit.unit)
        return String(localized: "\(amount) a day. \(schedule).")
    }
}

extension PeriodKind {
    var name: LocalizedStringResource {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }
}

/// Seven days across, with the date beside the weekday, so the only number under a mark is the count.
private struct WeekGrid: View {
    let habit: Habit
    let anchor: DayKey
    let today: DayKey
    let totals: [Int: Int]
    let tab: AppTab

    @Environment(Settings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.style) private var style
    @Environment(\.sharedPauses) private var sharedPauses
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let clock = settings.clock
        let words = DayWords(clock: clock)
        let days = Periods.week(of: anchor, firstWeekday: clock.calendar.firstWeekday)
        let states = habit.states(for: days, today: today, totals: totals, sharedPauses: sharedPauses, showDaysNotLogged: settings.showDaysNotLogged)
        if typeSize.isAccessibilitySize {
            // A list of all seven days: mark, date and the day's count in words.
            VStack(alignment: .leading, spacing: 0) {
                ForEach(days.indices, id: \.self) { i in
                    dayButton(days[i], state: states[i], words: words) {
                        HStack(spacing: 12) {
                            MarkView(state: states[i], isToday: days[i] == today, size: 36).frame(width: 52)
                            VStack(alignment: .leading) {
                                Text(words.long(days[i])).foregroundStyle(days[i] > today ? style.tertiary : style.text)
                                if let count = countWords(days[i]) { Text(count).foregroundStyle(style.secondary) }
                            }
                            .font(style.label(.body))
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        } else {
            HStack(spacing: 0) {
                ForEach(days.indices, id: \.self) { i in
                    dayButton(days[i], state: states[i], words: words) {
                        VStack(spacing: 6) {
                            Text(words.short(days[i]))
                                .font(style.label(.caption2))
                                .foregroundStyle(days[i] > today ? style.tertiary : style.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            MarkView(state: states[i], isToday: days[i] == today, size: 28)
                            Text(countNumber(days[i]) ?? " ")
                                .font(style.count(.caption))
                                .foregroundStyle(style.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 72)
                    }
                }
            }
        }
    }

    private func countNumber(_ day: DayKey) -> String? {
        guard habit.kind == .counted, let total = totals[day.rawValue], total > 0 else { return nil }
        return total.formatted()
    }

    private func countWords(_ day: DayKey) -> String? {
        guard habit.kind == .counted, let total = totals[day.rawValue], total > 0 else { return nil }
        return CountText.line(total: total, target: habit.rule(on: day).target, unit: habit.unit)
    }

    @ViewBuilder
    private func dayButton(_ day: DayKey, state: DayState, words: DayWords, @ViewBuilder label: () -> some View) -> some View {
        let spoken = [words.long(day), DayWords.state(state), countWords(day)].compactMap { $0 }.joined(separator: ". ")
        // A future day is not a button, unless it already holds a log (after travel or a new day-start hour).
        if day > today && (totals[day.rawValue] ?? 0) <= 0 {
            label()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(spoken))
        } else {
            Button {
                model.daySheet = DayRequest(habit: habit, day: day)
            } label: {
                label().contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(spoken))
            .accessibilityHint(Text("Opens this day"))
            .accessibilityAddTraits(.isButton)
        }
    }
}

/// One line for the week's total, only when the week has a log. A week with no log shows no zeros.
private struct WeekTotalLine: View {
    let habit: Habit
    let days: [DayKey]
    let totals: [Int: Int]
    @Environment(\.style) private var style

    var body: some View {
        let values = days.map { max(0, totals[$0.rawValue] ?? 0) }
        let logged = values.filter { $0 > 0 }.count
        if logged > 0 {
            let value = habit.kind == .counted
                ? CountText.line(total: values.reduce(0, +), target: nil, unit: habit.unit)
                : (logged == 1 ? String(localized: "1 day logged") : String(localized: "\(logged) days logged"))
            StatRow(label: String(localized: "This week"), value: value)
        }
    }
}

/// The month: weekday letters, then rows of weeks. A future day shows its date alone.
private struct MonthGrid: View {
    let habit: Habit
    let anchor: DayKey
    let today: DayKey
    let totals: [Int: Int]
    let openWeek: (DayKey) -> Void

    @Environment(Settings.self) private var settings
    @Environment(AppModel.self) private var model
    @Environment(\.style) private var style
    @Environment(\.sharedPauses) private var sharedPauses
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let clock = settings.clock
        let words = DayWords(clock: clock)
        let grid = Periods.monthGrid(of: anchor, firstWeekday: clock.calendar.firstWeekday)
        let state: (DayKey) -> DayState = {
            habit.state(on: $0, today: today, total: totals[$0.rawValue] ?? 0, sharedPauses: sharedPauses, showDaysNotLogged: settings.showDaysNotLogged)
        }
        if typeSize.isAccessibilitySize {
            // A list of weeks, each with its counts in words. A week opens in the week view.
            VStack(alignment: .leading, spacing: 0) {
                ForEach(grid.indices, id: \.self) { row in
                    let days = grid[row].compactMap { $0 }
                    Button { if let first = days.first { openWeek(first) } } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(words.week(days)).foregroundStyle(style.text)
                            Text(summary(days.map(state))).foregroundStyle(style.secondary)
                        }
                        .font(style.label(.body))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Opens the week"))
                }
            }
        } else {
            VStack(spacing: 2) {
                HStack(spacing: 0) {
                    ForEach(WeekdayText.labels(calendar: clock.calendar)) { label in
                        Text(label.short)
                            .font(style.label(.caption2))
                            .foregroundStyle(style.secondary)
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                    }
                }
                ForEach(grid.indices, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { column in
                            if let day = grid[row][column] {
                                cell(day, state: state(day), words: words)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 52).accessibilityHidden(true)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(_ day: DayKey, state: DayState, words: DayWords) -> some View {
        let content = VStack(spacing: 3) {
            MarkView(state: state, isToday: day == today, size: 24)
            Text(day.day.formatted())
                .font(style.label(.caption2).monospacedDigit())
                .foregroundStyle(day > today ? style.tertiary : style.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .contentShape(Rectangle())
        let spoken = [words.long(day), DayWords.state(state)].compactMap { $0 }.joined(separator: ". ")
        if day > today && (totals[day.rawValue] ?? 0) <= 0 {
            content.accessibilityElement(children: .ignore).accessibilityLabel(Text(spoken))
        } else {
            Button { model.daySheet = DayRequest(habit: habit, day: day) } label: { content }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(spoken))
                .accessibilityHint(Text("Opens this day"))
                .accessibilityAddTraits(.isButton)
        }
    }

    private func summary(_ states: [DayState]) -> String {
        MonthWords.summary(states)
    }
}

/// Counts in words. Days without a log are never counted.
enum MonthWords {
    static func summary(_ states: [DayState]) -> String {
        let done = states.filter { $0 == .done }.count
        let part = states.filter { $0 == .partDone }.count
        let paused = states.filter { $0 == .paused }.count
        let credited = states.filter { $0 == .loggedWhilePaused || $0 == .loggedOffSchedule }.count
        var parts: [String] = []
        if done > 0 { parts.append(done == 1 ? String(localized: "1 day done") : String(localized: "\(done) days done")) }
        if part > 0 { parts.append(String(localized: "\(part) part done")) }
        if credited > 0 { parts.append(String(localized: "\(credited) logged on a paused day or a day off")) }
        if paused > 0 { parts.append(String(localized: "\(paused) paused")) }
        return parts.isEmpty ? String(localized: "Nothing logged") : parts.formatted(.list(type: .and))
    }
}

/// The year: one button per month, each its label and its block of weeks.
private struct YearGrid: View {
    let habit: Habit
    let year: Int
    let since: DayKey
    let today: DayKey
    let totals: [Int: Int]
    let openMonth: (DayKey) -> Void

    @Environment(Settings.self) private var settings
    @Environment(\.style) private var style
    @Environment(\.sharedPauses) private var sharedPauses
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let words = DayWords(clock: settings.clock)
        let months = Periods.yearMonths(year: year, since: since, today: today)
        let state: (DayKey) -> DayState = { day in
            habit.state(on: day, today: today, total: totals[day.rawValue] ?? 0, sharedPauses: sharedPauses, showDaysNotLogged: settings.showDaysNotLogged)
        }
        if months.isEmpty {
            Text("Nothing logged this year").font(style.label(.subheadline)).foregroundStyle(style.secondary)
        } else if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(months, id: \.self) { month in
                    let states = Periods.monthDays(of: month).map(state)
                    Button { openMonth(month) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(words.month(month)).foregroundStyle(style.text)
                            Text(MonthWords.summary(states)).foregroundStyle(style.secondary)
                        }
                        .font(style.label(.body))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Opens the month"))
                }
            }
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 44), spacing: 12, alignment: .topLeading), count: 4), alignment: .leading, spacing: 12) {
                ForEach(months, id: \.self) { month in
                    let weeks = Periods.yearWeeks(of: month)
                    let states = weeks.map { $0.map(state) }
                    Button { openMonth(month) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(words.monthShort(month))
                                .font(style.label(.caption2))
                                .foregroundStyle(style.secondary)
                            Canvas { context, size in
                                let cell = min(size.width / 7, 9)
                                for (r, week) in weeks.enumerated() {
                                    for (c, day) in week.enumerated() {
                                        let rect = CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell, width: cell, height: cell).insetBy(dx: 0.75, dy: 0.75)
                                        SmallMark.draw(states[r][c], isToday: day == today, in: rect, context: &context, style: style)
                                    }
                                }
                            }
                            .frame(height: CGFloat(max(weeks.count, 4)) * 9)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    // Spoken for the calendar month, so it matches the month view it opens.
                    .accessibilityLabel(Text("\(words.month(month)). \(MonthWords.summary(Periods.monthDays(of: month).map(state)))"))
                    .accessibilityHint(Text("Opens the month"))
                    .accessibilityAddTraits(.isButton)
                }
            }
            .accessibilityChartDescriptor(YearChart(habit: habit, months: months, words: words, state: state))
        }
    }
}

/// The year grid as an audio graph: days done per month.
private struct YearChart: AXChartDescriptorRepresentable {
    let habit: Habit
    let months: [DayKey]
    let words: DayWords
    let state: (DayKey) -> DayState

    func makeChartDescriptor() -> AXChartDescriptor {
        let names = months.map(words.monthShort)
        // The calendar month, as spoken and as the month view counts it.
        let values = months.map { month in Periods.monthDays(of: month).map(state).filter(\.isLogged).count }
        let points = zip(names, values).map { AXDataPoint(x: $0, y: Double($1)) }
        return AXChartDescriptor(
            title: habit.name,
            summary: nil,
            xAxis: AXCategoricalDataAxisDescriptor(title: String(localized: "Month"), categoryOrder: names),
            yAxis: AXNumericDataAxisDescriptor(title: String(localized: "Days logged"), range: 0...Double(max(values.max() ?? 1, 1)), gridlinePositions: []) { "\(Int($0))" },
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(name: String(localized: "Days logged"), isContinuous: false, dataPoints: points)]
        )
    }
}

/// Days logged, the unit total and days done, all time. Runs only when Show runs is on.
private struct StatsBlock: View {
    let habit: Habit
    let stats: HabitStats
    let words: DayWords
    let showRuns: Bool
    @Environment(\.style) private var style

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Since \(words.full(stats.since))")
                .font(style.label(.footnote))
                .foregroundStyle(style.secondary)
                .padding(.bottom, 4)
            StatRow(label: String(localized: "Days logged"), value: stats.daysLogged.formatted())
            if habit.kind == .counted {
                StatRow(label: unitLabel, value: stats.unitTotal.formatted())
                if habit.target != nil {
                    StatRow(label: String(localized: "Days done"), value: stats.daysDone.formatted())
                }
            }
            if showRuns {
                StatRow(label: String(localized: "Current run"), value: runText)
                if stats.longestRun > 0 {
                    StatRow(label: String(localized: "Longest run"), value: Self.days(stats.longestRun))
                }
            }
        }
    }

    static func days(_ n: Int) -> String {
        n == 1 ? String(localized: "1 day") : String(localized: "\(n) days")
    }

    /// The unit as typed, with a capital first letter, or "Total" with no unit.
    private var unitLabel: String {
        let unit = habit.unit.trimmingCharacters(in: .whitespaces)
        guard let first = unit.first else { return String(localized: "Total") }
        return first.uppercased() + unit.dropFirst()
    }

    private var runText: String {
        switch stats.run {
        case .days(let n): Self.days(n)
        case .betweenRuns: String(localized: "Between runs", comment: "State label. No run is active after a gap. Restructure freely. Must not name a missed day or a zero.")
        case .noRunYet: String(localized: "No run yet")
        }
    }
}
