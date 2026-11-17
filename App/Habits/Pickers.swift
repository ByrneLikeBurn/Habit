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
struct FieldLabel: View {
    let title: LocalizedStringKey
    @Environment(\.style) private var style

    init(_ title: LocalizedStringKey) { self.title = title }

    var body: some View {
        Text(title)
            .textCase(.uppercase)
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
        // Two letters do not fit a 44-point circle at accessibility sizes, so the days become a list of
        // full names, each with a checkmark when chosen, as Logging does.
        if typeSize.isAccessibilitySize { list } else { circles }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(WeekdayText.labels(calendar: calendar)) { label in
                let on = selection.contains(weekday: label.weekday)
                Button {
                    selection.formSymmetricDifference(Weekdays(weekday: label.weekday))
                } label: {
                    HStack {
                        Text(label.full).font(style.label(.body, weight: on ? .semibold : .regular))
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
        HStack(spacing: 4) {
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
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                    .foregroundStyle(on ? style.text : style.secondary)
                    .frame(maxWidth: 44, minHeight: 44)
                    .aspectRatio(1, contentMode: .fit)
                    .background {
                        Circle().strokeBorder(on ? style.text : style.secondary, lineWidth: on ? style.outlineWidth * 1.6 : style.ruleWidth * 2)
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

    /// Two letters at equal width, for example "Mo" and "Tu".
    static func twoLetters(_ label: WeekdayLabel, calendar: Calendar) -> String {
        String(calendar.shortStandaloneWeekdaySymbols[label.weekday - 1].prefix(2))
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
    }

    private func shortcut(_ title: LocalizedStringKey, matches: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .underline(!matches)
                .font(style.label(.subheadline, weight: .medium))
                .foregroundStyle(matches ? style.tertiary : style.text)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(matches)
    }
}

// MARK: Symbols

/// The form's one row: None, five symbols and "More…". A symbol chosen from More takes the fifth slot.
struct SymbolRow: View {
    @Binding var selection: String
    /// Called before the picker opens, so the form can put its keyboard away.
    var willChoose: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var typeSize
    // The symbols screenshot opens the picker at once.
    @State private var choosing = LaunchOptions.current.screen == .symbols
    @Environment(\.style) private var style

    private var shown: [String] {
        var names = SymbolCatalog.firstRow
        if !selection.isEmpty, !names.contains(selection) { names[names.count - 1] = selection }
        return names
    }

    var body: some View {
        Group {
            // At accessibility sizes the row wraps, so nothing runs off the screen.
            if typeSize.isAccessibilitySize {
                FlowLayout(spacing: 12, lineSpacing: 8) { cells }
            } else {
                HStack(spacing: 0) { cells }
            }
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
        .frame(maxWidth: typeSize.isAccessibilitySize ? nil : .infinity)
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

    private var shownCount: Int {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty { return SymbolCatalog.search(query).count }
        if let group, let found = groups.first(where: { $0.key == group }) { return found.symbols.count }
        return SymbolCatalog.symbols.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    chips
                    if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        grid(SymbolCatalog.search(query))
                        countLine
                    } else if let group, let found = groups.first(where: { $0.key == group }) {
                        grid(found.symbols)
                        countLine
                    } else {
                        ForEach(groups) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(verbatim: group.title)
                                    .textCase(.uppercase)
                                    .font(style.label(.caption, weight: .medium))
                                    .foregroundStyle(style.secondary)
                                    .accessibilityAddTraits(.isHeader)
                                grid(group.symbols)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .searchable(text: $query, prompt: Text("Search symbols"))
            .onChange(of: query) { _, text in
                if !text.isEmpty { group = nil }
            }
            .onChange(of: shownCount) { _, count in
                AccessibilityNotification.Announcement(String(localized: "\(count) symbols shown", comment: "VoiceOver, after a search or a group chip changes the symbols in view")).post()
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
                group = item.key
                query = ""
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
                Capsule().strokeBorder(on ? style.text : style.secondary, lineWidth: on ? style.outlineWidth * 1.6 : style.ruleWidth * 2)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text("\(position) of \(count)", comment: "VoiceOver: the chip's place in the row, for example 7 of 12"))
        .accessibilityAddTraits(on ? .isSelected : [])
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
                .accessibilityLabel(Text(verbatim: symbol.label))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}
