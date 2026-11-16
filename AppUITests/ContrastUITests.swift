import XCTest

/// Gate for milestone 2: the contrast of every mark and text token, measured on a simulator
/// against the worst pixel of the paper. If it fails, fix the token, not the floor.
final class ContrastUITests: XCTestCase {
    /// Floors from CLAUDE.md: body, secondary, tertiary for paper and ink, and 3:1 for marks.
    private let floors: [String: (paper: Double, ink: Double)] = [
        "text": (17.7, 16.2), "secondary": (6.8, 8.3), "tertiary": (4.8, 5.1), "dot": (3, 3),
    ]

    func testPaper() throws { try measure(appearance: "paper") }
    func testInk() throws { try measure(appearance: "ink") }

    private func measure(appearance: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-fixture", "today", "-screen", "contrast", "-appearance", appearance]
        app.launch()
        let paperElement = app.descendants(matching: .any)["paper"]
        XCTAssertTrue(paperElement.waitForExistence(timeout: 5))
        sleep(1)
        let shot = Pixels(XCUIScreen.main.screenshot().image)

        // The worst paper pixel is the one closest in luminance to each patch.
        let paper = shot.samples(in: paperElement.frame.insetBy(dx: 4, dy: 4))
        XCTAssertFalse(paper.isEmpty)
        var report: [String] = []
        let ids = Array(floors.keys) + ["ochre", "moss", "leaf", "teal", "blue", "indigo", "plum", "graphite"].map { "mark-\($0)" }
        for id in ids.sorted() {
            let element = app.descendants(matching: .any)["patch-\(id)"]
            XCTAssertTrue(element.exists, id)
            // The middle of the patch, clear of edge antialiasing.
            let patch = shot.samples(in: element.frame.insetBy(dx: element.frame.width * 0.3, dy: element.frame.height * 0.3))
            let colour = Pixels.median(patch)
            let worst = paper.map { Pixels.contrast(colour, $0) }.min() ?? 0
            let floor = floors[id].map { appearance == "paper" ? $0.paper : $0.ink } ?? 3
            report.append(String(format: "%@ %@ %.2f:1 (floor %.1f)", appearance, id, worst, floor))
            XCTAssertGreaterThanOrEqual(worst, floor, "\(appearance) \(id) measured \(worst)")
        }
        let attachment = XCTAttachment(string: report.joined(separator: "\n"))
        attachment.name = "contrast-\(appearance)"
        attachment.lifetime = .keepAlways
        add(attachment)
        // Also written next to the test bundle's temp folder for the report.
        try? report.joined(separator: "\n").write(toFile: NSTemporaryDirectory() + "contrast-\(appearance).txt", atomically: true, encoding: .utf8)
    }
}

/// Screenshot pixels as sRGB values.
private struct Pixels {
    let width: Int
    let height: Int
    let scale: CGFloat
    let data: [UInt8]

    init(_ image: UIImage) {
        let cg = image.cgImage!
        width = cg.width
        height = cg.height
        scale = CGFloat(cg.width) / image.size.width
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &buffer, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        data = buffer
    }

    typealias RGB = (r: Double, g: Double, b: Double)

    func samples(in frame: CGRect) -> [RGB] {
        var out: [RGB] = []
        let x0 = Int(frame.minX * scale), x1 = Int(frame.maxX * scale)
        let y0 = Int(frame.minY * scale), y1 = Int(frame.maxY * scale)
        guard x1 > x0, y1 > y0 else { return [] }
        for y in stride(from: max(0, y0), to: min(height, y1), by: 2) {
            for x in stride(from: max(0, x0), to: min(width, x1), by: 2) {
                let i = (y * width + x) * 4
                out.append((Double(data[i]) / 255, Double(data[i + 1]) / 255, Double(data[i + 2]) / 255))
            }
        }
        return out
    }

    static func median(_ values: [RGB]) -> RGB {
        func m(_ k: KeyPath<(r: Double, g: Double, b: Double), Double>) -> Double {
            let sorted = values.map { $0[keyPath: k] }.sorted()
            return sorted.isEmpty ? 0 : sorted[sorted.count / 2]
        }
        return (m(\.r), m(\.g), m(\.b))
    }

    static func luminance(_ c: RGB) -> Double {
        func lin(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }

    static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
