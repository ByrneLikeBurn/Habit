import XCTest

/// Drives the real app on the fixture store with a frozen clock.
final class TodayUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-fixture", "today"]
        app.launch()
    }

    private func control(_ name: String) -> XCUIElement {
        app.descendants(matching: .any)["control-\(name)"]
    }

    func testYesOrNoTapLogsAndASecondTapTakesBackWithUndo() {
        let walk = control("Walk outside")
        XCTAssertTrue(walk.waitForExistence(timeout: 5))
        XCTAssertEqual(walk.value as? String ?? "", "")
        walk.tap()
        XCTAssertEqual(walk.value as? String, "Done")
        walk.tap()
        XCTAssertEqual(walk.value as? String ?? "", "")
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Walk outside cleared"].exists)
        undo.tap()
        XCTAssertEqual(walk.value as? String, "Done")
    }

    func testCountedTapOnlyAdds() {
        let water = control("Drink water")
        XCTAssertTrue(water.waitForExistence(timeout: 5))
        XCTAssertTrue((water.value as? String ?? "").hasPrefix("3 of 8 glasses"))
        water.tap()
        XCTAssertTrue((water.value as? String ?? "").hasPrefix("4 of 8 glasses"))
        for _ in 0..<5 { water.tap() }
        XCTAssertEqual(water.value as? String, "9 of 8 glasses, Done")
    }

    func testCountSheetAddsATypedAmountAndTakeAwayStopsAtZero() {
        let line = app.descendants(matching: .any)["count-Drink water"]
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        line.tap()
        let field = app.textFields["Amount to add or take away"]
        XCTAssertTrue(field.waitForExistence(timeout: 2))
        // The amount starts selected, so typing replaces it.
        sleep(1)
        app.typeText("12")
        app.buttons["Add"].tap()
        let afterAdd = control("Drink water").value as? String ?? ""
        XCTAssertTrue(afterAdd.hasPrefix("15 of 8 glasses"), afterAdd)

        line.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 2))
        sleep(1)
        app.typeText("100")
        app.buttons["Take away"].tap()
        XCTAssertTrue((control("Drink water").value as? String ?? "").hasPrefix("0 of 8 glasses"))
    }

    func testNewHabitNeedsOnlyAName() {
        app.buttons["New habit"].tap()
        let add = app.buttons["Add"]
        XCTAssertTrue(add.waitForExistence(timeout: 2))
        XCTAssertFalse(add.isEnabled)
        XCTAssertTrue(app.staticTexts["Add a name to continue."].exists)
        sleep(1)
        app.typeText("Floss")
        XCTAssertTrue(add.isEnabled)
        add.tap()
        XCTAssertTrue(control("Floss").waitForExistence(timeout: 2))
    }

    func testATapOnTheNameLogs() {
        let walk = control("Walk outside")
        XCTAssertTrue(walk.waitForExistence(timeout: 5))
        XCTAssertEqual(walk.value as? String ?? "", "")
        app.descendants(matching: .any)["name-Walk outside"].tap()
        XCTAssertEqual(walk.value as? String, "Done")
    }

    func testSwipeReachesEdit() {
        let read = control("Read")
        XCTAssertTrue(read.waitForExistence(timeout: 5))
        read.swipeLeft()
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 2))
    }

    func testArchiveShowsUndoAndBringsTheHabitBack() {
        let read = control("Read")
        XCTAssertTrue(read.waitForExistence(timeout: 5))
        read.swipeLeft()
        app.buttons["Archive"].tap()
        XCTAssertFalse(control("Read").waitForExistence(timeout: 1))
        app.buttons["Undo"].tap()
        XCTAssertTrue(control("Read").waitForExistence(timeout: 2))
    }
}
