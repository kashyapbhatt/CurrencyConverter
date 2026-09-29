//
//  Mocks.swift
//  CurrencyConverterTests
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation

/// Loads the bundled JSON Mocks.
enum Mocks {

    static func data(named name: String) throws -> Data {
        // Bundle(for:) wants a class and the suites are all structs, so
        // borrow one of the mocks
        guard let url = Bundle(for: MockURLProtocol.self).url(forResource: name, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "\(name).json"])
        }
        return try Data(contentsOf: url)
    }

    /// The rates dictionary from the canonical latest.json fixture.
    static func latestRates() throws -> [String: Double] {
        struct Payload: Decodable { let rates: [String: Double] }
        return try JSONDecoder().decode(Payload.self, from: data(named: "latest")).rates
    }

    /// The code → display-name mapping from the currencies.json fixture.
    static func currencyNames() throws -> [String: String] {
        try JSONDecoder().decode([String: String].self, from: data(named: "currencies"))
    }
}
