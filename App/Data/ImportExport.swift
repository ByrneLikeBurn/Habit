import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import HabitKit

/// Export and import. The file is made only when the user asks, goes only to the system share
/// sheet (a save panel on the Mac), and the app makes no network call.
enum DataTransfer {
    /// The app's own temporary folder for export files. Swept at launch.
    static var exportFolder: URL {
        FileManager.default.temporaryDirectory.appending(path: "Export", directoryHint: .isDirectory)
    }

    static var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    /// Removes every export file left behind, for example after the app was closed mid-share. Launch only,
    /// so a share running in another window keeps its file.
    static func sweep() {
        try? FileManager.default.removeItem(at: exportFolder)
    }

    /// Removes one export's folder when its sheet closes.
    static func remove(_ file: URL) {
        let folder = file.deletingLastPathComponent()
        guard folder.deletingLastPathComponent().standardizedFileURL == exportFolder.standardizedFileURL else { return }
        try? FileManager.default.removeItem(at: folder)
    }

    static func exportData(context: ModelContext, clock: HabitClock) throws -> Data {
        try ExportFile.make(from: context, appBuild: appBuild, now: clock.now()).encoded()
    }

    static func fileName(clock: HabitClock) -> String {
        ExportFile.fileName(for: clock.now(), calendar: clock.calendar)
    }

    /// Writes the export to its own temporary folder with complete file protection.
    static func writeTemporaryFile(context: ModelContext, clock: HabitClock) throws -> URL {
        let data = try exportData(context: context, clock: clock)
        let folder = exportFolder.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: fileName(clock: clock))
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
        return url
    }

    /// Reads a picked file. The size is checked before the file is read.
    @MainActor
    static func plan(for url: URL, context: ModelContext) -> Result<ImportPlan, ImportProblem> {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > ImportLimits.maxBytes {
            return .failure(.tooLarge)
        }
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return .failure(.notAHabitExport) }
        return plan(data: data, context: context)
    }

    @MainActor
    static func plan(data: Data, context: ModelContext) -> Result<ImportPlan, ImportProblem> {
        do {
            return .success(try ImportPlan.make(from: data, in: context))
        } catch {
            return .failure(error)
        }
    }

    /// The one place import writes. Invariant 5: a source check keeps every other file from calling it.
    @MainActor
    static func write(_ plan: ImportPlan, context: ModelContext) -> Result<LogWriter.ImportResult, ImportProblem> {
        do {
            return .success(try LogWriter.importEvents(plan, in: context))
        } catch let problem as ImportProblem {
            return .failure(problem)
        } catch {
            return .failure(.damaged)
        }
    }
}

/// Where the import flow is.
enum ImportStage: Identifiable {
    case preview(ImportPlan)
    case done(LogWriter.ImportResult)
    case problem(ImportProblem)

    var id: String {
        switch self {
        case .preview: "preview"
        case .done: "done"
        case .problem(let p): "problem-\(p)"
        }
    }
}

/// The import sheet: a preview with Import and Cancel, then what was added, or why nothing changed.
struct ImportSheet: View {
    let stage: ImportStage
    var chooseAnother: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.style) private var style
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(Settings.self) private var settings
    @Query private var habits: [Habit]
    /// Set on the first tap, so a double tap cannot write the file twice.
    @State private var importing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    content
                }
                .padding(20)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .paperBackground(style)
            .navigationTitle("Import")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbar }
        }
        .presentationDetents([.medium, .large])
    }

    /// Which habits get the new logs and over which days, so the user can tell it is the right file.
    /// Import cannot be undone, so this is the check before it.
    private func receiving(_ plan: ImportPlan) -> String? {
        guard let first = plan.newLogs.map(\.day).min(), let last = plan.newLogs.map(\.day).max() else { return nil }
        var names: [UUID: String] = Dictionary(habits.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        for r in plan.newHabits { names[r.id] = r.name }
        var seen = Set<UUID>()
        let ids = plan.newLogs.map(\.habit).filter { seen.insert($0).inserted }
        let shown = ids.prefix(3).compactMap { names[$0] }
        let more = ids.count - shown.count
        let list = more > 0
            ? String(localized: "\(shown.joined(separator: ", ")) and \(more) more")
            : shown.formatted(.list(type: .and))
        let words = DayWords(clock: settings.clock)
        let from = words.full(DayKey(rawValue: first)), to = words.full(DayKey(rawValue: last))
        return first == last
            ? String(localized: "Logs for \(list), on \(from).")
            : String(localized: "Logs for \(list), from \(from) to \(to).")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if case .preview(let plan) = stage, !plan.isEmpty {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        } else {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .preview(let plan) where plan.isEmpty:
            heading("Nothing new in this file")
            caption("Everything in it is already here. Nothing was changed.")
        case .preview(let plan):
            // What will change comes first, in the same rows the result shows, so the numbers match.
            heading("Importing adds")
            VStack(spacing: 0) {
                StatRow(label: String(localized: "Habits"), value: plan.newHabits.count.formatted())
                StatRow(label: String(localized: "Logs"), value: plan.newLogs.count.formatted())
                if !plan.newPauses.isEmpty {
                    StatRow(label: String(localized: "Pauses"), value: plan.newPauses.count.formatted())
                }
            }
            // Set apart, because these logs are not added.
            StatRow(label: String(localized: "Already here"), value: plan.skippedLogs.formatted())
                .padding(.top, 8)
            if let which = receiving(plan) {
                caption(which)
            }
            if plan.differing > 0 {
                caption(plan.differing == 1
                    ? String(localized: "1 habit has different details in this file. The version on this device is kept. Nothing here will be replaced.")
                    : String(localized: "\(plan.differing) habits have different details in this file. The version on this device is kept. Nothing here will be replaced."))
            }
            Button("Import") {
                guard !importing else { return }
                importing = true
                model.importStage = DataTransfer.write(plan, context: context).map(ImportStage.done).fold
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .foregroundStyle(style.paper)
            .controlSize(.large)
            .disabled(importing)
        case .done(let result):
            heading("Imported")
            VStack(spacing: 0) {
                StatRow(label: String(localized: "Habits added"), value: result.habitsAdded.formatted())
                StatRow(label: String(localized: "Logs added"), value: result.logsAdded.formatted())
                if result.pausesAdded > 0 {
                    StatRow(label: String(localized: "Pauses added"), value: result.pausesAdded.formatted())
                }
                StatRow(label: String(localized: "Already here, skipped"), value: result.skipped.formatted())
            }
            caption("Nothing was replaced. Importing the same file again adds nothing.")
        case .problem(let problem):
            switch problem {
            case .notAHabitExport:
                heading("This is not a Habit export")
                caption("Nothing was changed.")
                chooseButton
            case .newerVersion:
                heading("This file is from a newer version of Habit")
                caption("Update Habit on this device, then import again. Nothing was changed.")
            case .tooLarge:
                heading("This file is too large to import")
                caption("Nothing was changed.")
                chooseButton
            case .damaged:
                heading("This file could not be read")
                caption("Part of it is damaged. Nothing was changed.")
                chooseButton
            }
        }
    }

    private var chooseButton: some View {
        Button("Choose another file", action: chooseAnother)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .foregroundStyle(style.paper)
    }

    private func heading(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(style.display(.title2))
            .foregroundStyle(style.text)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
    }

    private func heading(_ text: String) -> some View {
        heading(LocalizedStringKey(text))
    }

    private func caption(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(style.label(.subheadline))
            .foregroundStyle(style.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(style.label(.subheadline))
            .foregroundStyle(style.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

extension Result where Success == ImportStage, Failure == ImportProblem {
    var fold: ImportStage {
        switch self {
        case .success(let stage): stage
        case .failure(let problem): .problem(problem)
        }
    }
}

/// The export screen: what the copy holds, the warning, and the button that hands it to the system.
struct ExportSheet: View {
    @Environment(Settings.self) private var settings
    @Environment(\.style) private var style
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var habits: [Habit]
    @State private var shareURL: URL?
    /// This sheet's own file, removed when the share closes.
    @State private var written: URL?
    @State private var failed = false
    #if os(macOS)
    @State private var exporting: ExportDocument?
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("A copy of your habits, logs and pauses, as one file. Settings stay on this device.")
                        .font(style.label(.body))
                        .foregroundStyle(style.text)
                    Text("This copy is not encrypted. Anyone who has it can read your habits.")
                        .font(style.label(.body, weight: .semibold))
                        .foregroundStyle(style.text)
                    if failed {
                        Text("The copy could not be made. Nothing was shared. Try again.")
                            .font(style.label(.subheadline))
                            .foregroundStyle(style.secondary)
                    }
                    Button(action: export) {
                        Text("Export a copy").frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .foregroundStyle(style.paper)
                    .controlSize(.large)
                    .disabled(habits.allSatisfy { $0.deletedAt != nil })
                }
                .padding(20)
                .frame(maxWidth: 480, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .paperBackground(style)
            .navigationTitle("Export a copy")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        #if os(iOS)
        .sheet(item: $shareURL, onDismiss: { written.map(DataTransfer.remove) }) { url in
            ShareSheet(url: url) { completed, error in
                // A finished share closes the export screen. A cancel leaves it open to try again.
                shareURL = nil
                if error { failed = true } else if completed { dismiss() }
            }
                .presentationDetents([.medium, .large])
        }
        #else
        .fileExporter(isPresented: Binding(get: { exporting != nil }, set: { if !$0 { exporting = nil } }),
                      document: exporting, contentType: .json, defaultFilename: DataTransfer.fileName(clock: settings.clock)) { result in
            // A failed save keeps the screen open with the message, so nobody believes they have a copy.
            switch result {
            case .success: dismiss()
            case .failure: failed = true
            }
        }
        #endif
    }

    private func export() {
        failed = false
        #if os(iOS)
        do {
            let url = try DataTransfer.writeTemporaryFile(context: context, clock: settings.clock)
            written = url
            shareURL = url
        } catch {
            failed = true
        }
        #else
        do {
            exporting = ExportDocument(data: try DataTransfer.exportData(context: context, clock: settings.clock))
        } catch {
            failed = true
        }
        #endif
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

#if os(iOS)
/// The system share sheet. The file is deleted when it closes.
private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    /// Whether the share finished, and whether it failed.
    var finished: (Bool, Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, error in
            DataTransfer.remove(url)
            finished(completed, error != nil)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#else
/// The export as a document for the Mac save panel. Nothing is written until the user picks a place.
struct ExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
#endif

/// Presents the file picker, then the import sheet. Attach once, at the root.
struct ImportPresenter: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        @Bindable var model = model
        content
            .fileImporter(isPresented: $model.choosingImportFile, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    model.importStage = DataTransfer.plan(for: url, context: context).map(ImportStage.preview).fold
                case .failure:
                    break
                }
            }
            .sheet(item: $model.importStage) { stage in
                ImportSheet(stage: stage) {
                    model.importStage = nil
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        model.choosingImportFile = true
                    }
                }
            }
            .sheet(isPresented: $model.showExport) {
                ExportSheet()
            }
    }
}

/// A label and a value on one line, stacking at accessibility sizes.
struct StatRow: View {
    let label: String
    let value: String
    @Environment(\.style) private var style
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        layout {
            Text(label)
                .font(style.label(.subheadline))
                .foregroundStyle(style.secondary)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 12) }
            Text(value)
                .font(style.count(.body))
                .foregroundStyle(style.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(style.rule).frame(height: style.ruleWidth)
        }
        .accessibilityElement(children: .combine)
    }
}
