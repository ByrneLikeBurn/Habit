import AppIntents
import Foundation
import SwiftData
import HabitKit

/// The one write path. Every LogEvent is written here: in-app taps, the count sheet, Shortcuts,
/// Siri, and later the widget, Control Centre, the Action button, NFC and the Watch.
struct LogHabitIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a habit"
    static let description = IntentDescription("Logs a habit for today. Leave the amount empty to log one tap.")
    static let openAppWhenRun = false

    @Parameter(title: "Habit")
    var habit: HabitEntity

    @Parameter(title: "Amount", description: "Leave empty to log one tap.", inclusiveRange: (1, 1_000_000))
    var amount: Int?

    @Parameter(title: "Take away", description: "Take the amount away instead of adding it.", default: false)
    var takeAway: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$habit)") {
            \.$amount
            \.$takeAway
        }
    }

    /// Set by the app for in-app calls. Shortcuts and Siri leave it empty and use the parameters.
    var action: LogAction?
    var source: LogSource = .shortcut
    var day: DayKey?

    init() {}

    init(habitID: UUID, name: String, action: LogAction, source: LogSource = .manual, day: DayKey? = nil) {
        self.habit = HabitEntity(id: habitID, name: name)
        self.action = action
        self.source = source
        self.day = day
    }

    private var resolvedAction: LogAction {
        if let action { return action }
        guard let amount else { return .tap }
        return takeAway ? .takeAway(amount) : .add(amount)
    }

    /// Writes the log. `context` is passed by the app and by fixtures; otherwise the shared store is used.
    @MainActor
    @discardableResult
    func execute(in context: ModelContext? = nil, clock: HabitClock? = nil) throws -> (outcome: LogOutcome, habit: Habit) {
        let context = try context ?? SharedStore.container.get().mainContext
        let id = habit.id
        var fetch = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == id })
        fetch.fetchLimit = 1
        guard let model = try context.fetch(fetch).first, model.deletedAt == nil else {
            throw LogError.habitNotFound
        }
        let clock = clock ?? Settings().clock
        let outcome = try LogWriter.log(
            resolvedAction,
            habit: model,
            day: day ?? clock.today,
            source: source,
            deviceID: SharedStore.deviceID,
            now: clock.now(),
            in: context
        )
        return (outcome, model)
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let (outcome, model) = try execute()
        let line: String
        switch outcome {
        case .wrote(_, let total), .unchanged(let total):
            if model.kind == .counted {
                line = CountText.line(total: total, target: model.rule(on: Settings().clock.today).target, unit: model.unit)
            } else {
                line = total > 0 ? String(localized: "Logged.") : String(localized: "Taken back.")
            }
        case .needsAmount:
            line = String(localized: "Add an amount to log \(model.name).")
        }
        // Archived habits still log, so a shortcut or tag never stops working.
        let note = model.isArchived ? " " + String(localized: "It is archived. You can bring it back in You.") : ""
        return .result(dialog: IntentDialog(stringLiteral: "\(model.name): \(line)\(note)"))
    }
}

enum LogError: Error, CustomLocalizedStringResourceConvertible {
    case habitNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .habitNotFound: "That habit is not in Habit any more."
        }
    }
}
