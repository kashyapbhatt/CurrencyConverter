//
//  ConverterViewModelTests.swift
//  CurrencyConverterTests
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation
import Testing
@testable import CurrencyConverter

/// The view model against a scripted repository, fake clock, and mock
/// connectivity. en_US throughout so formatted strings are predictable.
@MainActor
struct ConverterViewModelTests {

    private let repository = MockRatesRepository()
    private let connectivity = MockConnectivityObserver()
    private let clock = MockClock()
    private let defaults: UserDefaults
    private let suiteName: String

    init() {
        suiteName = "ConverterViewModelTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    // MARK: Helpers

    private func makeViewModel(debounce: Duration = .milliseconds(20)) -> ConverterViewModel {
        ConverterViewModel(
            repository: repository,
            connectivity: connectivity,
            clock: clock,
            defaults: defaults,
            locale: Locale(identifier: "en_US"),
            debounceInterval: debounce
        )
    }

    private func makeSnapshot(age: TimeInterval = 60) throws -> RatesSnapshot {
        RatesSnapshot(
            base: "USD",
            rates: try Mocks.latestRates(),
            currencyNames: try Mocks.currencyNames(),
            apiTimestamp: clock.now().addingTimeInterval(-age - 300),
            fetchedAt: clock.now().addingTimeInterval(-age)
        )
    }

    private func makeResult(age: TimeInterval = 60, error: NetworkError? = nil) throws -> RatesFetchResult {
        RatesFetchResult(snapshot: try makeSnapshot(age: age), refreshError: error)
    }

    private func expectedValue(_ value: Double, _ code: String) -> String {
        value.formatted(.currency(code: code).locale(Locale(identifier: "en_US")))
    }

    enum BannerKind {
        case fresh, staleOnline, offlineFresh, offlineStale, none
    }

    private func kind(of banner: ConverterViewModel.BannerState?) -> BannerKind {
        switch banner {
        case .fresh: .fresh
        case .staleOnline: .staleOnline
        case .offlineFresh: .offlineFresh
        case .offlineStale: .offlineStale
        case nil: .none
        }
    }

    @Test func testSuccessfulLoadShowsContent() async throws {
        repository.stub(.success(try makeResult()))
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.viewState == .content)
        #expect(!viewModel.rows.isEmpty)
    }

    @Test func testFailedLoadWithNoCacheShowsError() async {
        repository.stub(.failure(.offline))
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.viewState == .error(.offline))
    }

    @Test func testSlowFirstLoadShowsSkeleton() async throws {
        repository.stub(.success(try makeResult()), delay: .milliseconds(80))
        let viewModel = makeViewModel()

        let loadTask = Task { await viewModel.load() }
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.viewState == .skeleton)

        await loadTask.value
        #expect(viewModel.viewState == .content)
    }

    @Test func testDebounceKeepsOnlyTheLastAmount() async throws {
        repository.stub(.success(try makeResult()))
        let viewModel = makeViewModel()
        await viewModel.load()

        viewModel.amountText = "100"
        let stale = Task { await viewModel.debouncedRecompute() }
        stale.cancel() // this is what .task(id:) does when the id changes

        viewModel.amountText = "200"
        await viewModel.debouncedRecompute()

        let eur = viewModel.rows.first { $0.code == "EUR" }
        #expect(eur?.formattedValue == expectedValue(200 * 0.9203, "EUR"))
        _ = await stale.value
    }

    @Test func testChangingCurrencyRecomputesAndPersists() async throws {
        repository.stub(.success(try makeResult()))
        let viewModel = makeViewModel()
        await viewModel.load()
        viewModel.amountText = "100"

        viewModel.selectedCode = "EUR"

        #expect(defaults.string(forKey: "lastCurrency") == "EUR")
        #expect(!viewModel.rows.contains { $0.code == "EUR" }) // base excluded from results
        let jpy = viewModel.rows.first { $0.code == "JPY" }
        #expect(jpy?.formattedValue == expectedValue(100 * 149.37 / 0.9203, "JPY"))
    }

    @Test func testFilterMatchesCodeAndName() async throws {
        repository.stub(.success(try makeResult()))
        let viewModel = makeViewModel()
        await viewModel.load()

        viewModel.filterText = "yen"
        #expect(viewModel.rows.map(\.code) == ["JPY"])

        viewModel.filterText = "KW"
        #expect(viewModel.rows.map(\.code) == ["KWD"])

        viewModel.filterText = "zzzz"
        #expect(viewModel.rows.isEmpty) // view renders "No matches" for this
    }

    /// The banner matrix: what shows for each combination of connectivity
    /// and data age. The stale cases carry a date, so this compares the
    /// case rather than the whole value.
    @Test(arguments: [
        (true, 60.0, NetworkError?.none, BannerKind.fresh),
        (true, 45 * 60.0, .server(status: 500), .staleOnline),
        (false, 60.0, nil, .offlineFresh),
        (false, 45 * 60.0, .offline, .offlineStale),
    ])
    func testBannerMatrix(
        online: Bool,
        age: TimeInterval,
        refreshError: NetworkError?,
        expected: BannerKind
    ) async throws {
        connectivity.setOnline(online)
        repository.stub(.success(try makeResult(age: age, error: refreshError)))
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(kind(of: viewModel.banner) == expected)
    }

    @Test func testRetryAfterFailureShowsContent() async throws {
        repository.stub(.failure(.timeout), .success(try makeResult()))
        let viewModel = makeViewModel()

        await viewModel.load()
        #expect(viewModel.viewState == .error(.timeout))

        await viewModel.retry()
        #expect(viewModel.viewState == .content)
    }

    @Test func testEmptyAmountShowsUnitRates() async throws {
        repository.stub(.success(try makeResult()))
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.showsUnitRates)
        let eur = viewModel.rows.first { $0.code == "EUR" }
        #expect(eur?.formattedValue == expectedValue(0.9203, "EUR")) // rates for 1 USD
    }

    @Test func testTypedZeroShowsZeros() async throws {
        repository.stub(.success(try makeResult()))
        let viewModel = makeViewModel()
        await viewModel.load()

        viewModel.amountText = "0"
        await viewModel.debouncedRecompute()

        #expect(!viewModel.showsUnitRates)
        let eur = viewModel.rows.first { $0.code == "EUR" }
        #expect(eur?.formattedValue == expectedValue(0, "EUR"))
    }

    @Test func testRestoresLastAmountAndCurrency() async throws {
        defaults.set("42.5", forKey: "lastAmount")
        defaults.set("EUR", forKey: "lastCurrency")
        repository.stub(.success(try makeResult()))
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.amountText == "42.5")
        #expect(viewModel.selectedCode == "EUR")
    }

    @Test func testUnavailableStoredCurrencyFallsBackToUSD() async throws {
        defaults.set("XXX", forKey: "lastCurrency") // named in fixtures, but no rate
        repository.stub(.success(try makeResult()))
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.selectedCode == "USD") // silent fallback
    }

    @Test func testFirstLaunchUsesRegionCurrency() async throws {
        repository.stub(.success(try makeResult()))
        let viewModel = makeViewModel() // en_US region currency is USD

        await viewModel.load()

        #expect(viewModel.selectedCode == "USD")
        #expect(viewModel.amountText.isEmpty) // unit-rate state
    }
}
