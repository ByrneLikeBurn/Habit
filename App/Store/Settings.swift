import SwiftUI
import HabitKit

/// The user's settings, read and written through the shared defaults.
/// Unknown stored values fall back to Pen and ink, System and Blue.
@MainActor
@Observable
final class Settings {
    private let defaults: UserDefaults

    var style: StyleID { didSet { defaults.set(style.rawValue, forKey: SettingKey.style) } }
    var appearance: AppearanceChoice { didSet { defaults.set(appearance.rawValue, forKey: SettingKey.appearance) } }
    var accent: Swatch { didSet { defaults.set(accent.rawValue, forKey: SettingKey.accent) } }
    var controlsLeading: Bool { didSet { defaults.set(controlsLeading, forKey: SettingKey.controlsLeading) } }
    var dayStartHour: Int { didSet { defaults.set(dayStartHour, forKey: SettingKey.dayStartHour); WidgetReload.now() } }
    /// Adds Current run and Longest run to Habit detail. Off by default.
    var showRuns: Bool { didSet { defaults.set(showRuns, forKey: SettingKey.showRuns) } }
    /// Draws an empty outline for a past scheduled day with no log. Off by default.
    var showDaysNotLogged: Bool { didSet { defaults.set(showDaysNotLogged, forKey: SettingKey.showDaysNotLogged) } }

    init(defaults: UserDefaults = SharedStore.defaults) {
        self.defaults = defaults
        style = StyleID.resolve(defaults.string(forKey: SettingKey.style))
        appearance = LaunchOptions.current.appearance ?? AppearanceChoice.resolve(defaults.string(forKey: SettingKey.appearance))
        accent = Swatch.resolve(defaults.string(forKey: SettingKey.accent))
        controlsLeading = defaults.bool(forKey: SettingKey.controlsLeading)
        showRuns = defaults.bool(forKey: SettingKey.showRuns)
        showDaysNotLogged = defaults.bool(forKey: SettingKey.showDaysNotLogged)
        #if DEBUG
        // Screenshot flags. Release builds read only the stored settings.
        if LaunchOptions.current.showRuns { showRuns = true }
        if LaunchOptions.current.showDaysNotLogged { showDaysNotLogged = true }
        #endif
        let stored = defaults.object(forKey: SettingKey.dayStartHour) as? Int
        dayStartHour = stored.map { min(max($0, HabitClock.dayStartRange.lowerBound), HabitClock.dayStartRange.upperBound) }
            ?? HabitClock.defaultDayStartHour
    }

    /// Set by previews to freeze the clock.
    var clockOverride: HabitClock?

    /// The clock for this run. Screenshots and previews freeze it.
    var clock: HabitClock {
        let base = clockOverride ?? LaunchOptions.current.clock ?? HabitClock()
        return HabitClock(now: base.now, calendar: base.calendar, dayStartHour: dayStartHour)
    }

    func resolvedStyle(colorScheme: ColorScheme, increaseContrast: Bool) -> ResolvedStyle {
        let appearance: Appearance = switch self.appearance {
        case .system: colorScheme == .dark ? .ink : .paper
        case .paper: .paper
        case .ink: .ink
        }
        return ResolvedStyle(tokens: style.tokens, appearance: appearance, accent: accent, increaseContrast: increaseContrast)
    }

    /// Paper and Ink set the colour scheme, so system chrome matches the page.
    var preferredColorScheme: ColorScheme? {
        switch appearance {
        case .system: nil
        case .paper: .light
        case .ink: .dark
        }
    }
}
