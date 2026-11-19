import WidgetKit

/// Redraws the widget. Called after any save in the app, a change of day start, and an intent's log.
enum WidgetReload {
    static func now() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
