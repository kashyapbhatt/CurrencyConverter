//
//  MockRatesRepository.swift
//  CurrencyConverterTests
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation
@testable import CurrencyConverter

/// Only the view-model tests use this, and those are all @MainActor, so
/// plain properties are fine here. The doubles that get hit from the
/// repository's task groups need locks; this one doesn't.
final class MockRatesRepository: RatesRepositoryProtocol, @unchecked Sendable {

    var results: [Result<RatesFetchResult, NetworkError>] = []
    var delay: Duration = .zero
    private(set) var callCount = 0

    /// The last result sticks around, so `stub(.failure(...), .success(...))`
    /// covers a retry.
    func stub(_ results: Result<RatesFetchResult, NetworkError>..., delay: Duration = .zero) {
        self.results = results
        self.delay = delay
    }

    func currentRates() async throws -> RatesFetchResult {
        callCount += 1
        let next = results.count > 1 ? results.removeFirst() : results.first

        if delay > .zero {
            try? await Task.sleep(for: delay)
        }
        guard let next else { throw NetworkError.invalidResponse }
        return try next.get()
    }
}
