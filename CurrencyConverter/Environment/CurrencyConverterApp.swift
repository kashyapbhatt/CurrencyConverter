//
//  CurrencyConverterApp.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import SwiftUI

@main
struct CurrencyConverterApp: App {
    
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Theme.storageKey) private var appearanceRawValue = Theme.system.rawValue

    @State private var environment = AppEnvironment.make()
    
    var body: some Scene {
        WindowGroup {
            ConverterView(viewModel: environment.viewModel)
                .preferredColorScheme((Theme(rawValue: appearanceRawValue) ?? .system).colorScheme)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            // the repository's throttle stops this over-fetching
            Task { await environment.viewModel.scenePhaseBecameActive() }
        }
    }
}
