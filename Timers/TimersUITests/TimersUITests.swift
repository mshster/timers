// TimersUITests/TimersUITests.swift
import XCTest

final class TimersUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    // MARK: - Ad Hoc Timer

    func test_adHocTimer_startAndAppearInActiveSection() throws {
        // Tap the timer (⏱) button in the nav bar
        app.navigationBars["Timers"].buttons["timer"].tap()

        // The ad hoc sheet should appear
        XCTAssertTrue(app.navigationBars["Quick Timer"].waitForExistence(timeout: 2))

        // Tap Start
        app.navigationBars["Quick Timer"].buttons["Start"].tap()

        // Sheet should dismiss and an instance row appear
        XCTAssertFalse(app.navigationBars["Quick Timer"].exists)

        // An instance row should appear (the default 1-min countdown)
        XCTAssertTrue(app.staticTexts["Active"].waitForExistence(timeout: 2))
    }

    // MARK: - Saved Timer From Group

    func test_savedTimer_tapProfileStartsInstance() throws {
        // First, create a profile via the + button
        app.navigationBars["Timers"].buttons["plus"].tap()
        XCTAssertTrue(app.navigationBars["New Timer"].waitForExistence(timeout: 2))

        let nameField = app.textFields["Timer name"]
        nameField.tap()
        nameField.typeText("Earl Grey")

        app.navigationBars["New Timer"].buttons["Save"].tap()
        XCTAssertFalse(app.navigationBars["New Timer"].exists)

        // Tap the saved profile row to start it
        app.staticTexts["Earl Grey"].tap()

        // An "Active" section should appear
        XCTAssertTrue(app.staticTexts["Active"].waitForExistence(timeout: 2))
    }
}
