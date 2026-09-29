//
//  AmountSanitizerTests.swift
//  CurrencyConverterTests
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation
import Testing
@testable import CurrencyConverter

/// Parsing and sanitizing edge cases, across locales.
struct AmountSanitizerTests {

    private let enUS = AmountSanitizer(locale: Locale(identifier: "en_US"))
    private let deDE = AmountSanitizer(locale: Locale(identifier: "de_DE"))

    @Test func testGermanCommaDecimal() {
        #expect(deDE.parse("1,5") == 1.5)
    }

    @Test func testUSPeriodDecimal() {
        #expect(enUS.parse("1.5") == 1.5)
    }

    @Test(arguments: [
        ("  123  ", "123"),          // whitespace trimmed
        ("12abc3", "123"),           // letters dropped
        ("-45.6", "45.6"),           // minus dropped
        ("$1,234.56", "1234.56"),    // symbol + grouping dropped
        ("1.2.3", "1.23"),           // first separator wins
        ("007", "7"),                // leading zeros
        ("000", "0"),
        ("0.5", "0.5"),
        ("💰12🎉34", "1234"),        // emoji dropped
        ("١٢٣", ""),                 // non-ASCII digits dropped, not parsed wrong
    ])
    func testSanitizingMessyInput(input: String, expected: String) {
        #expect(enUS.sanitize(input) == expected)
    }

    @Test func testLoneSeparatorIsZero() {
        #expect(enUS.parse(".") == 0)
        #expect(deDE.parse(",") == 0)
    }

    @Test func testIntegerDigitsAreCapped() {
        let input = String(repeating: "9", count: 40)
        #expect(enUS.sanitize(input) == String(repeating: "9", count: 12))
    }

    @Test func testFractionDigitsAreCapped() {
        #expect(enUS.sanitize("1.123456789") == "1.123456")
    }

    @Test func testEmptyInputParsesToNil() {
        #expect(enUS.parse("") == nil)
        #expect(enUS.parse("abc") == nil)
    }
}
