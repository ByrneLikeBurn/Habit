import SwiftUI
import HabitKit

/// A habit's symbol, or nothing for a habit with none. Keeps the text baseline either way.
struct HabitSymbolImage: View {
    let name: String

    var body: some View {
        if name.isEmpty {
            Text(verbatim: " ").accessibilityHidden(true)
        } else {
            Image(systemName: name).accessibilityHidden(true)
        }
    }
}

/// A section label above its field, as drawn in `sheet-new-habit.png`.
/// The one uppercase label, also used for the symbol picker's group headings.
struct FieldLabel: View {
    let text: Text
    @Environment(\.style) private var style

    init(_ title: LocalizedStringKey) { text = Text(title) }
    init(verbatim title: String) { text = Text(verbatim: title) }

    var body: some View {
        text
            .textCase(.uppercase)
            .tracking(style.capsTracking)
            .font(style.label(.caption, weight: .medium))
            .foregroundStyle(style.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A hairline under a field.
struct FieldRule: View {
    @Environment(\.style) private var style

    var body: some View {
        Rectangle().fill(style.rule).frame(height: style.ruleWidth).accessibilityHidden(true)
    }
}

// MARK: Days

/// Seven outlined day buttons in the order of the user's calendar.
/// A chosen day has a heavy outline and a small checkmark above its letters. A day not chosen has a
/// thin outline in secondary ink. The checkmark and the stroke carry the state, never a fill, so the
/// row stays lighter than Add. The checkmark is used on this form only.
struct DayButtons: View {
    @Binding var selection: Weekdays
    let calendar: Calendar
    @Environment(\.style) private var style
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Two letters and a checkmark fill a 44-point circle at the default size. From xxLarge the days
        // become a list of full names, each with a checkmark when chosen, as Logging does.
        if typeSize >= .xxLarge { list } else { circles }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(WeekdayText.labels(calendar: calendar)) { label in
                let on = selection.contains(weekday: label.weekday)
                Button {
                    selection.formSymmetricDifference(Weekdays(weekday: label.weekday))
                } label: {
                    HStack {
                        // One weight either way, so ticking a day never rewraps its name. The checkmark carries the state.
                        Text(label.full).font(style.label(.body))
                        Spacer(minLength: 8)
                        Image(systemName: "checkmark").opacity(on ? 1 : 0).accessibilityHidden(true)
                    }
                    .foregroundStyle(on ? style.text : style.secondary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(on ? Text("Selected") : Text("Not selected"))
                .accessibilityIdentifier("day-\(label.weekday)")
            }
        }
    }

    private var circles: some View {
        // No spacing: on a 375-point phone seven buttons get 46 points each, so each keeps its 44-point target.
        HStack(spacing: 0) {
            ForEach(WeekdayText.labels(calendar: calendar)) { label in
                let on = selection.contains(weekday: label.weekday)
                Button {
                    selection.formSymmetricDifference(Weekdays(weekday: label.weekday))
                } label: {
                    VStack(spacing: 0) {
                        Image(systemName: "checkmark")
                            .font(style.label(.caption2, weight: .bold))
                            .imageScale(.small)
                            .opacity(on ? 1 : 0)
                        Text(Self.twoLetters(label, calendar: calendar))
                            .font(style.label(.footnote, weight: on ? .semibold : .regular))
                            .lineLimit(1)
                    }
                    .foregroundStyle(on ? style.text : style.secondary)
                    // Every circle at one size, which fits; larger text gets the list.
                    .dynamicTypeSize(...DynamicTypeSize.large)
                    .frame(maxWidth: 44, minHeight: 44)
                    .aspectRatio(1, contentMode: .fit)
                    .background {
                        Circle().strokeBorder(on ? style.text : style.secondary, lineWidth: on ? style.chosenOutlineWidth : style.openOutlineWidth)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(label.full))
                .accessibilityValue(on ? Text("Selected") : Text("Not selected"))
                .accessibilityIdentifier("day-\(label.weekday)")
            }
        }
    }

    /// Two letters at equal width, for example "Mo" and "Tu", unless they repeat in this locale.
    static func twoLetters(_ label: WeekdayLabel, calendar: Calendar) -> String {
        WeekdayText.buttonTexts(calendar: calendar)[label.weekday - 1]
    }

    /// The locale's working days: every weekday that is not its weekend.
    static func weekdays(calendar: Calendar) -> Weekdays {
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9)) ?? .now
        var days = Weekdays()
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            if !calendar.isDateInWeekend(date) {
                days.formUnion(Weekdays(weekday: calendar.component(.weekday, from: date)))
            }
        }
        return days
    }
}

/// "Set every day" and "Set weekdays". A shortcut whose result already matches the row is drawn in
/// tertiary text with no underline, which keeps the text contrast floor.
struct DayShortcuts: View {
    @Binding var selection: Weekdays
    let calendar: Calendar
    @Environment(\.style) private var style

    var body: some View {
        let weekdays = DayButtons.weekdays(calendar: calendar)
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 24) { buttons(weekdays) }
            VStack(alignment: .leading, spacing: 0) { buttons(weekdays) }
        }
    }

    @ViewBuilder
    private func buttons(_ weekdays: Weekdays) -> some View {
        shortcut("Set every day", matches: selection == .all) { selection = .all }
        shortcut("Set weekdays", matches: selection == weekdays) { selection = weekdays }
        shortcut("Set no days", matches: selection.isEmpty) { selection = [] }
    }

    /// A shortcut that already matches stays in tertiary text, which keeps the floor. It is not disabled,
    /// because a disabled control dims a second time, below every floor. A tap on it changes nothing.
    private func shortcut(_ title: LocalizedStringKey, matches: Bool, action: @escaping () -> Void) -> some View {
        Button { if !matches { action() } } label: {
            Text(title)
                .underline(!matches)
                .font(style.label(.subheadline, weight: .medium))
                .foregroundStyle(matches ? style.tertiary : style.text)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(matches ? Text("Already set") : Text(verbatim: ""))
    }
}

// MARK: Symbols

/// The form's one row: None, five symbols and "More…". A symbol chosen from More takes the fifth slot.
struct SymbolRow: View {
    @Binding var selection: String
    /// Called before the picker opens, so the form can put its keyboard away.
    var willChoose: () -> Void = {}
    // The symbols screenshot opens the picker at once.
    @State private var choosing = [.symbols, .symbolsNew].contains(LaunchOptions.current.screen)
    @Environment(\.style) private var style

    private var shown: [String] {
        var names = SymbolCatalog.firstRow
        if !selection.isEmpty, !names.contains(selection) { names[names.count - 1] = selection }
        return names
    }

    var body: some View {
        // The row wraps whenever it does not fit: on a small phone, at large text, and at accessibility sizes.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) { cells }
            FlowLayout(spacing: 12, lineSpacing: 8) { cells }
        }
        .sheet(isPresented: $choosing) {
            SymbolPickerSheet(selection: $selection)
        }
    }

    @ViewBuilder
    private var cells: some View {
        chip(on: selection.isEmpty, label: Text("None")) { selection = "" } content: {
            Text("None").font(style.label(.subheadline)).lineLimit(1).fixedSize().padding(.horizontal, 10)
        }
        ForEach(shown, id: \.self) { name in
            let label = SymbolCatalog.symbol(named: name).map { Text(verbatim: $0.label) } ?? Text(verbatim: name)
            chip(on: selection == name, label: label) { selection = name } content: {
                Image(systemName: name).font(style.label(.body)).frame(minWidth: 28)
            }
        }
        Button { willChoose(); choosing = true } label: {
            Text("More…")
                .underline()
                .lineLimit(1)
                .fixedSize()
                .font(style.label(.subheadline))
                .foregroundStyle(style.text)
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("More symbols"))
    }

    private func chip<Content: View>(on: Bool, label: Text, action: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        Button(action: action) {
            content()
                .foregroundStyle(style.text)
                .frame(minWidth: 40, minHeight: 40)
                .overlay {
                    if on { RoundedRectangle(cornerRadius: 10).strokeBorder(style.text, lineWidth: style.outlineWidth) }
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Every symbol, searchable, with one row of group chips. One chip is on at a time, and All shows every
/// group under its heading. Typing searches every group and puts the chips back to All.
struct SymbolPickerSheet: View {
    @Binding var selection: String
    @State private var draft: String
    @State private var query = ""
    @State private var group: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.style) private var style
    @ScaledMetric(relativeTo: .body) private var cell: CGFloat = 44

    init(selection: Binding<String>) {
        _selection = selection
        _draft = State(initialValue: selection.wrappedValue)
    }

    private var groups: [SymbolCatalog.Group] { SymbolCatalog.groups }

    private func announceCount() {
        AccessibilityNotification.Announcement(String(localized: "\(shownCount) symbols shown", comment: "VoiceOver, after a search or a group chip changes the symbols in view")).post()
    }

    private var shownCount: Int {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty { return SymbolCatalog.search(query).count }
        if let group, let found = groups.first(where: { $0.key == group }) { return found.symbols.count }
        return SymbolCatalog.symbols.count
    }

    var body: some View {
        NavigationStack {
          ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        let found = SymbolCatalog.search(query)
                        if found.isEmpty {
                            noMatch
                        } else {
                            grid(found)
                            countLine
                        }
                    } else if let group, let found = groups.first(where: { $0.key == group }) {
                        grid(found.symbols)
                        countLine
                    } else {
                        ForEach(groups) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                FieldLabel(verbatim: group.title)
                                grid(group.symbols)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            // The chips stay in place while the grid scrolls under them.
            .safeAreaInset(edge: .top, spacing: 0) {
                chips
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(style.paper)
            }
            // Edit opens on the habit's symbol, wherever it sits in the list.
            .task {
                // After the sheet settles, so the lazy grid has laid out.
                guard !draft.isEmpty else { return }
                try? await Task.sleep(for: .milliseconds(300))
                reader.scrollTo(draft, anchor: .center)
            }
            .searchable(text: $query, prompt: Text("Search symbols"))
            .onChange(of: query) { old, text in
                if !text.isEmpty { group = nil }
                // Clearing a search returns the grid: say so. A chip that clears it says so once, here.
                if text.isEmpty, !old.isEmpty { announceCount() }
            }
            // Announced when a chip changes the view, or once typing has paused, never over each keystroke.
            .task(id: query) {
                guard !query.isEmpty else { return }
                try? await Task.sleep(for: .milliseconds(600))
                if !Task.isCancelled { announceCount() }
            }
            .foregroundStyle(style.text, style.secondary, style.tertiary)
            .paperBackground(style)
            .navigationTitle("Symbol")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { selection = draft; dismiss() }
                }
            }
            // A swipe never drops a symbol the user picked: Cancel or Done says which.
            .interactiveDismissDisabled(draft != selection)
          }
        }
        #if os(macOS)
        .frame(minWidth: 460, idealWidth: 520, minHeight: 480, idealHeight: 600)
        #endif
    }

    private var countLine: some View {
        Text("\(shownCount) symbols", comment: "Under the symbol grid: how many symbols are shown")
            .font(style.label(.footnote))
            .foregroundStyle(style.secondary)
    }

    @ViewBuilder
    private var chips: some View {
        let items: [(key: String?, title: String)] = [(nil, String(localized: "All"))] + groups.map { ($0.key, $0.title) }
        let row = ForEach(Array(items.enumerated()), id: \.offset) { index, item in
            chip(item.title, on: group == item.key, position: index + 1, of: items.count) {
                let searching = !query.isEmpty
                group = item.key
                query = ""
                // The count is said once: by the query handler when a search was cleared, otherwise here.
                // Typing that turns a chip off says nothing until it pauses.
                if !searching { announceCount() }
            }
        }
        #if os(macOS)
        FlowLayout(spacing: 8) { row }
        #else
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) { row }
        }
        #endif
    }

    private func chip(_ title: String, on: Bool, position: Int, of count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if on {
                    Image(systemName: "checkmark")
                        .font(style.label(.caption, weight: .bold))
                        .accessibilityHidden(true)
                }
                Text(verbatim: title).font(style.label(.subheadline, weight: on ? .semibold : .regular))
            }
            .foregroundStyle(style.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule().strokeBorder(on ? style.text : style.secondary, lineWidth: on ? style.chosenOutlineWidth : style.openOutlineWidth)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text("\(position) of \(count)", comment: "VoiceOver: the chip's place in the row, for example 7 of 12"))
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// A search with no match is not a dead end: None is offered beside the line.
    private var noMatch: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No symbols match. A habit works without one.", comment: "Symbol search with no result. \"One\" is a symbol. A None button follows")
                .font(style.label(.subheadline))
                .foregroundStyle(style.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { draft = "" } label: {
                Text("None")
                    .font(style.label(.subheadline))
                    .foregroundStyle(style.text)
                    .padding(.horizontal, 12)
                    .frame(minWidth: 44, minHeight: 44)
                    .overlay {
                        if draft.isEmpty { RoundedRectangle(cornerRadius: 10).strokeBorder(style.text, lineWidth: style.outlineWidth) }
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(draft.isEmpty ? .isSelected : [])
        }
    }

    private func grid(_ symbols: [SymbolCatalog.Symbol]) -> some View {
        let size = max(cell, 44)
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: size), spacing: 4)], alignment: .leading, spacing: 4) {
            ForEach(symbols) { symbol in
                let on = symbol.name == draft
                Button { draft = symbol.name } label: {
                    Image(systemName: symbol.name)
                        .font(style.label(.title3))
                        .foregroundStyle(style.text)
                        .frame(width: size, height: size)
                        .overlay {
                            if on { RoundedRectangle(cornerRadius: 10).strokeBorder(style.text, lineWidth: style.outlineWidth) }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .id(symbol.name)
                .accessibilityLabel(Text(verbatim: symbol.label))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}
