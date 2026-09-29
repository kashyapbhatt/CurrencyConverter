//
//  CurrencyFlag.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation

enum CurrencyFlag {

    /// ISO 4217 codes are a country code plus a letter, so the first two
    /// characters give the flag. Codes starting with X are metals, funds and
    /// multi-country currencies with no flag of their own, and crypto has
    /// none either; those get nil and the UI falls back to a monogram.
    static func emoji(for code: String) -> String? {
        guard !crypto.contains(code) else { return nil }

        let country = String(code.prefix(2)).uppercased()
        guard country.count == 2, country.first != "X" else { return nil }

        var flag = ""
        for scalar in country.unicodeScalars {
            guard let indicator = UnicodeScalar(127_397 + scalar.value) else { return nil }
            flag.unicodeScalars.append(indicator)
        }
        return flag
    }

    private static let crypto: Set<String> = ["BTC", "ETH", "LTC", "DOGE", "XRP", "BCH"]
}
