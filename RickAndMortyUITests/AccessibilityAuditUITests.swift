import XCTest

final class AccessibilityAuditUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testListAccessibilityAudit() throws {
        let app = launch()
        XCTAssertTrue(characterRow("Rick Sanchez", in: app).waitForExistence(timeout: 10))
        try audit(app)
    }

    @MainActor
    func testDetailAccessibilityAudit() throws {
        let app = launch()
        let rick = characterRow("Rick Sanchez", in: app)
        XCTAssertTrue(rick.waitForExistence(timeout: 10))
        rick.tap()
        assertRickDetail(in: app)
        try audit(app)
    }

    @MainActor
    private func audit(_ app: XCUIApplication) throws {
        continueAfterFailure = true
        try app.performAccessibilityAudit { issue in
            let details = XCTAttachment(string: "\(issue.detailedDescription)\n\(String(describing: issue.element))")
            details.name = issue.compactDescription
            details.lifetime = .keepAlways
            self.add(details)
            // False leaves the issue unhandled: XCTest must still report every failure.
            return false
        }
    }
}
