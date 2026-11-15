import Foundation

/// An sRGB colour as data, so tokens can be measured in tests.
public struct RGB: Hashable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    /// `hex` is "#RRGGBB".
    public init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = Int(digits, radix: 16) ?? 0
        self.init(
            r: Double((value >> 16) & 0xFF) / 255,
            g: Double((value >> 8) & 0xFF) / 255,
            b: Double(value & 0xFF) / 255
        )
    }

    public var hex: String {
        String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    /// This colour at `alpha` laid over `background`.
    public func over(_ background: RGB, alpha: Double) -> RGB {
        RGB(
            r: r * alpha + background.r * (1 - alpha),
            g: g * alpha + background.g * (1 - alpha),
            b: b * alpha + background.b * (1 - alpha)
        )
    }

    /// WCAG 2.2 relative luminance.
    public var luminance: Double {
        func channel(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    /// WCAG 2.2 contrast ratio, unrounded.
    public func contrast(with other: RGB) -> Double {
        let a = luminance
        let b = other.luminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// Hue in degrees, saturation and value, all from HSV.
    public var hsv: (hue: Double, saturation: Double, value: Double) {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        var hue = 0.0
        if delta > 0 {
            if maxC == r { hue = 60 * ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
            else if maxC == g { hue = 60 * ((b - r) / delta + 2) }
            else { hue = 60 * ((r - g) / delta + 4) }
        }
        if hue < 0 { hue += 360 }
        return (hue, maxC == 0 ? 0 : delta / maxC, maxC)
    }

    /// The test for "true red" in docs/spec.md: hue within 15 degrees of 0,
    /// saturation above 0.40 and value above 0.25.
    public var isTrueRed: Bool {
        let (hue, saturation, value) = hsv
        let distance = min(hue, 360 - hue)
        return distance <= 15 && saturation > 0.40 && value > 0.25
    }
}
