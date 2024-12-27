//
//  MustardUITestsLaunchTests.swift
//  MustardUITests
//
//  Created by VAIBHAV SRIVASTAVA on 14/09/24.
//

import XCTest

final class MustardUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        // Continue after failure is set to false.
        continueAfterFailure = false
    }

    /// Tests the launch performance of the application.
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    /// Tests the launch screen appearance.
    func testLaunchScreen() throws {
        let app = XCUIApplication()
        app.launch()

        // Capture a screenshot of the launch screen.
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

