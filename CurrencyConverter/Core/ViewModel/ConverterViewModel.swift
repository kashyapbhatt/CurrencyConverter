//
//  ConverterViewModel.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation
import Observation
import UIKit
import os

/// The repository decides when to hit the network and the engine does the
/// math. Everything else the view needs lives here.
@MainActor
@Observable
final class ConverterViewModel {

    /// Skeleton only on a first launch with no cache; once there's data
    /// it stays put no matter what refreshes do.
    enum ViewState: Equatable {
        case skeleton
        case content
        case error(NetworkError)
    }

    enum BannerState: Equatable {
        case fresh(asOf: Date)
        case staleOnline(ratesFrom: Date)
        case offlineFresh
        case offlineStale(ratesFrom: Date)
    }

    struct Row: Identifiable, Equatable {
        let code: String
        let name: String
        let formattedValue: String
        var id: String { code } // codes are unique and stable
    }

    private enum StorageKey {
        static let lastAmount = "lastAmount"
        static let lastCurrency = "lastCurrency"
    }

    // MARK: Observed state

    private(set) var viewState: ViewState = .skeleton
    private(set) var banner: BannerState?
    private(set) var isRetrying = false

    /// Cleaned on the way in, so the field can never hold anything the
    /// parser would choke on. Stored verbatim, which means a cleared field
    /// comes back cleared after a relaunch.
    var amountText: String {
        get { storedAmount }
        set {
            storedAmount = sanitizer.sanitize(newValue)
            defaults.set(storedAmount, forKey: StorageKey.lastAmount)
        }
    }

    var selectedCode: String {
        didSet {
            guard oldValue != selectedCode else { return }
            defaults.set(selectedCode, forKey: StorageKey.lastCurrency)
            if !suppressHaptics {
                // only for user taps, not for restoration or the USD fallback
                UISelectionFeedbackGenerator().selectionChanged()
            }
            recompute()
        }
    }

    /// Applied in `rows`, not by recomputing; typing here shouldn't redo
    /// the math.
    var filterText = ""

    // MARK: Derived state

    /// Everything except the base row, narrowed by the filter.
    var rows: [Row] {
        guard !filterText.isEmpty else { return allRows }
        return allRows.filter {
            $0.code.localizedStandardContains(filterText)
                || $0.name.localizedStandardContains(filterText)
        }
    }

    var showsUnitRates: Bool {
        sanitizer.parse(amountText) == nil
    }

    var selectedCurrencyName: String {
        snapshot?.displayName(for: selectedCode) ?? selectedCode
    }

    var pickerItems: [(code: String, name: String)] {
        guard let snapshot else { return [] }
        return snapshot.availableCodes.map { ($0, snapshot.displayName(for: $0)) }
    }

    func pickerItems(matching search: String) -> [(code: String, name: String)] {
        guard !search.isEmpty else { return pickerItems }
        return pickerItems.filter {
            $0.code.localizedStandardContains(search) || $0.name.localizedStandardContains(search)
        }
    }

    // MARK: Dependencies

    @ObservationIgnored private let repository: RatesRepositoryProtocol
    @ObservationIgnored private let connectivity: ConnectivityObserving
    @ObservationIgnored private let clock: DateProviding
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let locale: Locale
    @ObservationIgnored private let engine = ConversionEngine()
    @ObservationIgnored private let sanitizer: AmountSanitizer
    @ObservationIgnored private let formatCache: CurrencyFormatCache
    // injected so tests don't wait 250ms per keystroke
    @ObservationIgnored private let debounceInterval: Duration

    private var storedAmount = ""
    private var snapshot: RatesSnapshot?
    private var lastRefreshError: NetworkError?
    private var allRows: [Row] = []
    // set while we change the selection ourselves, so it stays silent
    private var suppressHaptics = false

    init(
        repository: RatesRepositoryProtocol,
        connectivity: ConnectivityObserving,
        clock: DateProviding,
        defaults: UserDefaults = .standard,
        locale: Locale = .autoupdatingCurrent,
        debounceInterval: Duration = .milliseconds(250)
    ) {
        self.repository = repository
        self.connectivity = connectivity
        self.clock = clock
        self.defaults = defaults
        self.locale = locale
        self.debounceInterval = debounceInterval
        self.sanitizer = AmountSanitizer(locale: locale)
        self.formatCache = CurrencyFormatCache(locale: locale)
        // the currency gets validated against real data once the first
        // snapshot lands
        self.storedAmount = defaults.string(forKey: StorageKey.lastAmount) ?? ""
        self.selectedCode = defaults.string(forKey: StorageKey.lastCurrency) ?? ""
    }

    // MARK: Lifecycle & refresh triggers

    func load() async {
        if snapshot == nil {
            viewState = .skeleton
        }
        await fetch()
    }

    /// Inside the throttle window the repository answers from cache and
    /// this just ends. No toast, no call.
    func refresh() async {
        await fetch()
    }

    func retry() async {
        isRetrying = true
        defer { isRetrying = false }
        await fetch()
    }

    func scenePhaseBecameActive() async {
        guard let snapshot else { return } // initial load owns the no-data path
        if snapshot.isFresh(now: clock.now()) {
            updateBanner()
        } else {
            await fetch()
        }
    }

    /// Runs for the view's lifetime. Reconnecting with stale data
    /// refreshes; the repository is what keeps that to one call.
    func observeConnectivity() async {
        for await online in connectivity.statusStream {
            updateBanner()
            if online, let snapshot, !snapshot.isFresh(now: clock.now()) {
                await fetch()
            }
        }
    }

    /// Driven by `.task(id: amountText)`. A new keystroke cancels this
    /// mid-sleep, so only the last value recomputes.
    func debouncedRecompute() async {
        guard (try? await Task.sleep(for: debounceInterval)) != nil else {
            return // cancelled, a newer value is on its way
        }
        recompute()
    }

    // MARK: Fetching

    private func fetch() async {
        do {
            let result = try await repository.currentRates()
            apply(result)
        } catch {
            let appError = error as? NetworkError ?? .invalidResponse
            guard appError != .cancelled else { return } // not a user-facing error
            if snapshot == nil {
                // the only full-screen error: no data and no way to get any
                viewState = .error(appError)
            }
        }
    }

    private func apply(_ result: RatesFetchResult) {
        snapshot = result.snapshot
        lastRefreshError = result.refreshError == .cancelled ? nil : result.refreshError
        validateSelectedCurrency()
        viewState = .content
        recompute()
        updateBanner()
    }

    /// On the first snapshot this picks a default; on later ones it
    /// catches a selection that lost its rate.
    private func validateSelectedCurrency() {
        guard let snapshot else { return }
        let available = Set(snapshot.availableCodes)

        suppressHaptics = true
        defer { suppressHaptics = false }

        if selectedCode.isEmpty {
            if let region = locale.currency?.identifier, available.contains(region) {
                selectedCode = region
            } else {
                selectedCode = "USD"
            }
        } else if !available.contains(selectedCode) {
            Log.app.notice("selected currency \(self.selectedCode) missing from refreshed rates, falling back to USD")
            selectedCode = "USD"
        }
    }

    private func recompute() {
        guard let snapshot else {
            allRows = []
            return
        }
        // empty field means the per-unit table
        let amount = sanitizer.parse(amountText) ?? 1

        do {
            allRows = try engine.convertAll(amount: amount, base: selectedCode, rates: snapshot.rates)
                .filter { $0.code != selectedCode } // the base is the input, not a result
                .map { conversion in
                    Row(
                        code: conversion.code,
                        name: snapshot.displayName(for: conversion.code),
                        formattedValue: formatCache.string(for: conversion.value, code: conversion.code)
                    )
                }
        } catch {
            // shouldn't happen, the picker only offers rated codes
            viewState = .error(error as? NetworkError ?? .conversionUnavailable)
        }
    }

    private func updateBanner() {
        guard let snapshot else {
            banner = nil
            return
        }
        let stale = lastRefreshError != nil || !snapshot.isFresh(now: clock.now())
        switch (connectivity.isOnline, stale) {
        case (true, false): banner = .fresh(asOf: snapshot.apiTimestamp)
        case (true, true): banner = .staleOnline(ratesFrom: snapshot.apiTimestamp)
        case (false, false): banner = .offlineFresh
        case (false, true): banner = .offlineStale(ratesFrom: snapshot.apiTimestamp)
        }
    }
}
