//
//  RatesRepositoryTests.swift
//  CurrencyConverterTests
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation
import Testing
@testable import CurrencyConverter

/// Throttle, stale fallback, and dedupe, on a fake clock. The only sleeps
/// are in the tests where concurrency itself is the thing being tested.
struct RatesRepositoryTests {

    private let network = MockNetworkClient()
    private let cache: MockRatesCache
    private let clock = MockClock()

    private static let fixtureDTO = LatestRatesDTO(
        timestamp: Date(timeIntervalSince1970: 1_753_948_800),
        base: "USD",
        rates: ["USD": 1, "EUR": 0.9203, "JPY": 149.37]
    )
    private static let fixtureNames = ["USD": "United States Dollar", "EUR": "Euro", "JPY": "Japanese Yen"]

    init() {
        cache = MockRatesCache()
    }

    private func makeRepository() -> RatesRepository {
        RatesRepository(network: network, cache: cache, clock: clock)
    }

    // snapshot fetched `age` seconds before the fake clock's now
    private func makeSnapshot(age: TimeInterval) -> RatesSnapshot {
        RatesSnapshot(
            base: "USD",
            rates: Self.fixtureDTO.rates,
            currencyNames: Self.fixtureNames,
            apiTimestamp: clock.now().addingTimeInterval(-age - 60),
            fetchedAt: clock.now().addingTimeInterval(-age)
        )
    }

    @Test func testFreshCacheIsServedWithoutHittingTheNetwork() async throws {
        let fresh = makeSnapshot(age: 5 * 60)
        cache.save(fresh)

        let result = try await makeRepository().currentRates()

        #expect(result.snapshot == fresh)
        #expect(result.refreshError == nil)
        #expect(network.latestCallCount == 0)
    }

    @Test func testStaleCacheTriggersFetchAndPersists() async throws {
        cache.save(makeSnapshot(age: 31 * 60))
        network.stubLatest(.success(Self.fixtureDTO))
        network.stubNames(.success(Self.fixtureNames))

        let result = try await makeRepository().currentRates()

        #expect(network.latestCallCount == 1)
        #expect(result.refreshError == nil)
        #expect(result.snapshot.fetchedAt == clock.now())
        #expect(result.snapshot.apiTimestamp == Self.fixtureDTO.timestamp)
        #expect(cache.stored == result.snapshot)
    }

    @Test func testFailedRefreshStillServesStaleData() async throws {
        let stale = makeSnapshot(age: 45 * 60)
        cache.save(stale)
        network.stubLatest(.failure(.server(status: 500)))

        let result = try await makeRepository().currentRates()

        #expect(result.snapshot == stale)
        #expect(result.refreshError == .server(status: 500))
    }

    @Test func testNoCacheAndFailureThrows() async {
        network.stubLatest(.failure(.offline))

        await #expect(throws: NetworkError.offline) {
            _ = try await makeRepository().currentRates()
        }
    }

    @Test func testConcurrentTriggersMakeOneNetworkCall() async throws {
        network.stubLatest(.success(Self.fixtureDTO), delay: .milliseconds(100))
        network.stubNames(.success(Self.fixtureNames))
        let repository = makeRepository()

        let results = try await withThrowingTaskGroup(of: RatesFetchResult.self) { group in
            for _ in 0..<5 {
                group.addTask { try await repository.currentRates() }
            }
            return try await group.reduce(into: [RatesFetchResult]()) { $0.append($1) }
        }

        #expect(results.count == 5)
        #expect(results.allSatisfy { $0.snapshot == results[0].snapshot })
        #expect(network.latestCallCount == 1)
    }

    @Test func testOneAwaiterCancellingDoesNotCancelTheRefresh() async throws {
        network.stubLatest(.success(Self.fixtureDTO), delay: .milliseconds(100))
        network.stubNames(.success(Self.fixtureNames))
        let repository = makeRepository()

        let first = Task { try await repository.currentRates() }
        let second = Task { try await repository.currentRates() }
        try await Task.sleep(for: .milliseconds(20))
        first.cancel()

        let result = try await second.value
        #expect(result.snapshot.rates == Self.fixtureDTO.rates)
        #expect(network.latestCallCount == 1)
    }

    @Test func testCodesStandInWhenNamesRequestFails() async throws {
        network.stubLatest(.success(Self.fixtureDTO))
        network.stubNames(.failure(.server(status: 500)))

        let result = try await makeRepository().currentRates()

        #expect(result.refreshError == nil)
        #expect(result.snapshot.currencyNames == ["USD": "USD", "EUR": "EUR", "JPY": "JPY"])
    }
}
