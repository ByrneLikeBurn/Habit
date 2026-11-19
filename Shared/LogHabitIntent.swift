import AppIntents
import Foundation
import SwiftData
import HabitKit

/// The one write path. Every LogEvent is written here: in-app taps, the count sheet, Shortcuts,
/// Siri, and later the widget, Control Centre, the Action button, NFC and the Watch.
struct LogHabitIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a habit"
    static let description = IntentDescription("Logs a habit for today. Leave the amount empty to log one tap.")
    static let supportedModes: IntentModes = .background
    /// Habit names can be health details. Siri and Shortcuts never read or log them on a locked device.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

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

    /// In-app calls pass their action. A shortcut means "log": running it twice never takes a log back.
    private func resolvedAction(for habit: Habit) -> LogAction {
        action ?? .external(amount: amount, takeAway: takeAway, kind: habit.kind, tapAmount: habit.tapAmount)
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
        let clock = clock ?? SharedStore.clock
        let outcome = try LogWriter.log(
            resolvedAction(for: model),
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
        WidgetReload.now()
        let line: String
        switch outcome {
        case .wrote(_, let total), .unchanged(let total):
            if model.kind == .counted {
                line = CountText.line(total: total, target: model.rule(on: SharedStore.clock.today).target, unit: model.unit)
            } else if case .unchanged = outcome, total > 0 {
                line = String(localized: "Already logged today.")
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
        case .habitNotFound: LocalizedStringResource("That habit is not in Habit any more.", comment: "Shortcuts and Siri. The second \"Habit\" is the app's name. Do not translate it.")
        }
    }
}
