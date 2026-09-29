//
//  MockConnectivityObserver.swift
//  CurrencyConverterTests
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation
import os
@testable import CurrencyConverter

/// Connectivity double. `setOnline` flips the value and fires the stream,
/// like a real path update would.
final class MockConnectivityObserver: ConnectivityObserving, Sendable {

    private let online: OSAllocatedUnfairLock<Bool>
    private let continuation: AsyncStream<Bool>.Continuation
    let statusStream: AsyncStream<Bool>

    var isOnline: Bool { online.withLock { $0 } }

    init(isOnline: Bool = true) {
        online = OSAllocatedUnfairLock(initialState: isOnline)
        (statusStream, continuation) = AsyncStream.makeStream(of: Bool.self)
    }

    func setOnline(_ value: Bool) {
        online.withLock { $0 = value }
        continuation.yield(value)
    }
}
