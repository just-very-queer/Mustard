//
//  MustardUITests.swift
//  MustardUITests
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import XCTest

final class MustardUITests: XCTestCase {

    override func setUpWithError() throws {
        // Stop immediately when a failure occurs.
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Teardown code if needed.
    }

    /// Tests the launch of the application.
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify that the welcome text exists.
        XCTAssertTrue(app.staticTexts["Welcome to Mustard"].exists)
    }

    /// Tests adding a new account.
    func testAddingNewAccount() throws {
        let app = XCUIApplication()
        app.launch()

        // Navigate to Accounts Tab
        app.tabBars.buttons["Accounts"].tap()

        // Tap Add Account Button
        app.navigationBars["Accounts"].buttons["plus"].tap()

        // Enter Instance URL
        let instanceURLField = app.textFields["Enter Mastodon Instance URL (e.g., https://mastodon.social)"]
        instanceURLField.tap()
        instanceURLField.typeText("https://mastodon.social")

        // Tap Add Button
        app.buttons["Add"].tap()

        // Verify Account is Added
        // Assuming the account display name appears in the list
        XCTAssertTrue(app.staticTexts["Mastodon Social"].exists)
    }

    /// Tests authenticating with an instance.
    func testAuthenticationFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Enter Instance URL
        let instanceURLField = app.textFields["Enter Mastodon Instance URL (e.g., https://mastodon.social)"]
        instanceURLField.tap()
        instanceURLField.typeText("https://mastodon.social")

        // Tap Authenticate Button
        app.buttons["Authenticate"].tap()

        // Since authentication involves external web interactions, UI tests might need to mock this or skip.
        // Alternatively, verify that the authentication sheet appears.
        // For example:
        XCTAssertTrue(app.otherElements["ASWebAuthenticationSession"].exists)
    }
}

