//
//  SkeletonView.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import SwiftUI

struct SkeletonView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    var body: some View {
        VStack(spacing: 12) {
            placeholderCard
            ForEach(0..<7, id: \.self) { _ in
                placeholderRow
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .redacted(reason: .placeholder)
        .opacity(dimmed ? 0.45 : 1)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
            value: dimmed
        )
        .onAppear {
            guard !reduceMotion else { return } // no pulse under Reduce Motion
            dimmed = true
        }
        // one announcement instead of a screen full of redacted rows
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading rates")
    }

    private var placeholderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(verbatim: "USD").font(.headline)
                Spacer()
                Text(verbatim: "1,234").font(.system(size: 40, weight: .semibold, design: .rounded))
            }
            Divider()
            Text(verbatim: "Rates for 1 USD").font(.caption)
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20))
    }

    private var placeholderRow: some View {
        HStack(spacing: 14) {
            Circle().fill(.quaternary).frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "USD").font(.subheadline.weight(.semibold))
                Text(verbatim: "Placeholder Currency").font(.caption)
            }
            Spacer()
            Text(verbatim: "1,234.56").font(.system(.body, design: .rounded))
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    SkeletonView()
}
