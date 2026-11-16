import Foundation
import Testing
import SwiftUI
@testable import HabitKit

/// The repo root, found from this file's path.
let repoRoot = URL(filePath: #filePath)
    .deletingLastPathComponent() // HabitKitTests
    .deletingLastPathComponent() // Tests
    .deletingLastPathComponent() // HabitKit
    .deletingLastPathComponent() // repo

private func tokensJSON() throws -> [String: Any] {
    let data = try Data(contentsOf: repoRoot.appending(path: "docs/tokens.json"))
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

@Suite("Style")
struct StyleTests {
    @Test func noStyleTokenSwatchOrPaletteColourIsRed() throws {
        var colours: [String: RGB] = [:]
        for style in StyleID.allCases {
            for appearance in Appearance.allCases {
                let t = style.tokens.tokens(appearance)
                colours["\(style) \(appearance) paper"] = t.paper
                colours["\(style) \(appearance) text"] = t.text
            }
        }
        for swatch in Swatch.allCases { colours["swatch \(swatch)"] = swatch.rgb }
        // Palettes ship in milestone 5. Their stops are checked now, from the token file.
        let palettes = try #require(try tokensJSON()["palettes"] as? [String: [String: Any]])
        for (name, palette) in palettes {
            for (key, value) in palette {
                let hexes = (value as? [String]) ?? [(value as? String)].compactMap { $0 }
                for (i, hex) in hexes.enumerated() { colours["palette \(name) \(key) \(i)"] = RGB(hex: hex) }
            }
        }
        #expect(colours.count > 50)
        let red = colours.filter { $0.value.isTrueRed }.map(\.key).sorted()
        #expect(red.isEmpty, "Red: \(red)")
    }

    @Test func theRedTestCatchesRed() {
        #expect(RGB(hex: "#E02020").isTrueRed)
        #expect(RGB(hex: "#C0392B").isTrueRed)
        #expect(!RGB(hex: "#4C78C8").isTrueRed)
    }

    @Test(arguments: StyleID.allCases)
    func textMeetsTheFloorOnTheWorstPixelOfThePaper(style: StyleID) {
        for appearance in Appearance.allCases {
            let tokens = style.tokens
            let paper = tokens.worstPaper(appearance)
            for level in TextLevel.allCases {
                let ratio = tokens.tokens(appearance).composited(level).contrast(with: paper)
                #expect(ratio >= ContrastFloor.ratio(level, appearance), "\(style) \(appearance) \(level): \(ratio)")
            }
        }
    }

    @Test(arguments: StyleID.allCases)
    func everySwatchMarkIsAtLeastThreeToOneAsDrawn(style: StyleID) {
        let tokens = style.tokens
        for appearance in Appearance.allCases {
            let paper = tokens.worstPaper(appearance)
            for swatch in Swatch.allCases {
                let drawn = swatch.rgb.over(paper, alpha: tokens.markAlpha)
                #expect(drawn.contrast(with: paper) >= ContrastFloor.mark, "\(swatch) on \(style) \(appearance)")
            }
        }
    }

    @Test func swiftTokensMatchTheTokenFile() throws {
        let json = try tokensJSON()
        let styles = try #require(json["styles"] as? [String: [String: Any]])
        let pen = try #require(styles["penAndInk"])
        for appearance in Appearance.allCases {
            let file = try #require(pen[appearance.rawValue] as? [String: Any])
            let swift = StyleTokens.penAndInk.tokens(appearance)
            #expect(RGB(hex: file["paper"] as! String) == swift.paper)
            #expect(RGB(hex: file["text"] as! String) == swift.text)
            #expect(file["secondaryAlpha"] as? Double == swift.secondaryAlpha)
            #expect(file["tertiaryAlpha"] as? Double == swift.tertiaryAlpha)
            #expect(file["ruleAlpha"] as? Double == swift.ruleAlpha)
        }
        let swatches = try #require(json["swatches"] as? [String: String])
        #expect(Set(swatches.keys) == Set(Swatch.allCases.map(\.rawValue)))
        for swatch in Swatch.allCases {
            #expect(RGB(hex: swatches[swatch.rawValue]!) == swatch.rgb)
        }
        #expect(json["hatchAngleDegrees"] as? Double == StyleTokens.penAndInk.hatchAngle)
        let floors = try #require(json["contrastFloor"] as? [String: [String: Double]])
        for appearance in Appearance.allCases {
            for level in TextLevel.allCases {
                #expect(floors[appearance.rawValue]?[level.rawValue] == ContrastFloor.ratio(level, appearance))
            }
        }
    }

    @Test func unknownStoredValuesFallBack() {
        #expect(StyleID.resolve("watercolour-typo") == .penAndInk)
        #expect(StyleID.resolve(nil) == .penAndInk)
        #expect(Swatch.resolve("crimson") == .blue)
        #expect(AppearanceChoice.resolve("sepia") == .system)
        // Scenes and palettes do not exist until milestone 5. Their fallbacks to Lake and auto are tested then.
    }
}

@Suite("Count words")
struct CountTextTests {
    let britain = Locale(identifier: "en_GB")

    @Test func lines() {
        #expect(CountText.line(total: 3, target: 8, unit: "glasses", locale: britain) == "3 of 8 glasses")
        #expect(CountText.line(total: 0, target: 8, unit: "glasses", locale: britain) == "0 of 8 glasses")
        #expect(CountText.line(total: 3, target: nil, unit: "glasses", locale: britain) == "3 glasses")
        #expect(CountText.line(total: 3, target: 8, unit: "", locale: britain) == "3 of 8")
        #expect(CountText.line(total: 12_000, target: 15_000, unit: "steps", locale: britain) == "12,000 of 15,000 steps")
    }

    @Test func parsingTypedNumbers() {
        #expect(CountText.parse("15000", locale: britain) == 15_000)
        #expect(CountText.parse("15,000", locale: britain) == 15_000)
        #expect(CountText.parse(" 25 ", locale: britain) == 25)
        #expect(CountText.parse("", locale: britain) == nil)
        #expect(CountText.parse("2.5", locale: britain) == nil)
        #expect(CountText.parse("abc", locale: britain) == nil)
    }

    @Test func defaultTapAmount() {
        #expect(CountText.defaultTapAmount(forTarget: nil) == 1)
        #expect(CountText.defaultTapAmount(forTarget: 8) == 1)
        #expect(CountText.defaultTapAmount(forTarget: 20) == 1)
        #expect(CountText.defaultTapAmount(forTarget: 21) == nil)
    }
}

/// The small "logged" diamond is split by a flat gap, so it blurs apart from the done square. See docs/m4-blur-test.md.
@Suite struct SmallDiamondTests {
    @Test func theSmallDiamondHasAFlatGapOfTwoAndAHalfUnitsInTwelve() {
        let box = CGRect(x: 0, y: 0, width: 12, height: 12)
        let path = SmallMark.cutDiamond(in: box)
        // The gap runs from 4.75 to 7.25 across the middle and holds nothing.
        for x in stride(from: 0.5, through: 11.5, by: 0.5) {
            #expect(!path.contains(CGPoint(x: x, y: 6)))
            #expect(!path.contains(CGPoint(x: x, y: 4.8)))
            #expect(!path.contains(CGPoint(x: x, y: 7.2)))
        }
        // Each half is a triangle that reaches the cell's edge at its point.
        #expect(path.contains(CGPoint(x: 6, y: 0.5)))
        #expect(path.contains(CGPoint(x: 6, y: 11.5)))
        #expect(path.contains(CGPoint(x: 6, y: 4.5)))
        #expect(path.contains(CGPoint(x: 6, y: 7.5)))
        // At the gap's edge the half-width follows the diamond: 6 × (1 − 2.5/12) = 4.75.
        #expect(path.contains(CGPoint(x: 1.4, y: 4.7)))
        #expect(!path.contains(CGPoint(x: 1.0, y: 4.7)))
        #expect(path.boundingRect.minY == 0 && path.boundingRect.maxY == 12)
    }

    @Test func theCutIsAFifthOfTheMarkUpToTwelvePointsAndAHairlineAbove() {
        #expect(SmallMark.diamondCut(width: 6) == 1.25)
        #expect(SmallMark.diamondCut(width: 12) == 2.5)
        #expect(SmallMark.diamondCut(width: 12.5) == 1.25)
        #expect(SmallMark.diamondCut(width: 19) == 1.25)
        // A full-size diamond, 19 points wide, is cut by a 1.25 point line and nothing wider.
        let path = SmallMark.cutDiamond(in: CGRect(x: 0, y: 0, width: 19, height: 19))
        #expect(!path.contains(CGPoint(x: 9.5, y: 9.5)))
        #expect(!path.contains(CGPoint(x: 9.5, y: 8.95)))
        #expect(path.contains(CGPoint(x: 9.5, y: 8.8)))
        #expect(path.contains(CGPoint(x: 9.5, y: 10.2)))
    }
}
