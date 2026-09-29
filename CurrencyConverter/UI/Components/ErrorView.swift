//
//  ErrorView.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import SwiftUI

struct ErrorView: View {
    let error: NetworkError
    let isRetrying: Bool
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(.quaternary.opacity(0.5))
                    .frame(width: 88, height: 88)
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text("Couldn't load rates")
                    .font(.title3.weight(.semibold))
                Text(error.errorDescription ?? "Something went wrong.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                retry()
            } label: {
                if isRetrying {
                    ProgressView()
                        .frame(maxWidth: 120)
                } else {
                    Text("Try again").frame(maxWidth: 120)
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .disabled(isRetrying)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ErrorView(error: .offline, isRetrying: false) {}
}
