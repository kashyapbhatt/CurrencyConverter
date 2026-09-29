//
//  NetworkClient.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation
import os

/// Everything that comes out of here is either a DTO or an `NetworkError`.
protocol NetworkClientProtocol: Sendable {
    func fetchLatestRates() async throws -> LatestRatesDTO
    func fetchCurrencyNames() async throws -> [String: String]
}

struct NetworkClient: NetworkClientProtocol {

    private static let baseURL = "https://openexchangerates.org/api/"

    private let session: URLSession
    private let appID: String

    /// The App ID comes from the composition root, not the bundle. Tests
    /// pass a configuration with MockURLProtocol installed.
    init(appID: String, configuration: URLSessionConfiguration = .ephemeral) {
        configuration.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: configuration)
        self.appID = appID
    }

    func fetchLatestRates() async throws -> LatestRatesDTO {
        let data = try await fetch("latest.json", needsAppID: true)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970 // OXR sends unix seconds
        guard let dto = try? decoder.decode(LatestRatesDTO.self, from: data) else {
            Log.network.error("latest.json body did not decode")
            throw NetworkError.invalidResponse
        }
        return dto
    }

    func fetchCurrencyNames() async throws -> [String: String] {
        let data = try await fetch("currencies.json", needsAppID: false)
        guard let names = try? JSONDecoder().decode([String: String].self, from: data) else {
            Log.network.error("currencies.json body did not decode")
            throw NetworkError.invalidResponse
        }
        return names
    }

    // MARK: Shared fetch + error mapping

    private func fetch(_ path: String, needsAppID: Bool) async throws -> Data {
        guard var components = URLComponents(string: Self.baseURL + path) else {
            throw NetworkError.invalidResponse
        }
        if needsAppID {
            components.queryItems = [URLQueryItem(name: "app_id", value: appID)]
        }
        guard let url = components.url else {
            throw NetworkError.invalidResponse
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw Self.mapTransportError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw Self.mapHTTPError(status: http.statusCode, body: data)
        }
        return data
    }

    private static func mapTransportError(_ error: Error) -> NetworkError {
        if error is CancellationError {
            return .cancelled
        }
        guard let urlError = error as? URLError else {
            return .invalidResponse
        }
        switch urlError.code {
        case .cancelled:
            return .cancelled
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            return .offline
        default:
            Log.network.error("transport failure: \(urlError.code.rawValue)")
            return .invalidResponse
        }
    }

    /// Status decides the mapping; the payload only feeds the log, so an
    /// HTML error page still maps sensibly.
    private static func mapHTTPError(status: Int, body: Data) -> NetworkError {
        if let payload = try? JSONDecoder().decode(OXRErrorDTO.self, from: body) {
            Log.network.error("API error \(payload.status): \(payload.message)")
        } else {
            Log.network.error("HTTP \(status) with undecodable body")
        }
        switch status {
        case 401: return .invalidAppID
        case 429: return .rateLimited
        default: return .server(status: status)
        }
    }
}
