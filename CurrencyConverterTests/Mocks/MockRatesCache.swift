//
//  MockRatesCache.swift
//  CurrencyConverterTests
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation
import os
@testable import CurrencyConverter

/// In-memory cache double. Seed it to simulate data from a previous run.
final class MockRatesCache: RatesCacheProtocol, Sendable {

    private struct State {
        var stored: RatesSnapshot?
        var saveCount = 0
    }

    private let state: OSAllocatedUnfairLock<State>

    init(seeded snapshot: RatesSnapshot? = nil) {
        state = OSAllocatedUnfairLock(initialState: State(stored: snapshot))
    }

    var saveCount: Int { state.withLock { $0.saveCount } }
    var stored: RatesSnapshot? { state.withLock { $0.stored } }

    func load() -> RatesSnapshot? {
        state.withLock { $0.stored }
    }

    func save(_ snapshot: RatesSnapshot) {
        state.withLock {
            $0.stored = snapshot
            $0.saveCount += 1
        }
    }
}
