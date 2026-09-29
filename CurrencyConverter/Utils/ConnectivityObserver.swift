//
//  ConnectivityObserver.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation
import Network
import os

protocol ConnectivityObserving: Sendable {
    var isOnline: Bool { get }
    var statusStream: AsyncStream<Bool> { get }
}

/// `@unchecked` because NWPathMonitor isn't Sendable-annotated; our own
/// state is behind a lock.
final class ConnectivityObserver: ConnectivityObserving, @unchecked Sendable {

    private let monitor = NWPathMonitor()
    private let online: OSAllocatedUnfairLock<Bool>
    let statusStream: AsyncStream<Bool>

    var isOnline: Bool { online.withLock { $0 } }

    init() {
        // start optimistic; assuming offline would flash the banner at launch
        let online = OSAllocatedUnfairLock(initialState: true)
        self.online = online

        let (stream, continuation) = AsyncStream.makeStream(of: Bool.self, bufferingPolicy: .bufferingNewest(1))
        statusStream = stream

        monitor.pathUpdateHandler = { path in
            let satisfied = path.status == .satisfied
            let changed = online.withLock { current in
                let didChange = current != satisfied
                current = satisfied
                return didChange
            }
            if changed {
                Log.app.info("connectivity changed: \(satisfied ? "online" : "offline")")
                continuation.yield(satisfied)
            }
        }
        monitor.start(queue: DispatchQueue(label: "connectivity-monitor"))
    }

    deinit {
        monitor.cancel()
    }
}
