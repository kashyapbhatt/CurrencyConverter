//
//  MockURLProtocol.swift
//  CurrencyConverterTests
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation
import os

/// Intercepts every request on a session configured with it, so the
/// NetworkClient can be tested without any real networking.
final class MockURLProtocol: URLProtocol {

    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    // locked because the URL loading system calls in from its own thread
    private static let handler = OSAllocatedUnfairLock<Handler?>(initialState: nil)

    static func setHandler(_ newHandler: Handler?) {
        handler.withLock { $0 = newHandler }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler.withLock({ $0 }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension MockURLProtocol {
    /// Session configuration that routes everything through this mock.
    static var configuration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return configuration
    }

    ///  "respond with this status and body".
    static func respond(status: Int, data: Data) {
        setHandler { request in
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else {
                throw URLError(.badURL)
            }
            return (response, data)
        }
    }
}
