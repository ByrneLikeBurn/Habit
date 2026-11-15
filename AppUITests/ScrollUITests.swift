import XCTest

/// Scrolling Today with 30 fixture habits, each with 200 days of history.
final class ScrollUITests: XCTestCase {
    func testScrollingThirtyHabitsWithHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["-fixture", "long"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["control-Habit 1"].waitForExistence(timeout: 60))
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric], options: options) {
            app.swipeUp(velocity: .fast)
            app.swipeDown(velocity: .fast)
        }
        // A tap on day 200 still lands at once.
        let control = app.descendants(matching: .any)["control-Habit 2"]
        let before = control.value as? String ?? ""
        control.tap()
        XCTAssertNotEqual(control.value as? String ?? "", before)
    }
}
