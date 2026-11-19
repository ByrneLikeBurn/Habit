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

    /// While a pause's Undo line shows, it is the one undo: the pause line's button waits.
    func testPauseEverythingHasOneUndo() {
        let pause = app.buttons["pause-everything"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        while !pause.isHittable { app.swipeUp() }
        pause.tap()
        // The bottom button goes, and the pause line shows no second undo while the line is up.
        XCTAssertFalse(app.buttons["pause-everything"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["pause-line-button"].exists)
    }

    /// "Undo pause" on a pause made earlier today removes it, and that can be undone, so a planned
    /// pause is never lost to one tap.
    func testUndoPauseOnAnEarlierPauseCanBeUndone() {
        app.terminate()
        app.launchArguments = ["-fixture", "paused-today"]
        app.launch()
        let line = app.buttons["pause-line-button"]
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        XCTAssertEqual(line.label, "Undo pause")
        line.tap()
        XCTAssertFalse(app.buttons["pause-line-button"].waitForExistence(timeout: 1))
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        undo.tap()
        XCTAssertTrue(app.buttons["pause-line-button"].waitForExistence(timeout: 2))
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
