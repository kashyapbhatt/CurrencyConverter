//
//  AppEnvironment+Testing.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

#if DEBUG
import Foundation

/// UI tests run out of process and can only pass launch arguments, so the
/// app has to configure itself from them. Kept here, behind DEBUG, so the
/// real composition root stays clean.
@MainActor
extension AppEnvironment {

    static func testingEnvironment(for process: ProcessInfo) -> AppEnvironment? {
        if process.arguments.contains("-uiTesting") {
            return uiTesting()
        }
        if process.environment["XCTestConfigurationFilePath"] != nil {
            // the unit test bundle boots the app too; keep it inert
            return unitTestHost()
        }
        return nil
    }

    // MARK: UI testing

    // throwaway cache and cleared prefs, so every run starts the same
    private static func uiTesting() -> AppEnvironment {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "lastAmount")
        defaults.removeObject(forKey: "lastCurrency")
        defaults.removeObject(forKey: Theme.storageKey)

        let cacheDirectory = FileManager.default.temporaryDirectory
            .appending(path: "uitest-cache-\(UUID().uuidString)")
        let clock = SystemDateProvider()
        let repository = RatesRepository(
            network: DummyNetworkClient(),
            cache: RatesCache(directory: cacheDirectory),
            clock: clock
        )
        return AppEnvironment(
            viewModel: ConverterViewModel(
                repository: repository,
                connectivity: ConnectivityObserver(),
                clock: clock,
                locale: Locale(identifier: "en_US") // stable strings to assert on
            )
        )
    }

    // MARK: Unit-test host

    private static func unitTestHost() -> AppEnvironment {
        struct InertRepository: RatesRepositoryProtocol {
            func currentRates() async throws -> RatesFetchResult {
                throw NetworkError.cancelled // treated as a no-op upstream
            }
        }
        return AppEnvironment(
            viewModel: ConverterViewModel(
                repository: InertRepository(),
                connectivity: ConnectivityObserver(),
                clock: SystemDateProvider(),
                defaults: UserDefaults(suiteName: "unit-test-host") ?? .standard
            )
        )
    }
}
#endif
