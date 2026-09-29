//
//  CurrencyFormatCache.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation

/// Formats row values with per-currency fraction digits (JPY gets 0, KWD
/// gets 3) and caches the FormatStyle per code. The cache matters because
/// the list re-renders ~170 rows on every keystroke, and building styles
/// isn't cheap.
@MainActor
final class CurrencyFormatCache {

    private let locale: Locale
    private var styles: [String: FloatingPointFormatStyle<Double>.Currency] = [:]

    init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
    }

    func string(for value: Double, code: String) -> String {
        value.formatted(style(for: code))
    }

    private func style(for code: String) -> FloatingPointFormatStyle<Double>.Currency {
        if let cached = styles[code] { return cached }
        let style = FloatingPointFormatStyle<Double>.Currency(code: code, locale: locale)
        styles[code] = style
        return style
    }
}
