//
//  CurrencyRow.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import SwiftUI

struct CurrencyRow: View {
    let row: ConverterViewModel.Row

    var body: some View {
        HStack(spacing: 14) {
            CurrencyBadge(code: row.code)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.code)
                    .font(.subheadline.weight(.semibold))
                Text(row.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(row.formattedValue)
                .font(.system(.body, design: .rounded, weight: .medium))
                .monospacedDigit() // keeps rows steady while typing
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.25), value: row.formattedValue)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                UIPasteboard.general.string = row.formattedValue
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
        // one VoiceOver element per row: "Japanese Yen, ¥15,032"
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.name), \(row.formattedValue)")
        .accessibilityIdentifier(AccessibilityID.row(row.code))
    }
}

#Preview {
    List {
        CurrencyRow(row: .init(code: "JPY", name: "Japanese Yen", formattedValue: "¥15,032"))
        CurrencyRow(row: .init(code: "AED", name: "United Arab Emirates Dirham", formattedValue: "367.30"))
        CurrencyRow(row: .init(code: "BTC", name: "Bitcoin", formattedValue: "BTC 0.00"))
    }
    .listStyle(.plain)
}
