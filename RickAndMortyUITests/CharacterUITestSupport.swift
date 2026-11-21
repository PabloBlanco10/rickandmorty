import XCTest

@MainActor
extension XCTestCase {
    func launch(scenario: String = "normal") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launchEnvironment["UITEST_SCENARIO"] = scenario
        app.launch()
        addTeardownBlock {
            await MainActor.run { XCUIApplication().terminate() }
        }
        return app
    }

    func characterRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    func assertRickDetail(in app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Character"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Rick Sanchez"].exists)
        for (label, value) in [
            ("Status", "Alive"), ("Species", "Human"), ("Gender", "Male"),
            ("Origin", "Earth (C-137)"), ("Location", "Citadel of Ricks")
        ] {
            let field = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", label, value)
            ).firstMatch
            XCTAssertTrue(field.exists, "Missing detail field: \(label), \(value)")
        }
    }
}
