import Foundation

/// The eight mark colours. The set runs round the wheel from ochre to plum with a gap where red would be.
/// The accent tints marks only, never text, never rules.
public enum Swatch: String, CaseIterable, Sendable, Codable, Identifiable {
    case ochre, moss, leaf, teal, blue, indigo, plum, graphite

    /// Blue until scenes arrive in milestone 5. The owner set this.
    public static let `default` = Swatch.blue

    /// An unknown stored value falls back to the default.
    public static func resolve(_ stored: String?) -> Swatch {
        stored.flatMap(Swatch.init(rawValue:)) ?? .default
    }

    public var id: String { rawValue }

    public var rgb: RGB {
        switch self {
        case .ochre: RGB(hex: "#A47C1E")
        case .moss: RGB(hex: "#6E8B2E")
        case .leaf: RGB(hex: "#3E8A45")
        case .teal: RGB(hex: "#2A8A86")
        case .blue: RGB(hex: "#4C78C8")
        case .indigo: RGB(hex: "#6A6AD0")
        case .plum: RGB(hex: "#9A5DB0")
        case .graphite: RGB(hex: "#6F6B66")
        }
    }

    public var displayName: String {
        switch self {
        case .ochre: String(localized: "Ochre", bundle: .module)
        case .moss: String(localized: "Moss", bundle: .module)
        case .leaf: String(localized: "Leaf", bundle: .module)
        case .teal: String(localized: "Teal", bundle: .module)
        case .blue: String(localized: "Blue", bundle: .module)
        case .indigo: String(localized: "Indigo", bundle: .module)
        case .plum: String(localized: "Plum", bundle: .module)
        case .graphite: String(localized: "Graphite", bundle: .module)
        }
    }
}
