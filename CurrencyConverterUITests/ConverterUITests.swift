//
//  CurrencyConverterUITests.swift
//  CurrencyConverterUITests
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import XCTest

final class CurrencyConverterUITests: XCTestCase {
    
    // mirror of AccessibilityID in the app target (UI test bundles can't
    // import the app module) - keep in sync by hand
    private enum ID {
        static let amountField = "amountField"
        static let currencyChip = "currencyChip"
        static let filterField = "filterField"
        static func row(_ code: String) -> String { "row_\(code)" }
        static func pickerRow(_ code: String) -> String { "pickerRow_\(code)" }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        return app
    }

    func testConvertingAnAmount() {
        let app = launchApp()

        let amountField = app.textFields[ID.amountField]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("100")

        app.buttons[ID.currencyChip].tap()
        let eurRow = app.buttons[ID.pickerRow("EUR")]
        XCTAssertTrue(eurRow.waitForExistence(timeout: 5))
        eurRow.tap()

        // 100 EUR through USD: 100 / 0.9203 = $108.66
        let usdRow = app.otherElements[ID.row("USD")]
        XCTAssertTrue(usdRow.waitForExistence(timeout: 5))
        XCTAssertTrue(usdRow.label.contains("108.66"), "unexpected row label: \(usdRow.label)")
    }

    func testFilteringTheList() {
        let app = launchApp()

        let filter = app.textFields[ID.filterField]
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        filter.tap()
        filter.typeText("euro")

        XCTAssertTrue(app.otherElements[ID.row("EUR")].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements[ID.row("JPY")].exists)
    }

    /// Regression test: the Done button used to be bound to the amount
    /// field's own focus, so it did nothing while the filter was focused.
    func testDoneDismissesTheKeyboard() {
        let app = launchApp()

        let filter = app.textFields[ID.filterField]
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        filter.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        app.buttons["Done"].tap()
        XCTAssertEqual(app.keyboards.count, 0)
    }
}
