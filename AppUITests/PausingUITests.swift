import XCTest

/// Pausing from Today and from Edit. The rules themselves are tested in HabitKit.
@MainActor
final class PausingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-fixture", "today"]
        app.launch()
    }

    /// Pause everything acts at once, says so at the top, and the line there offers Undo pause.
    func testPauseEverythingFromTodayAndUndoIt() {
        let pause = app.buttons["pause-everything"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        while !pause.isHittable { app.swipeUp() }
        pause.tap()
        // The bottom button goes, so Undo pause is never shown twice.
        XCTAssertFalse(app.buttons["pause-everything"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Everything is paused.")).firstMatch.waitForExistence(timeout: 2))
        let line = app.buttons["pause-line-button"]
        while !line.isHittable { app.swipeDown() }
        XCTAssertEqual(line.label, "Undo pause")
        line.tap()
        XCTAssertFalse(app.buttons["pause-line-button"].waitForExistence(timeout: 1))
        // Logging still works after the pause is gone.
        XCTAssertTrue(app.descendants(matching: .any)["control-Read"].exists)
    }

    /// A slip on Pause everything is one tap from undone: the Undo line shows where the tap was.
    func testPauseEverythingSlipIsUndoneFromTheLine() {
        let pause = app.buttons["pause-everything"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        while !pause.isHittable { app.swipeUp() }
        pause.tap()
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        undo.tap()
        XCTAssertFalse(app.buttons["pause-line-button"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.buttons["pause-everything"].waitForExistence(timeout: 2))
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
