import Foundation
import Testing

/// Checks over the Swift sources of the app and the package.
@Suite("Source checks")
struct SourceChecks {
    private static let styleFolder = "HabitKit/Sources/HabitKit/Style/"
    private static let intentFile = "App/Intents/LogHabitIntent.swift"

    private func swiftFiles() throws -> [(path: String, text: String)] {
        let roots = ["App", "HabitKit/Sources"].map { repoRoot.appending(path: $0) }
        var files: [(String, String)] = []
        for root in roots {
            guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let relative = String(url.path(percentEncoded: false).dropFirst(repoRoot.path(percentEncoded: false).count))
                files.append((relative, try String(contentsOf: url, encoding: .utf8)))
            }
        }
        return files
    }

    @Test func sourcesAreFound() throws {
        let files = try swiftFiles()
        #expect(files.contains { $0.path.hasPrefix(Self.styleFolder) })
        #expect(files.contains { $0.path == Self.intentFile }, "The app sources were not found")
    }

    /// Tokens live in the style files only. A view that computes a colour or names a font is a bug.
    @Test func coloursAndFontsAreNamedOnlyInTheStyleFiles() throws {
        // `Color(` as a call, not as the end of a name such as `swatchColor(`.
        let banned: [Regex<Substring>] = [
            try Regex(#"(?:^|[^A-Za-z_])(?:Color|UIColor|NSColor)\("#),
            try Regex(#"\.custom\("#),
            try Regex(#"Font\.system\("#),
            try Regex(#"\.foregroundColor\("#),
            try Regex(#"\.red\b"#),
        ]
        var offences: [String] = []
        for file in try swiftFiles() where !file.path.hasPrefix(Self.styleFolder) {
            for (number, line) in file.text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                for pattern in banned where line.contains(pattern) {
                    offences.append("\(file.path):\(number + 1) \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        #expect(offences.isEmpty, "\(offences)")
    }

    @Test func theColourCheckCanFail() throws {
        let pattern = try Regex<Substring>(#"(?:^|[^A-Za-z_])(?:Color|UIColor|NSColor)\("#)
        #expect("let c = Color(red: 1, green: 0, blue: 0)".contains(pattern))
        #expect(".fill(Color(.sRGB, red: 1, green: 1, blue: 1))".contains(pattern))
        #expect(!"style.swatchColor(swatch)".contains(pattern))
    }

    /// Invariant 5: every LogEvent is written by LogHabitIntent.
    @Test func onlyTheIntentWritesLogs() throws {
        var offences: [String] = []
        for file in try swiftFiles() where file.path.hasPrefix("App/") && file.path != Self.intentFile {
            if file.text.contains("LogWriter.log(") || file.text.contains("LogEvent(") {
                offences.append(file.path)
            }
        }
        #expect(offences.isEmpty, "\(offences)")
    }

    /// The app's container is built through the migration plan, never a bare Schema.
    @Test func theContainerUsesTheMigrationPlan() throws {
        let app = try swiftFiles().filter { $0.path.hasPrefix("App/") }
        let builders = app.filter { $0.text.contains("ModelContainer(") }
        #expect(!builders.isEmpty)
        for file in builders {
            #expect(file.text.contains("migrationPlan: HabitMigrationPlan.self"), "\(file.path)")
        }
    }

    /// No network calls, analytics or logging of user actions.
    @Test func noNetworkOrLogging() throws {
        let banned = ["URLSession", "URLRequest", "NWConnection", "os_log(", "Logger(", "print("]
        var offences: [String] = []
        for file in try swiftFiles() {
            for token in banned where file.text.contains(token) {
                offences.append("\(file.path) \(token)")
            }
        }
        #expect(offences.isEmpty, "\(offences)")
    }
}
