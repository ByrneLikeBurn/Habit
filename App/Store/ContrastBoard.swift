import SwiftUI
import HabitKit

/// A screen for the contrast gate only (`-screen contrast`). It draws every text level as a filled
/// patch, the dot, and a done mark in each of the eight swatches, each on bare paper with an
/// identifier, so a UI test can measure the drawn pixels against the paper on a simulator.
struct ContrastBoard: View {
    @Environment(Settings.self) private var settings
    @Environment(\.style) private var style

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                patch("text") { Rectangle().fill(style.text) }
                patch("secondary") { Rectangle().fill(style.secondary) }
                patch("tertiary") { Rectangle().fill(style.tertiary) }
                patch("dot") { Rectangle().fill(style.tertiary) }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(60), spacing: 16), count: 4), alignment: .leading, spacing: 16) {
                ForEach(Swatch.allCases) { swatch in
                    patch("mark-\(swatch.rawValue)") {
                        MarkView(state: .done, size: 60)
                            .environment(\.style, ResolvedStyle(tokens: style.tokens, appearance: style.appearance, accent: swatch, increaseContrast: style.increaseContrast))
                    }
                }
            }
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 120)
                .accessibilityElement()
                .accessibilityIdentifier("paper")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(style.paper)
    }

    private func patch(_ id: String, @ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(width: 60, height: 60)
            .accessibilityElement()
            .accessibilityIdentifier("patch-\(id)")
    }
}
