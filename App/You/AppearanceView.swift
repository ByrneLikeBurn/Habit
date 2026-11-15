import SwiftUI
import HabitKit

/// One choice per row: a preview, Light or dark, then mark colour.
struct AppearanceView: View {
    @Environment(Settings.self) private var settings
    @Environment(\.style) private var style
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        @Bindable var settings = settings
        List {
            Section("Preview") {
                PreviewRow(symbol: "drop", name: String(localized: "Drink water"), state: .partDone, count: CountText.line(total: 3, target: 8, unit: String(localized: "glasses")))
                PreviewRow(symbol: "book", name: String(localized: "Read"), state: .done, count: nil)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Preview of two habits in the chosen look"))

            Section("Light or dark") {
                if typeSize.isAccessibilitySize {
                    appearancePicker($settings.appearance).pickerStyle(.inline)
                } else {
                    appearancePicker($settings.appearance).pickerStyle(.segmented)
                }
            }

            Section("Mark colour") {
                if typeSize.isAccessibilitySize {
                    ForEach(Swatch.allCases) { swatch in
                        SwatchButton(swatch: swatch, selected: settings.accent == swatch, wide: true) { settings.accent = swatch }
                    }
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(Swatch.allCases) { swatch in
                            SwatchButton(swatch: swatch, selected: settings.accent == swatch, wide: false) { settings.accent = swatch }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .listRowBackground(style.paper)
        .foregroundStyle(style.text)
        .paperBackground(style)
        .navigationTitle("Appearance")
    }

    private func appearancePicker(_ selection: Binding<AppearanceChoice>) -> some View {
        Picker("Light or dark", selection: selection) {
            Text("System").tag(AppearanceChoice.system)
            Text("Paper").tag(AppearanceChoice.paper)
            Text("Ink").tag(AppearanceChoice.ink)
        }
        .labelsHidden()
    }
}

private struct PreviewRow: View {
    let symbol: String
    let name: String
    let state: DayState
    let count: String?
    @Environment(\.style) private var style

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(style.display(.body))
                if let count {
                    Text(count).font(style.label(.footnote)).foregroundStyle(style.secondary)
                }
            }
            Spacer()
            MarkView(state: state, isToday: true, showsPlus: count != nil && state != .done)
        }
        .listRowBackground(style.paper)
    }
}

private struct SwatchButton: View {
    let swatch: Swatch
    let selected: Bool
    let wide: Bool
    let action: () -> Void
    @Environment(\.style) private var style

    var body: some View {
        Button(action: action) {
            let chip = RoundedRectangle(cornerRadius: 3)
                .fill(style.swatchColor(swatch))
                .frame(width: 24, height: 24)
                .padding(4)
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: 5).strokeBorder(style.text, lineWidth: style.outlineWidth)
                    }
                }
            let label = HStack(spacing: 2) {
                Text(swatch.displayName).font(style.label(.caption))
                if selected { Image(systemName: "checkmark").font(style.label(.caption2, weight: .bold)) }
            }
            if wide {
                HStack(spacing: 12) { chip; label; Spacer() }
                    .frame(minHeight: 44)
            } else {
                VStack(spacing: 4) { chip; label }
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(style.text)
        .contentShape(Rectangle())
        .accessibilityLabel(Text(swatch.displayName))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview("Appearance") {
    NavigationStack { AppearanceView() }.previewEnvironment()
}
