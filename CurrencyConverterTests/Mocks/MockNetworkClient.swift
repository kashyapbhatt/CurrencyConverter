//
//  MockNetworkClient.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation
import os
@testable import CurrencyConverter

/// Scriptable network double. Exposes call counts so the throttle tests
/// can assert the network was never touched.
final class MockNetworkClient: NetworkClientProtocol, Sendable {

    private struct State {
        var latestResult: Result<LatestRatesDTO, NetworkError> = .failure(.invalidResponse)
        var namesResult: Result<[String: String], NetworkError> = .failure(.invalidResponse)
        var latestDelay: Duration = .zero
        var latestCallCount = 0
        var namesCallCount = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var latestCallCount: Int { state.withLock { $0.latestCallCount } }
    var namesCallCount: Int { state.withLock { $0.namesCallCount } }

    func stubLatest(_ result: Result<LatestRatesDTO, NetworkError>, delay: Duration = .zero) {
        state.withLock {
            $0.latestResult = result
            $0.latestDelay = delay
        }
    }

    func stubNames(_ result: Result<[String: String], NetworkError>) {
        state.withLock { $0.namesResult = result }
    }

    func fetchLatestRates() async throws -> LatestRatesDTO {
        let (result, delay) = state.withLock {
            $0.latestCallCount += 1
            return ($0.latestResult, $0.latestDelay)
        }
        if delay > .zero {
            try? await Task.sleep(for: delay)
        }
        return try result.get()
    }

    func fetchCurrencyNames() async throws -> [String: String] {
        let result = state.withLock {
            $0.namesCallCount += 1
            return $0.namesResult
        }
        return try result.get()
    }
}
