import XCTest

/// Pausing from Today and from Edit. The rules themselves are tested in HabitKit.
final class PausingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-fixture", "today"]
        app.launch()
    }

    /// Pause everything acts at once, says so at the top, and the same place offers Undo pause.
    func testPauseEverythingFromTodayAndUndoIt() {
        let pause = app.buttons["pause-everything"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        while !pause.isHittable { app.swipeUp() }
        pause.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Everything is paused.")).firstMatch.waitForExistence(timeout: 2))
        let line = app.buttons["pause-line-button"]
        while !line.isHittable { app.swipeDown() }
        XCTAssertEqual(line.label, "Undo pause")
        line.tap()
        XCTAssertFalse(app.buttons["pause-line-button"].waitForExistence(timeout: 1))
        // Logging still works after the pause is gone.
        XCTAssertTrue(app.descendants(matching: .any)["control-Read"].exists)
    }

    /// Pause this habit in Edit acts at once. The row says Paused, and the habit can still be logged.
    func testPauseOneHabitFromEdit() {
        let name = app.descendants(matching: .any)["name-Walk outside"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.press(forDuration: 1)
        app.buttons["Edit"].tap()
        let pause = app.buttons["Pause this habit"]
        while !pause.isHittable { app.swipeUp() }
        pause.tap()
        XCTAssertTrue(app.buttons["Undo pause"].waitForExistence(timeout: 2))
        app.buttons["Save"].tap()
        let control = app.descendants(matching: .any)["control-Walk outside"]
        XCTAssertTrue(control.waitForExistence(timeout: 2))
        XCTAssertTrue((control.value as? String ?? "").contains("Paused"), control.value as? String ?? "")
    }
}
