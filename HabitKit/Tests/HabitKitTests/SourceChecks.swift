import Foundation
import Testing

/// Checks over the Swift sources of the app and the package.
@Suite("Source checks")
struct SourceChecks {
    private static let styleFolder = "HabitKit/Sources/HabitKit/Style/"
    private static let intentFile = "Shared/LogHabitIntent.swift"

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

    /// The diamond's cut jumps from the wide gap to the hairline at 12 points. Every full-size mark the app draws must sit
    /// clearly above it, so one screen never mixes the two drawings. MarkView's diamond is 68% of its size, so 18 is the floor.
    /// Each `MarkView(state:` call is read to its closing bracket, across lines. A size the test cannot read as numbers fails.
    @Test func everyFullSizeMarkIsAboveTheCutThreshold() throws {
        let start = try Regex(#"(?:^|[^A-Za-z])MarkView\(\s*state:"#)
        let number = try Regex(#"[0-9]+(?:\.[0-9]+)?"#)
        var checked = 0
        for file in try swiftFiles() {
            for match in file.text.matches(of: start) {
                // From the opening bracket to the one that closes it.
                let open = file.text[match.range].lastIndex(of: "(")!
                var depth = 0, index = open, close = open
                while index < file.text.endIndex {
                    let c = file.text[index]
                    if c == "(" { depth += 1 } else if c == ")" { depth -= 1; if depth == 0 { close = index; break } }
                    index = file.text.index(after: index)
                }
                let arguments = file.text[file.text.index(after: open)..<close]
                guard let sizeLabel = arguments.range(of: "size:") else {
                    checked += 1 // the default, 28
                    continue
                }
                // The size runs to the next argument or the end.
                var expression = arguments[sizeLabel.upperBound...]
                if let comma = expression.firstIndex(of: ",") { expression = expression[..<comma] }
                let sizes = expression.matches(of: number).compactMap { Double(expression[$0.range]) }
                #expect(!sizes.isEmpty, "\(file.path): a MarkView size the test cannot read: \(expression)")
                for size in sizes {
                    #expect(size * 0.68 > 12, "\(file.path): a MarkView of \(size) points draws its diamond under 12 points")
                }
                checked += 1
            }
        }
        #expect(checked > 3, "Too few MarkView calls were found")
    }

    /// The plural VoiceOver label for the "Not scheduled today" group has both English forms.
    /// The UI test reaches only "one", on the fixture's Saturday.
    @Test func theNotScheduledLabelHasBothPluralForms() throws {
        let data = try Data(contentsOf: repoRoot.appending(path: "App/Localizable.xcstrings"))
        let catalog = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: Any])
        let entry = try #require(strings["Not scheduled today, %lld habits"] as? [String: Any])
        let plural = try #require(((((entry["localizations"] as? [String: Any])?["en"] as? [String: Any])?["variations"] as? [String: Any])?["plural"]) as? [String: Any])
        func value(_ form: String) -> String? { ((plural[form] as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String }
        #expect(value("one") == "Not scheduled today, %lld habit")
        #expect(value("other") == "Not scheduled today, %lld habits")
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
        // The name, not the call, so a space or a stored reference is caught too.
        try! Regex(#"(?:^|[^A-Za-z0-9_])LogWriter\s*\.\s*log(?![A-Za-z0-9_])"#),
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
    static var importPattern: Regex<Substring> { try! Regex(#"(?:^|[^A-Za-z0-9_])importEvents(?![A-Za-z0-9_])"#) }

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
        #expect("let w = LogWriter.importEvents; try w(plan, ctx)".contains(Self.importPattern))
        #expect("LogWriter.importEvents (plan, in: ctx)".contains(Self.importPattern))
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
        let samples = ["try LogWriter.log(.tap, habit: h)", "try LogWriter.log (.tap, habit: h)", "let write = LogWriter.log", "context.insert(LogEvent(delta: 1))", "event.delta = 4", "event.delta += 1"]
        for sample in samples {
            #expect(Self.writePatterns.contains { sample.contains($0) }, "\(sample)")
        }
        #expect(!Self.writePatterns.contains { "if event.delta == 0 {}".contains($0) })
    }

    @Test func checksSeeEveryTarget() throws {
        let folders = Set(try swiftFiles().map { String($0.path.split(separator: "/").first ?? "") })
        #expect(folders.isSuperset(of: ["App", "AppUITests", "HabitKit", "Shared", "Widget"]), "\(folders)")
    }

    /// The app's container is built through the migration plan, never a bare Schema.
    @Test func theContainerUsesTheMigrationPlan() throws {
        let app = try swiftFiles().filter { $0.path.hasPrefix("App/") || $0.path.hasPrefix("Shared/") || $0.path.hasPrefix("Widget/") }
        let builders = app.filter { $0.text.contains("ModelContainer(") }
        #expect(!builders.isEmpty)
        for file in builders {
            #expect(file.text.contains("migrationPlan: HabitMigrationPlan.self"), "\(file.path)")
        }
    }

    /// No network calls, analytics or logging of user actions.
    @Test func noNetworkOrLogging() throws {
        let banned = ["URLSession", "URLRequest", "NWConnection", "os_log(", "Logger(", "print(", "NSLog(", "debugPrint(", "dump("]
        var offences: [String] = []
        for file in try swiftFiles() {
            for token in banned where file.text.contains(token) {
                offences.append("\(file.path) \(token)")
            }
        }
        #expect(offences.isEmpty, "\(offences)")
    }
}
