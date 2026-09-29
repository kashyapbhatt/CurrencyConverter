//
//  AppEnvironment.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation

@MainActor
struct AppEnvironment {

    let viewModel: ConverterViewModel

    static func make() -> AppEnvironment {
        #if DEBUG
        // see AppEnvironment+Testing.swift
        if let testing = testingEnvironment(for: .processInfo) {
            return testing
        }
        #endif
        return live()
    }

    // MARK: Live

    static func live() -> AppEnvironment {
        let appID = (Bundle.main.object(forInfoDictionaryKey: "OXRAppID") as? String) ?? ""
        assert(
            !appID.isEmpty && appID != "REPLACE_ME",
            "No Open Exchange Rates App ID. Put yours in Config/Config.xcconfig (OXR_APP_ID), see README."
        )

        let clock = SystemDateProvider()
        let repository = RatesRepository(
            network: NetworkClient(appID: appID),
            cache: RatesCache(),
            clock: clock
        )
        return AppEnvironment(
            viewModel: ConverterViewModel(
                repository: repository,
                connectivity: ConnectivityObserver(),
                clock: clock
            )
        )
    }
}
