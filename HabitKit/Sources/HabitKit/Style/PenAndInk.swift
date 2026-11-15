import Foundation

// Values from docs/tokens.json. A test checks they match.
extension StyleTokens {
    public static let penAndInk = StyleTokens(
        id: .penAndInk,
        displayName: String(localized: "Pen and ink", bundle: .module),
        display: .system(serif: true),
        paper: AppearanceTokens(
            paper: RGB(hex: "#FBFAF6"),
            text: RGB(hex: "#16130F"),
            secondaryAlpha: 0.705,
            tertiaryAlpha: 0.605,
            ruleAlpha: 0.16
        ),
        ink: AppearanceTokens(
            paper: RGB(hex: "#14120F"),
            text: RGB(hex: "#F3EFE6"),
            secondaryAlpha: 0.7,
            tertiaryAlpha: 0.53,
            ruleAlpha: 0.18
        ),
        markAlpha: 1.0,
        hatchAngle: 56,
        hatchLines: 5
    )
}
