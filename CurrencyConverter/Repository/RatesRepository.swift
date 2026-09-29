//
//  RatesRepository.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation
import os

/// The best snapshot we have, plus whatever stopped it being fresher.
/// Returning the error alongside the data (rather than throwing) is what
/// keeps the app usable offline.
struct RatesFetchResult: Equatable, Sendable {
    let snapshot: RatesSnapshot
    let refreshError: NetworkError?
}

/// Every refresh trigger goes through here: launch, foregrounding,
/// pull-to-refresh, reconnect. No force flag: the window applies to all.
protocol RatesRepositoryProtocol: Sendable {
    /// Throws only when there's no data at all and the fetch failed.
    func currentRates() async throws -> RatesFetchResult
}

/// An actor because it guards the cached snapshot and the in-flight
/// refresh task.
actor RatesRepository: RatesRepositoryProtocol {

    private let network: NetworkClientProtocol
    private let cache: RatesCacheProtocol
    private let clock: DateProviding

    private var cachedSnapshot: RatesSnapshot?
    // everyone awaits this same task, so N triggers = 1 network call
    private var inFlightRefresh: Task<RatesSnapshot, Error>?

    init(network: NetworkClientProtocol, cache: RatesCacheProtocol, clock: DateProviding) {
        self.network = network
        self.cache = cache
        self.clock = clock
    }

    func currentRates() async throws -> RatesFetchResult {
        let existing = loadSnapshot()

        if let existing, existing.isFresh(now: clock.now()) {
            return RatesFetchResult(snapshot: existing, refreshError: nil)
        }

        do {
            let refreshed = try await refresh()
            return RatesFetchResult(snapshot: refreshed, refreshError: nil)
        } catch {
            let appError = error as? NetworkError ?? .invalidResponse
            if let existing {
                // stale beats nothing; the banner reports the failure
                return RatesFetchResult(snapshot: existing, refreshError: appError)
            }
            throw appError
        }
    }

    private func loadSnapshot() -> RatesSnapshot? {
        if cachedSnapshot == nil {
            cachedSnapshot = cache.load()
        }
        return cachedSnapshot
    }

    // MARK: Refresh

    private func refresh() async throws -> RatesSnapshot {
        if let inFlightRefresh {
            // awaiting .value won't cancel the task if this caller is
            // cancelled, so one caller backing out doesn't kill the rest
            return try await inFlightRefresh.value
        }

        let task = Task { [network, clock] in
            // both together, so names and rates describe the same moment
            async let ratesCall = network.fetchLatestRates()
            async let namesCall = network.fetchCurrencyNames()

            let dto = try await ratesCall
            // names are best-effort; fall back to codes and let the next
            // refresh heal it
            let names = (try? await namesCall) ?? [:]
            let currencyNames = names.isEmpty
                ? Dictionary(uniqueKeysWithValues: dto.rates.keys.map { ($0, $0) })
                : names

            return RatesSnapshot(
                base: dto.base,
                rates: dto.rates,
                currencyNames: currencyNames,
                apiTimestamp: dto.timestamp,
                fetchedAt: clock.now()
            )
        }
        inFlightRefresh = task
        defer { inFlightRefresh = nil }

        let snapshot = try await task.value
        cachedSnapshot = snapshot
        cache.save(snapshot)
        Log.app.info("refreshed rates: \(snapshot.rates.count) codes")
        return snapshot
    }
}
