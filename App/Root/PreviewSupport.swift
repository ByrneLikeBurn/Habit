import SwiftUI
import HabitKit

extension View {
    /// Fixture store, frozen clock and style for SwiftUI previews.
    @MainActor
    func previewEnvironment(_ fixture: LaunchOptions.Fixture = .today, appearance: AppearanceChoice = .paper, controlsLeading: Bool = false) -> some View {
        let settings = Settings(defaults: UserDefaults(suiteName: "dev.byrnelikeburn.Habit.preview") ?? .standard)
        settings.appearance = appearance
        settings.accent = .default
        settings.controlsLeading = controlsLeading
        settings.dayStartHour = HabitClock.defaultDayStartHour
        settings.clockOverride = Fixtures.previewClock
        return StyledScreen { self }
            .modelContainer(Fixtures.previewContainer(fixture))
            .environment(settings)
            .environment(AppModel())
            .preferredColorScheme(settings.preferredColorScheme)
    }
}
