import XCTest

/// Milestone 2 flows on the fixture store with a frozen clock (Saturday 14 November 2026).
final class HistoryUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-fixture", "today"] + arguments
        app.launch()
        return app
    }

    func testDetailsFromATodayRowOpensHabitDetail() {
        let app = launch([])
        let read = app.descendants(matching: .any)["control-Read"]
        XCTAssertTrue(read.waitForExistence(timeout: 5))
        read.swipeLeft()
        app.buttons["Details"].tap()
        XCTAssertTrue(app.staticTexts["Since 28 April 2026"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Days logged"].exists)
    }

    func testAPastDayIsLoggedFromTheDaySheetWithUndo() {
        let app = launch(["-screen", "day"])
        let markDone = app.buttons["Mark done"]
        XCTAssertTrue(markDone.waitForExistence(timeout: 5))
        markDone.tap()
        let line = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Logged '")).firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 3))
        app.buttons["Undo"].tap()
        XCTAssertFalse(line.waitForExistence(timeout: 1))
    }

    func testHistoryShowsEveryHabitAndArchivedOnlyWithALog() {
        let app = launch(["-screen", "history"])
        XCTAssertTrue(app.staticTexts["History"].waitForExistence(timeout: 5))
        // Water the plants is archived and has a log this week. It sits at the end, under Archived.
        app.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["Water the plants"].waitForExistence(timeout: 3))
        app.swipeDown()
        app.buttons["Month"].tap()
        XCTAssertTrue(app.buttons["November 2026"].waitForExistence(timeout: 3))
    }
}
