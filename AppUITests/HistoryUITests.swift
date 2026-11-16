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
        // Undo leaves no line behind: neither the old one, a new "Cleared" one, nor an Undo button.
        let gone = NSPredicate(format: "exists == false")
        let cleared = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Cleared '")).firstMatch
        for element in [line, app.buttons["Undo"]] {
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: gone, evaluatedWith: element)], timeout: 3), .completed)
        }
        XCTAssertFalse(cleared.exists)
    }

    func testAddAPastDayOpensTheDaySheetFromTheBottomButton() {
        let app = launch(["-screen", "detailMonth"])
        let add = app.buttons["Add a past day"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let open = app.buttons["Open this day"]
        XCTAssertTrue(open.waitForExistence(timeout: 3))
        open.tap()
        // The picker defaults to yesterday, Friday 13 November. The day sheet follows with no timer.
        XCTAssertTrue(app.staticTexts["Friday 13 November"].waitForExistence(timeout: 3))
    }

    func testBackFromDetailOpenedInHistoryReadsHistory() {
        let app = launch(["-screen", "history"])
        // The row is one element. Its name sits at the top, above the day cells.
        let row = app.buttons["Drink water"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.15)).tap()
        XCTAssertTrue(app.staticTexts["Days logged"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.navigationBars.buttons["History"].exists)
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
