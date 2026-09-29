//
//  CurrencyBadge.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import SwiftUI

/// Flag in a circle, or the first two letters when the currency has no flag
/// (gold, Bitcoin, the CFA francs).
struct CurrencyBadge: View {
    let code: String
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            Circle()
                .fill(.quaternary.opacity(0.6))

            if let flag = CurrencyFlag.emoji(for: code) {
                Text(flag)
                    .font(.system(size: size * 0.52))
            } else {
                Text(code.prefix(2))
                    .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 12) {
        CurrencyBadge(code: "USD")
        CurrencyBadge(code: "JPY")
        CurrencyBadge(code: "EUR")
        CurrencyBadge(code: "BTC")
        CurrencyBadge(code: "XAU")
    }
    .padding()
}
