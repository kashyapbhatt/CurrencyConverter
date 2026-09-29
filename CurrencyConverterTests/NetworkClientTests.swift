//
//  NetworkClientTests.swift
//  CurrencyConverterTests
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation
import Testing
import os
@testable import CurrencyConverter

/// Request construction, decoding, and the error mapping, all through
/// MockURLProtocol. Serialized because the mock's handler is shared
/// static state.
@Suite(.serialized)
struct NetworkClientTests {

    private func makeClient(appID: String = "test_app_id") -> NetworkClient {
        NetworkClient(appID: appID, configuration: MockURLProtocol.configuration)
    }

    @Test func testLatestRatesURLIncludesAppID() async throws {
        let captured = OSAllocatedUnfairLock<URL?>(initialState: nil)
        MockURLProtocol.setHandler { request in
            captured.withLock { $0 = request.url }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, try Mocks.data(named: "latest"))
        }

        _ = try await makeClient().fetchLatestRates()

        let url = captured.withLock { $0 }
        #expect(url?.host() == "openexchangerates.org")
        #expect(url?.path() == "/api/latest.json")
        #expect(url?.query() == "app_id=test_app_id")
    }

    @Test func testCurrencyNamesURLHasNoAppID() async throws {
        let captured = OSAllocatedUnfairLock<URL?>(initialState: nil)
        MockURLProtocol.setHandler { request in
            captured.withLock { $0 = request.url }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, try Mocks.data(named: "currencies"))
        }

        _ = try await makeClient().fetchCurrencyNames()

        let url = captured.withLock { $0 }
        #expect(url?.path() == "/api/currencies.json")
        #expect(url?.query() == nil)
    }

    @Test func testDecodingLatestRates() async throws {
        MockURLProtocol.respond(status: 200, data: try Mocks.data(named: "latest"))

        let dto = try await makeClient().fetchLatestRates()

        #expect(dto.base == "USD")
        #expect(dto.timestamp == Date(timeIntervalSince1970: 1_753_948_800))
        #expect(dto.rates["JPY"] == 149.37)
        #expect(dto.rates.count == 11)
    }

    @Test func testUnauthorizedMapsToInvalidAppID() async throws {
        MockURLProtocol.respond(status: 401, data: try Mocks.data(named: "error_invalid_app_id"))

        await #expect(throws: NetworkError.invalidAppID) {
            _ = try await makeClient().fetchLatestRates()
        }
    }

    @Test(arguments: [
        (403, NetworkError.server(status: 403)),
        (429, NetworkError.rateLimited),
        (500, NetworkError.server(status: 500)),
        (503, NetworkError.server(status: 503)),
    ])
    func testErrorStatusesMapToTypedErrors(status: Int, expected: NetworkError) async throws {
        let body = Data(#"{"error": true, "status": \#(status), "message": "err", "description": "d"}"#.utf8)
        MockURLProtocol.respond(status: status, data: body)

        await #expect(throws: expected) {
            _ = try await makeClient().fetchLatestRates()
        }
    }

    @Test func testUnparseableErrorBodyStillMapsByStatus() async {
        MockURLProtocol.respond(status: 404, data: Data("<html>not found</html>".utf8))

        await #expect(throws: NetworkError.server(status: 404)) {
            _ = try await makeClient().fetchLatestRates()
        }
    }

    @Test func testGarbageBodyMapsToInvalidResponse() async {
        MockURLProtocol.respond(status: 200, data: Data("not json at all".utf8))

        await #expect(throws: NetworkError.invalidResponse) {
            _ = try await makeClient().fetchLatestRates()
        }
    }

    @Test(arguments: [
        (URLError.timedOut, NetworkError.timeout),
        (URLError.cancelled, NetworkError.cancelled),
        (URLError.notConnectedToInternet, NetworkError.offline),
    ])
    func testTransportErrorsMapToTypedErrors(code: URLError.Code, expected: NetworkError) async {
        MockURLProtocol.setHandler { _ in throw URLError(code) }

        await #expect(throws: expected) {
            _ = try await makeClient().fetchLatestRates()
        }
    }
}
