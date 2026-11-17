import SwiftUI

/// A style resolved for one appearance, accent and contrast setting.
/// Views read it from the environment. A view never computes a colour or names a font.
public struct ResolvedStyle: Sendable, Equatable {
    public var tokens: StyleTokens
    public var appearance: Appearance
    public var accent: Swatch
    public var increaseContrast: Bool

    public init(tokens: StyleTokens = .penAndInk, appearance: Appearance = .paper, accent: Swatch = .default, increaseContrast: Bool = false) {
        self.tokens = tokens
        self.appearance = appearance
        self.accent = accent
        self.increaseContrast = increaseContrast
    }

    private var t: AppearanceTokens { tokens.tokens(appearance) }

    public var colorScheme: ColorScheme { appearance == .paper ? .light : .dark }

    // MARK: Colours

    public var paper: Color { Self.color(t.paper) }
    public var text: Color { Self.color(t.text) }
    public var secondary: Color { Self.color(t.composited(.secondary)) }
    public var tertiary: Color { Self.color(t.composited(.tertiary)) }
    /// Hairline rules. With Increase Contrast they use the tertiary text colour.
    public var rule: Color { increaseContrast ? tertiary : Self.color(t.text.over(t.paper, alpha: t.ruleAlpha)) }
    /// The mark colour. With Increase Contrast marks are drawn in the text colour.
    public var mark: Color { increaseContrast ? text : Self.color(accent.rgb).opacity(tokens.markAlpha) }

    public func swatchColor(_ swatch: Swatch) -> Color { Self.color(swatch.rgb) }

    // MARK: Lines

    /// Strokes are half a point heavier with Increase Contrast.
    public var markLineWidth: CGFloat { increaseContrast ? 2 : 1.5 }
    public var outlineWidth: CGFloat { increaseContrast ? 1.75 : 1.25 }
    public var ruleWidth: CGFloat { increaseContrast ? 1 : 0.5 }
    /// A chosen option drawn as an outline, such as a day in the form. Heavier than a today outline.
    public var chosenOutlineWidth: CGFloat { outlineWidth * 1.6 }
    /// An option that is not chosen, drawn as an outline.
    public var openOutlineWidth: CGFloat { ruleWidth * 2 }

    // MARK: Type

    /// The style's display face, scaled with the text style.
    public func display(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        switch tokens.display {
        case .system(let serif):
            return .system(style, design: serif ? .serif : .default, weight: weight)
        }
    }

    /// Labels and controls use SF in every style.
    public func label(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .default, weight: weight)
    }

    /// Digits in counts are lining and tabular.
    public func count(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        display(style, weight: weight).monospacedDigit()
    }

    private static func color(_ rgb: RGB) -> Color {
        Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}

extension EnvironmentValues {
    @Entry public var style = ResolvedStyle()
}

extension View {
    /// Paper behind a screen, with system controls tinted in the text colour.
    public func paperBackground(_ style: ResolvedStyle) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(style.paper)
            .tint(style.text)
    }
}
