import Foundation
import Testing

/// Checks over the Swift sources of the app and the package.
@Suite("Source checks")
struct SourceChecks {
    private static let styleFolder = "HabitKit/Sources/HabitKit/Style/"
    private static let intentFile = "App/Intents/LogHabitIntent.swift"

    /// Every Swift source in the repo except build output and tools. New targets are covered without a change here.
    private func swiftFiles() throws -> [(path: String, text: String)] {
        let skip: Set<String> = ["DerivedData", "build", "tools", "docs", ".git", ".build"]
        let top = try FileManager.default.contentsOfDirectory(at: repoRoot, includingPropertiesForKeys: [.isDirectoryKey])
        let roots = top.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true && !skip.contains($0.lastPathComponent) }
        var files: [(String, String)] = []
        for root in roots {
            guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" && !url.path.contains("/.build/") && !url.path.contains("/HabitKit/Tests/") {
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

    /// Habit names can be health details. Every intent, in any target, needs an unlocked device.
    @Test func everyIntentNeedsAnUnlockedDevice() throws {
        let intent = try Regex<Substring>(#":\s*(?:[A-Za-z]+,\s*)*(?:AppIntent|AudioPlaybackIntent|SetValueIntent|ControlConfigurationIntent|WidgetConfigurationIntent)\b"#)
        let files = try swiftFiles().filter { $0.text.contains(intent) }
        #expect(files.contains { $0.path == Self.intentFile }, "No intents were found")
        for file in files {
            #expect(file.text.contains("authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication"), "\(file.path)")
        }
    }

    /// Invariant 5: every LogEvent is written by LogHabitIntent, in any target.
    static var writePatterns: [Regex<Substring>] { [
        try! Regex(#"LogWriter\.log\("#),
        try! Regex(#"(?:^|[^A-Za-z_.])LogEvent\("#),
        try! Regex(#"\.delta\s*[-+]?=[^=]"#),
    ] }
    static let writeAllowed: Set<String> = [
        intentFile,
        "HabitKit/Sources/HabitKit/Logic/LogWriter.swift",
        "HabitKit/Sources/HabitKit/Models/Schema.swift",
    ]

    /// Invariant 5, second entry: only the app's import file calls `importEvents`.
    static let importFile = "App/Data/ImportExport.swift"
    static var importPattern: Regex<Substring> { try! Regex(#"importEvents\("#) }

    @Test func onlyTheImportFileImports() throws {
        let allowed: Set<String> = [Self.importFile, "HabitKit/Sources/HabitKit/Logic/LogWriter.swift"]
        var offences: [String] = []
        var found = false
        for file in try swiftFiles() where !file.path.hasPrefix("HabitKit/Tests/") {
            for (number, line) in file.text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() where line.contains(Self.importPattern) {
                if file.path == Self.importFile { found = true }
                if !allowed.contains(file.path) { offences.append("\(file.path):\(number + 1)") }
            }
        }
        #expect(found, "The import file does not call importEvents")
        #expect(offences.isEmpty, "\(offences)")
        #expect("try LogWriter.importEvents(plan, in: context)".contains(Self.importPattern))
    }

    @Test func onlyTheIntentWritesLogs() throws {
        var offences: [String] = []
        for file in try swiftFiles() where !Self.writeAllowed.contains(file.path) && !file.path.hasPrefix("HabitKit/Tests/") {
            for (number, line) in file.text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                if Self.writePatterns.contains(where: { line.contains($0) }) {
                    offences.append("\(file.path):\(number + 1)")
                }
            }
        }
        #expect(offences.isEmpty, "\(offences)")
    }

    @Test func theWriteCheckCanFail() {
        let samples = ["try LogWriter.log(.tap, habit: h)", "context.insert(LogEvent(delta: 1))", "event.delta = 4", "event.delta += 1"]
        for sample in samples {
            #expect(Self.writePatterns.contains { sample.contains($0) }, "\(sample)")
        }
        #expect(!Self.writePatterns.contains { "if event.delta == 0 {}".contains($0) })
    }

    @Test func checksSeeEveryTarget() throws {
        let folders = Set(try swiftFiles().map { String($0.path.split(separator: "/").first ?? "") })
        #expect(folders.isSuperset(of: ["App", "AppUITests", "HabitKit"]), "\(folders)")
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
