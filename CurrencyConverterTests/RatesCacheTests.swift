//
//  RatesCacheTests.swift
//  CurrencyConverterTests
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation
import Testing
@testable import CurrencyConverter

/// The snapshot store, pointed at a throwaway temp directory.
struct RatesCacheTests {

    private let directory: URL
    private let cache: RatesCache

    init() {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "RatesCacheTests-\(UUID().uuidString)")
        cache = RatesCache(directory: directory)
    }

    private func makeSnapshot() throws -> RatesSnapshot {
        RatesSnapshot(
            base: "USD",
            rates: try Mocks.latestRates(),
            currencyNames: try Mocks.currencyNames(),
            apiTimestamp: Date(timeIntervalSince1970: 1_753_948_800),
            fetchedAt: Date(timeIntervalSince1970: 1_753_950_000)
        )
    }

    @Test func testSaveAndLoadRoundTrip() throws {
        let snapshot = try makeSnapshot()

        cache.save(snapshot)

        #expect(cache.load() == snapshot)
    }

    @Test func testLoadWithNoFileReturnsNil() {
        #expect(cache.load() == nil)
    }

    @Test func testCorruptFileIsTreatedAsMiss() throws {
        try writeGarbage("{ definitely not a snapshot")

        #expect(cache.load() == nil)
    }

    private func writeGarbage(_ contents: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: directory.appending(path: "rates-snapshot.json"))
    }
}
