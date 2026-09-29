//
//  CurrencyFormatCacheTests.swift
//  CurrencyConverterTests
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation
import Testing
@testable import CurrencyConverter

/// Per-currency fraction digits. Pinned to en_US so the separator
/// assertions hold.
@MainActor
struct CurrencyFormatCacheTests {

    private let cache = CurrencyFormatCache(locale: Locale(identifier: "en_US"))

    @Test func testJPYHasNoFractionDigits() {
        let formatted = cache.string(for: 1234.567, code: "JPY")
        #expect(!formatted.contains("."))
        #expect(formatted.contains("1,235")) // rounded, grouped
    }

    @Test func testKWDHasThreeFractionDigits() {
        let formatted = cache.string(for: 1.5, code: "KWD")
        #expect(formatted.contains("1.500"))
    }
}
