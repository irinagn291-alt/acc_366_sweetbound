import XCTest

final class CrossingUITests: XCTestCase {
    func testTapToHopPauseResumeAndReplay() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()
        let start = app.buttons["startCrossing"]
        XCTAssertTrue(start.waitForExistence(timeout: 12))
        XCTAssertEqual(start.label, "Start crossing")
        XCTAssertEqual(app.buttons["openGuide"].label, "How to play")
        keepFrame(app, named: "Reserve")
        start.tap()

        let board = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.56))
        board.tap()
        let score = app.staticTexts["score"]
        let firstRow = NSPredicate(format: "label == %@", "001")
        expectation(for: firstRow, evaluatedWith: score)
        waitForExpectations(timeout: 6)
        keepFrame(app, named: "First crossing")
        app.buttons["pauseCrossing"].tap()
        XCTAssertEqual(app.staticTexts["panelTitle"].label, "Take a breather")
        app.buttons["primaryAction"].tap()

        // Row two is a road. Standing still guarantees a car eventually reaches us.
        board.tap()
        XCTAssertTrue(app.buttons["primaryAction"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["panelTitle"].label, "Hit by a car!")
        app.buttons["primaryAction"].tap()
        XCTAssertEqual(score.label, "000")
        app.buttons["pauseCrossing"].tap()
        app.buttons["leaveCrossing"].tap()
        XCTAssertTrue(start.exists)
    }

    func testGuideTrainingAndJournal() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()
        app.buttons["openGuide"].tap()
        XCTAssertTrue(app.buttons["startPractice"].waitForExistence(timeout: 8))
        app.buttons["startPractice"].tap()
        XCTAssertEqual(app.staticTexts["practiceTitle"].label, "Your first hop")
        app.buttons["forward"].tap()
        let secondStep = NSPredicate(format: "label == %@", "Across the road")
        expectation(for: secondStep, evaluatedWith: app.staticTexts["practiceTitle"])
        waitForExpectations(timeout: 6)
        app.buttons["pauseCrossing"].tap()
        app.buttons["leaveCrossing"].tap()
        app.buttons["openJournal"].tap()
        XCTAssertTrue(app.buttons["journalTab"].isSelected)
        keepFrame(app, named: "Field journal")
        app.buttons["guideTab"].tap()
        XCTAssertTrue(app.buttons["startPractice"].exists)
        app.buttons["notebookClose"].tap()
        XCTAssertTrue(app.buttons["startCrossing"].waitForExistence(timeout: 6))
    }

    func testDailySurveySignAndReplay() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()
        app.buttons["dailyCrossing"].tap()
        let count = app.staticTexts["surveyCount"]
        XCTAssertTrue(count.label.contains("0 OF 3"))
        app.buttons["forward"].tap()
        let firstFind = NSPredicate(format: "label CONTAINS %@", "1 OF 3")
        expectation(for: firstFind, evaluatedWith: count)
        waitForExpectations(timeout: 6)
        keepFrame(app, named: "Daily field survey")
        app.buttons["forward"].tap()
        let retry = app.buttons["primaryAction"]
        XCTAssertTrue(retry.waitForExistence(timeout: 20))
        retry.tap()
        XCTAssertTrue(count.label.contains("0 OF 3"))
        app.terminate()
        app.launch()
        app.buttons["openJournal"].tap()
        let feather = app.descendants(matching: .any)["fieldFind0"].firstMatch
        if !feather.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(feather.exists)
    }

    func testPrivacyPolicyIsReadableOffline() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()
        app.buttons["aboutGame"].tap()
        app.buttons["aboutPrivacy"].tap()
        let policy = app.staticTexts["aboutPrivacyText"]
        XCTAssertTrue(policy.waitForExistence(timeout: 8))
        XCTAssertTrue(policy.label.hasPrefix("Mossbound Privacy Policy"))
        XCTAssertTrue(app.buttons["aboutClose"].label == "Close")
        keepFrame(app, named: "English privacy policy")
    }

    private func keepFrame(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
