//
//  CurrencyChip.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import SwiftUI

struct CurrencyChip: View {
    let code: String
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                CurrencyBadge(code: code, size: 28)
                Text(code)
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .padding(.vertical, 6) // keeps the tap target past 44pt
            .background(.background.secondary, in: Capsule())
            .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Selected currency: \(name)")
        .accessibilityHint("Opens the currency list")
        .accessibilityIdentifier(AccessibilityID.currencyChip)
    }
}

#Preview {
    CurrencyChip(code: "USD", name: "United States Dollar") {}
        .padding()
}
