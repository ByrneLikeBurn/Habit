import Foundation

/// The styles. Adding one changes nothing outside the style files and the picker.
public enum StyleID: String, CaseIterable, Sendable, Codable {
    case penAndInk

    /// An unknown stored value falls back to Pen and ink.
    public static func resolve(_ stored: String?) -> StyleID {
        stored.flatMap(StyleID.init(rawValue:)) ?? .penAndInk
    }

    public var tokens: StyleTokens {
        switch self {
        case .penAndInk: .penAndInk
        }
    }
}

/// Light or dark. System follows the device.
public enum AppearanceChoice: String, CaseIterable, Sendable, Codable {
    case system, paper, ink

    public static func resolve(_ stored: String?) -> AppearanceChoice {
        stored.flatMap(AppearanceChoice.init(rawValue:)) ?? .system
    }
}

/// The two appearances a style is drawn in.
public enum Appearance: String, CaseIterable, Sendable {
    case paper, ink
}

public enum TextLevel: String, CaseIterable, Sendable {
    case body, secondary, tertiary
}

/// One appearance of one style.
public struct AppearanceTokens: Sendable, Hashable {
    public var paper: RGB
    public var text: RGB
    public var secondaryAlpha: Double
    public var tertiaryAlpha: Double
    public var ruleAlpha: Double

    public func alpha(_ level: TextLevel) -> Double {
        switch level {
        case .body: 1
        case .secondary: secondaryAlpha
        case .tertiary: tertiaryAlpha
        }
    }

    /// The text colour as drawn on bare paper.
    public func composited(_ level: TextLevel) -> RGB {
        text.over(paper, alpha: alpha(level))
    }
}

/// How a style draws its display type.
public enum DisplayDesign: Sendable, Hashable {
    /// A system design, such as New York (serif). It scales with the text style.
    case system(serif: Bool)
}

public struct StyleTokens: Sendable, Hashable {
    public var id: StyleID
    public var displayName: String
    public var display: DisplayDesign
    public var paper: AppearanceTokens
    public var ink: AppearanceTokens
    /// Mark opacity as drawn.
    public var markAlpha: Double
    /// Hatching angle in degrees from horizontal, rising to the right. It does not mirror.
    public var hatchAngle: Double
    /// Hatch lines in a part-done mark.
    public var hatchLines: Int

    public func tokens(_ appearance: Appearance) -> AppearanceTokens {
        appearance == .paper ? paper : ink
    }

    /// The worst pixel of the paper. Pen and ink paper is flat, so it is the paper itself.
    public func worstPaper(_ appearance: Appearance) -> RGB {
        tokens(appearance).paper
    }
}

/// The text contrast floor. Text contrast is a fixed constant the user cannot break.
public enum ContrastFloor {
    public static func ratio(_ level: TextLevel, _ appearance: Appearance) -> Double {
        switch (appearance, level) {
        case (.paper, .body): 17.7
        case (.paper, .secondary): 6.8
        case (.paper, .tertiary): 4.8
        case (.ink, .body): 16.2
        case (.ink, .secondary): 8.3
        case (.ink, .tertiary): 5.1
        }
    }

    /// WCAG 2.2 minimum for a shape that carries information.
    public static let mark = 3.0
}
