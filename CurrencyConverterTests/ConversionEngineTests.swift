//
//  ConversionEngineTests.swift
//  CurrencyConverterTests
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation
import Testing
@testable import CurrencyConverter

/// Conversion math against the mock rates.
struct ConversionEngineTests {

    private let engine = ConversionEngine()
    private let rates: [String: Double]

    init() throws {
        rates = try Mocks.latestRates()
    }

    // relative comparison, so huge and tiny amounts get the same tolerance
    private func approximatelyEqual(_ lhs: Double?, _ rhs: Double, tolerance: Double = 1e-9) -> Bool {
        guard let lhs else { return false }
        return abs(lhs - rhs) <= tolerance * max(1, abs(rhs))
    }

    @Test func testSameCurrencyReturnsTheInput() {
        #expect(engine.convert(amount: 123.45, from: "EUR", to: "EUR", rates: rates) == 123.45)
    }

    @Test func testUSDToJPY() {
        let converted = engine.convert(amount: 100, from: "USD", to: "JPY", rates: rates)
        #expect(approximatelyEqual(converted, 100 * 149.37))
    }

    @Test func testCrossRateGoesThroughUSD() {
        let converted = engine.convert(amount: 100, from: "EUR", to: "JPY", rates: rates)
        #expect(approximatelyEqual(converted, 100 * 149.37 / 0.9203))
    }

    @Test func testZeroAmountGivesZeroEverywhere() throws {
        let rows = try engine.convertAll(amount: 0, base: "EUR", rates: rates)
        #expect(!rows.isEmpty)
        #expect(rows.allSatisfy { $0.value == 0 })
    }

    @Test func testBrokenRatesAreOmitted() throws {
        let dirty: [String: Double] = [
            "USD": 1.0,
            "EUR": 0.9,
            "ZRO": 0,
            "NEG": -2.5,
            "NAN": .nan,
            "INF": .infinity,
        ]
        let rows = try engine.convertAll(amount: 10, base: "USD", rates: dirty)
        #expect(rows.map(\.code) == ["EUR", "USD"])
    }

    @Test func testMissingTargetRateReturnsNil() {
        #expect(engine.convert(amount: 10, from: "USD", to: "ZZZ", rates: rates) == nil)
    }

    @Test func testMissingBaseRateThrows() {
        #expect(throws: NetworkError.conversionUnavailable) {
            try engine.convertAll(amount: 10, base: "ZZZ", rates: rates)
        }
    }

    @Test func testHugeAmountStaysFinite() throws {
        let rows = try engine.convertAll(amount: 1e12, base: "USD", rates: rates)
        #expect(rows.allSatisfy { $0.value.isFinite })
    }

    @Test func testRoundTripSurvivesWithinEpsilon() {
        let there = engine.convert(amount: 250, from: "EUR", to: "INR", rates: rates)
        let back = there.flatMap { engine.convert(amount: $0, from: "INR", to: "EUR", rates: rates) }
        #expect(approximatelyEqual(back, 250))
    }
}
