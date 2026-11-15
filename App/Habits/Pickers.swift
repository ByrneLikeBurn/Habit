import SwiftUI
import HabitKit

/// Day circles in the order of the user's calendar. A chosen day is filled.
struct DayPicker: View {
    @Binding var selection: Weekdays
    let calendar: Calendar
    @Environment(\.style) private var style

    var body: some View {
        let labels = WeekdayText.labels(calendar: calendar)
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { circles(labels) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], alignment: .leading, spacing: 8) { circles(labels) }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func circles(_ labels: [WeekdayLabel]) -> some View {
        ForEach(labels) { label in
            let on = selection.contains(weekday: label.weekday)
            Button {
                selection.formSymmetricDifference(Weekdays(weekday: label.weekday))
            } label: {
                Text(label.short)
                    .font(style.label(.subheadline, weight: .medium))
                    .foregroundStyle(on ? style.paper : style.text)
                    .frame(minWidth: 40, minHeight: 40)
                    .background {
                        if on {
                            Circle().fill(style.text)
                        } else {
                            Circle().strokeBorder(style.secondary, lineWidth: 1)
                        }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(label.full))
            .accessibilityAddTraits(on ? .isSelected : [])
            .frame(maxWidth: .infinity)
        }
    }
}

/// The habit's symbol. The first one is the default.
struct SymbolPicker: View {
    struct Symbol: Identifiable {
        let name: String
        let label: LocalizedStringResource
        var id: String { name }
    }

    static let symbols: [Symbol] = [
        Symbol(name: "drop", label: "Water"),
        Symbol(name: "book", label: "Book"),
        Symbol(name: "leaf", label: "Leaf"),
        Symbol(name: "pencil", label: "Pencil"),
        Symbol(name: "pills", label: "Pills"),
        Symbol(name: "moon", label: "Moon"),
        Symbol(name: "sun.max", label: "Sun"),
        Symbol(name: "figure.walk", label: "Walking"),
        Symbol(name: "bicycle", label: "Bicycle"),
        Symbol(name: "dumbbell", label: "Weights"),
        Symbol(name: "fork.knife", label: "Food"),
        Symbol(name: "cup.and.saucer", label: "Cup"),
        Symbol(name: "music.note", label: "Music"),
        Symbol(name: "paintbrush", label: "Brush"),
        Symbol(name: "bed.double", label: "Bed"),
        Symbol(name: "heart", label: "Heart"),
        Symbol(name: "brain", label: "Mind"),
        Symbol(name: "phone.down", label: "Phone down"),
    ]

    @Binding var selection: String
    @Environment(\.style) private var style

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 4)], spacing: 4) {
            ForEach(Self.symbols) { symbol in
                let on = symbol.name == selection
                Button {
                    selection = symbol.name
                } label: {
                    Image(systemName: symbol.name)
                        .font(style.label(.body))
                        .foregroundStyle(style.text)
                        .frame(width: 44, height: 44)
                        .overlay {
                            if on {
                                RoundedRectangle(cornerRadius: 8).strokeBorder(style.text, lineWidth: style.outlineWidth)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(symbol.label))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}
