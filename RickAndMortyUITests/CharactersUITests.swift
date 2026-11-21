import XCTest

final class CharactersUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSearchAndDirectCharacterNavigation() {
        let app = launch()
        XCTAssertTrue(characterRow("Morty Smith", in: app).waitForExistence(timeout: 10))
        search("rick", in: app)
        let mortyDisappeared = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: characterRow("Morty Smith", in: app)
        )
        XCTAssertEqual(XCTWaiter.wait(for: [mortyDisappeared], timeout: 10), .completed)
        let rick = characterRow("Rick Sanchez", in: app)
        XCTAssertTrue(rick.waitForExistence(timeout: 10))
        rick.tap()
        assertRickDetail(in: app)
        app.navigationBars["Character"].buttons.firstMatch.tap()
        XCTAssertTrue(characterRow("Rick Sanchez", in: app).waitForExistence(timeout: 10))
        XCTAssertEqual(app.searchFields.firstMatch.value as? String, "rick")
        XCTAssertFalse(characterRow("Morty Smith", in: app).exists)
    }

    @MainActor
    func testSearchWithNoMatchesShowsEmptyState() {
        let app = launch()
        XCTAssertTrue(characterRow("Rick Sanchez", in: app).waitForExistence(timeout: 10))
        search("no-matching-character", in: app)
        XCTAssertTrue(app.staticTexts["No characters found"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Unable to load characters"].exists)
        XCTAssertFalse(app.buttons["Retry loading characters"].exists)
    }

    @MainActor
    func testInitialConnectionErrorCanBeRetried() {
        let app = launch(scenario: "initial-error")
        XCTAssertTrue(app.staticTexts["Check your internet connection and try again."].waitForExistence(timeout: 10))
        let retry = app.buttons["Retry loading characters"]
        XCTAssertTrue(retry.exists)
        retry.tap()
        XCTAssertTrue(characterRow("Rick Sanchez", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Unable to load characters"].exists)
    }

    @MainActor
    private func search(_ query: String, in app: XCUIApplication) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText(query + "\n")
    }
}
