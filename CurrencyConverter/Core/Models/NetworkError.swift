//
//  NetworkError.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation

/// One failure type, so nothing above the network layer has to know
/// about URLError or HTTP statuses.
enum NetworkError: Error, Equatable, Sendable {
    case invalidAppID
    case rateLimited
    case server(status: Int)
    /// The reply wasn't something we could read: bad JSON, an HTML error
    /// page, an empty body.
    case invalidResponse
    case offline
    case timeout
    /// Never shown to the user.
    case cancelled
    /// Defensive; the picker only offers codes that have rates.
    case conversionUnavailable
}

// MARK: - User-facing messages

extension NetworkError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .invalidAppID:
            "The rates service rejected the request."
        case .rateLimited:
            "The rates service is busy. Please try again later."
        case .server:
            "The rates service is having trouble right now."
        case .invalidResponse:
            "Received an unexpected reply from the rates service."
        case .offline:
            "You're offline. Connect to the internet to load rates."
        case .timeout:
            "The request took too long. Please try again."
        case .cancelled:
            "The request was cancelled."
        case .conversionUnavailable:
            "Rates for the selected currency aren't available."
        }
    }
}
