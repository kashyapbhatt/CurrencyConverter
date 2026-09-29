//
//  DTOs.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation

/// Kept separate from `RatesSnapshot` so the wire format can change
/// without touching what we persist.
struct LatestRatesDTO: Decodable, Equatable, Sendable {
    /// Unix seconds; the server's "rates as of" moment.
    let timestamp: Date
    let base: String
    let rates: [String: Double]
}

struct OXRErrorDTO: Decodable, Equatable, Sendable {
    let error: Bool
    let status: Int
    let message: String
    let description: String?
}
