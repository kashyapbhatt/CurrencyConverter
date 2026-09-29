//
//  StatusBannerView.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import SwiftUI

struct StatusBannerView: View {
    let state: ConverterViewModel.BannerState

    var body: some View {
        switch state {
        case .fresh(let asOf):
            label(
                icon: "checkmark.circle.fill",
                text: "Updated \(asOf.formatted(date: .omitted, time: .shortened))",
                tint: .secondary
            )

        case .staleOnline(let ratesFrom):
            label(
                icon: "exclamationmark.triangle.fill",
                text: "Couldn't update · \(relative(ratesFrom))",
                tint: .orange
            )

        case .offlineFresh:
            // data under 30 min is what online users see anyway; no date
            label(icon: "wifi.slash", text: "Offline", tint: .secondary)

        case .offlineStale(let ratesFrom):
            label(icon: "wifi.slash", text: "Offline · \(relative(ratesFrom))", tint: .secondary)
        }
    }

    private func relative(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }

    private func label(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.caption2)
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

#Preview("All states") {
    VStack(spacing: 12) {
        StatusBannerView(state: .fresh(asOf: .now))
        StatusBannerView(state: .staleOnline(ratesFrom: .now.addingTimeInterval(-90_000)))
        StatusBannerView(state: .offlineFresh)
        StatusBannerView(state: .offlineStale(ratesFrom: .now.addingTimeInterval(-90_000)))
    }
    .padding()
}
