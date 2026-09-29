//
//  RatesSnapshot.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation

/// Rates and names are stored together so they can't drift apart.
struct RatesSnapshot: Codable, Equatable, Sendable {
    var base: String
    var rates: [String: Double]
    var currencyNames: [String: String]
    /// The server's "rates as of" time; shown in the caption.
    var apiTimestamp: Date
    /// When we fetched. The throttle measures from this, not from
    /// `apiTimestamp`, since the server refreshes on its own schedule.
    var fetchedAt: Date
}

extension RatesSnapshot {

    static let maxAge: TimeInterval = 30 * 60

    func isFresh(now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) < Self.maxAge
    }

    /// A name without a rate isn't selectable. A rate without a name is
    /// fine, `displayName` falls back to the code.
    var availableCodes: [String] {
        rates
            .filter { $0.value.isFinite && $0.value > 0 }
            .keys
            .sorted()
    }

    func displayName(for code: String) -> String {
        guard let name = currencyNames[code], !name.isEmpty else { return code }
        return name
    }
}
