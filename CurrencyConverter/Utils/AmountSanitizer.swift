//
//  AmountSanitizer.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation

/// Paste stays enabled on the amount field (copying a number out of a
/// message is half the point of a converter), so this has to cope with
/// whatever lands there.
struct AmountSanitizer: Sendable {

    // truncate rather than let the formatter choke
    static let maxIntegerDigits = 12
    static let maxFractionDigits = 6

    private let decimalSeparator: String

    init(locale: Locale = .autoupdatingCurrent) {
        decimalSeparator = locale.decimalSeparator ?? "."
    }

    /// Keeps ASCII digits and the first separator, drops everything else.
    /// "." is accepted in any locale because people paste US-formatted
    /// numbers everywhere.
    func sanitize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        var integerPart = ""
        var fractionPart = ""
        var sawSeparator = false

        for character in trimmed {
            // isWholeNumber on its own also matches Arabic-Indic and other
            // Unicode digits, which Double() can't read. Keeping those would
            // hand back a string that quietly parses as 0, so require ASCII.
            if character.isASCII, character.isWholeNumber {
                if sawSeparator {
                    fractionPart.append(character)
                } else {
                    integerPart.append(character)
                }
            } else if !sawSeparator, String(character) == decimalSeparator || character == "." {
                sawSeparator = true
            }
            // later separators are dropped, so "1.2.3" comes out as "1.23"
        }

        integerPart = Self.stripLeadingZeros(integerPart)
        integerPart = String(integerPart.prefix(Self.maxIntegerDigits))
        fractionPart = String(fractionPart.prefix(Self.maxFractionDigits))

        return sawSeparator ? integerPart + decimalSeparator + fractionPart : integerPart
    }

    /// nil means nothing was entered: the unit-rate state, not an error.
    func parse(_ text: String) -> Double? {
        let sanitized = sanitize(text)
        guard !sanitized.isEmpty else { return nil }
        let normalized = sanitized.replacingOccurrences(of: decimalSeparator, with: ".")
        return Double(normalized) ?? 0
    }

    // "007" -> "7", but a single "0" stays (and so does the 0 in "0.5")
    private static func stripLeadingZeros(_ digits: String) -> String {
        guard digits.count > 1 else { return digits }
        let stripped = digits.drop(while: { $0 == "0" })
        return stripped.isEmpty ? "0" : String(stripped)
    }
}
