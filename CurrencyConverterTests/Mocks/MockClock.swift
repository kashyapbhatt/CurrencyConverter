//
//  MockClock.swift
//  CurrencyConverterTests
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation
import os
@testable import CurrencyConverter

/// A clock the tests can move. The throttle window is 30 minutes and
/// nobody is waiting that out in a test run.
final class MockClock: DateProviding, Sendable {

    private let state: OSAllocatedUnfairLock<Date>

    init(now: Date = Date(timeIntervalSince1970: 1_753_950_000)) {
        state = OSAllocatedUnfairLock(initialState: now)
    }

    func now() -> Date {
        state.withLock { $0 }
    }

    func advance(by interval: TimeInterval) {
        state.withLock { $0 = $0.addingTimeInterval(interval) }
    }

    func set(_ date: Date) {
        state.withLock { $0 = date }
    }
}
