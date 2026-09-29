//
//  DummyNetworkClient.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

#if DEBUG
import Foundation

/// Fixed rates for the UI tests. Lives in the app target because the
/// composition root builds it, hence the DEBUG fence.
struct DummyNetworkClient: NetworkClientProtocol {

    static let rates: [String: Double] = [
        "AED": 3.67297, "AUD": 1.5231, "BTC": 0.0000162, "CAD": 1.3796,
        "CHF": 0.8892, "EUR": 0.9203, "GBP": 0.7869, "INR": 86.41,
        "JPY": 149.37, "KWD": 0.30721, "USD": 1,
    ]

    static let names: [String: String] = [
        "AED": "United Arab Emirates Dirham", "AUD": "Australian Dollar",
        "BTC": "Bitcoin", "CAD": "Canadian Dollar", "CHF": "Swiss Franc",
        "EUR": "Euro", "GBP": "British Pound Sterling", "INR": "Indian Rupee",
        "JPY": "Japanese Yen", "KWD": "Kuwaiti Dinar", "USD": "United States Dollar",
    ]

    func fetchLatestRates() async throws -> LatestRatesDTO {
        LatestRatesDTO(
            timestamp: Date().addingTimeInterval(-120),
            base: "USD",
            rates: Self.rates
        )
    }

    func fetchCurrencyNames() async throws -> [String: String] {
        Self.names
    }
}
#endif
