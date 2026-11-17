import SwiftUI
import HabitKit

/// One habit on Today: symbol, name, the count line for a counted habit, and the control.
struct HabitRow: View {
    struct Actions {
        var log: (LogAction) -> Void
        var openCount: () -> Void
        var details: () -> Void
        var edit: () -> Void
        var archive: () -> Void
        var move: () -> Void
        var moveUp: (() -> Void)?
        var moveDown: (() -> Void)?
    }

    let habit: Habit
    let day: DayKey
    /// The day's raw total, from one fetch for all of Today.
    let total: Int
    let actions: Actions

    @Environment(Settings.self) private var settings
    @Environment(\.style) private var style
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            largeLayout
        } else {
            HStack(spacing: 12) {
                if settings.controlsLeading { control }
                info
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !settings.controlsLeading { control }
            }
            .frame(minHeight: 56)
        }
    }

    // At accessibility sizes the row is one column: symbol, name, count, then the control.
    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            nameButton
            if habit.kind == .counted { countButton }
            control
                .frame(maxWidth: .infinity, alignment: settings.controlsLeading ? .leading : .trailing)
        }
        .padding(.vertical, 12)
        .padding(.leading, settings.controlsLeading ? 16 : 0)
        .padding(.trailing, settings.controlsLeading ? 0 : 16)
    }

    private var info: some View {
        // Name and count line each keep a 44-point target. They do not overlap.
        VStack(alignment: .leading, spacing: 0) {
            nameButton
            if habit.kind == .counted {
                countButton.padding(.leading, 36)
            }
        }
        .padding(.vertical, habit.kind == .counted ? 0 : 6)
    }

    private var shown: Int { max(0, total) }
    private var state: DayState { habit.state(on: day, today: day, total: shown) }
    private var target: Int? { habit.rule(on: day).target }

    // MARK: Name

    /// A tap on the name or symbol logs, the same as the control. Details, Edit, Move and Archive are in the
    /// row's menu and its swipe actions. For VoiceOver the name and the control both log and both carry the menu.
    private var nameButton: some View {
        Button { actions.log(.tap) } label: {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    if !habit.symbolName.isEmpty { symbol }
                    name
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    symbol.frame(width: 24)
                    name
                }
            }
        }
        .buttonStyle(.plain)
        // On a counted row the name sits low in its target, so the count line reads as part of it.
        .frame(maxWidth: .infinity, minHeight: 44, alignment: habit.kind == .counted && !typeSize.isAccessibilitySize ? .bottomLeading : .leading)
        .contentShape(Rectangle())
        .contextMenu { menu }
        .accessibilityHint(Text(accessibilityHint))
        .accessibilityIdentifier("name-\(habit.name)")
        .accessibilityActions { rowActions }
    }

    private var symbol: some View {
        HabitSymbolImage(name: habit.symbolName)
            .font(style.label(.body))
            .foregroundStyle(style.text)
            .accessibilityHidden(true)
    }

    private var name: some View {
        Text(habit.name)
            .font(style.display(.body))
            .foregroundStyle(style.text)
            .multilineTextAlignment(.leading)
            // Three lines at standard sizes. From xxLarge upward the name is never cut.
            .lineLimit(typeSize >= .xxLarge ? nil : 3)
            .fixedSize(horizontal: false, vertical: typeSize >= .xxLarge)
    }

    @ViewBuilder
    private var menu: some View {
        Button("Details", systemImage: "calendar", action: actions.details)
        Button("Edit", systemImage: "pencil", action: actions.edit)
        Button("Move", systemImage: "arrow.up.arrow.down", action: actions.move)
        Button("Archive", systemImage: "archivebox", action: actions.archive)
    }

    @ViewBuilder
    private var rowActions: some View {
        menu
        if let up = actions.moveUp { Button("Move up", action: up) }
        if let down = actions.moveDown { Button("Move down", action: down) }
    }

    // MARK: Count line

    /// Always shown for a counted habit, "0 of 8 glasses" included. Opens the count sheet.
    private var countButton: some View {
        Button(action: actions.openCount) {
            Text(countLine)
                .font(style.label(.footnote).monospacedDigit())
                .foregroundStyle(style.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                // The outline says "button". Tertiary text measures over 4.8:1, above the 3:1 for shapes.
                .overlay(Capsule().strokeBorder(style.tertiary, lineWidth: 1))
                .padding(.top, 4)
                .frame(minHeight: 44, alignment: .topLeading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(countLine))
        .accessibilityHint(Text("Opens the count"))
        .accessibilityIdentifier("count-\(habit.name)")
    }

    private var countLine: String {
        CountText.line(total: shown, target: target, unit: habit.unit)
    }

    // MARK: Control

    /// The control's target is the full row height by 76 points.
    private var control: some View {
        let large = typeSize.isAccessibilitySize
        return MarkView(
            state: state,
            isToday: true,
            showsPlus: habit.kind == .counted && state != .done,
            size: large ? 44 : 28
        )
        .frame(width: 76)
        .frame(minHeight: large ? 76 : 44, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { actions.log(.tap) }
        .onLongPressGesture(minimumDuration: 0.45) {
            if habit.kind == .counted { actions.openCount() }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(habit.name))
        .accessibilityValue(Text(accessibilityValue))
        .accessibilityHint(Text(accessibilityHint))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("control-\(habit.name)")
        .accessibilityAction { actions.log(.tap) }
        .accessibilityActions { rowActions }
        .modifier(CountAdjustable(habit: habit, log: actions.log, openCount: actions.openCount))
    }

    private var accessibilityValue: String {
        var parts: [String] = []
        if habit.kind == .counted { parts.append(countLine) }
        switch state {
        case .done: parts.append(String(localized: "Done"))
        case .partDone: parts.append(String(localized: "Part done"))
        case .loggedOffSchedule: parts.append(String(localized: "Logged on a day off"))
        case .loggedWhilePaused: parts.append(String(localized: "Logged while paused"))
        default: break
        }
        return parts.joined(separator: ", ")
    }

    private var accessibilityHint: String {
        switch habit.kind {
        case .binary:
            return shown > 0 ? String(localized: "Takes the log back") : String(localized: "Logs it")
        case .counted:
            guard let amount = habit.tapAmount, amount > 0 else { return String(localized: "Opens the count") }
            return String(localized: "Adds \(amount.formatted())")
        }
    }
}

/// VoiceOver adjustable actions for a counted habit: Increase and Decrease by the tap amount.
private struct CountAdjustable: ViewModifier {
    let habit: Habit
    let log: (LogAction) -> Void
    let openCount: () -> Void

    func body(content: Content) -> some View {
        if habit.kind == .counted {
            let step = max(habit.tapAmount ?? 1, 1)
            content
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: log(.add(step))
                    case .decrement: log(.takeAway(step))
                    @unknown default: break
                    }
                }
                .accessibilityAction(named: Text("Change the count"), openCount)
        } else {
            content
        }
    }
}
