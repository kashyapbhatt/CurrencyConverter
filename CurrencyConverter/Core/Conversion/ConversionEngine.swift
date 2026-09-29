//
//  ConversionEngine.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation

/// The free tier only serves USD-based rates, so everything goes through
/// USD:
///
///     converted = amount * rate[target] / rate[base]
///
/// USD needs no special case, rate["USD"] is 1.0.
struct ConversionEngine: Sendable {

    struct Conversion: Equatable, Sendable {
        let code: String
        let value: Double
    }

    init() {}

    /// nil when a rate is unusable or the result isn't finite; callers
    /// drop that row.
    func convert(amount: Double, from base: String, to target: String, rates: [String: Double]) -> Double? {
        guard base != target else { return amount }
        guard let baseRate = rates[base], isUsable(baseRate),
              let targetRate = rates[target], isUsable(targetRate) else {
            return nil
        }
        let converted = amount * targetRate / baseRate
        return converted.isFinite ? converted : nil
    }

    /// Sorted by code. Broken rates drop their row; a broken base rate
    /// throws, since nothing can be converted without it.
    func convertAll(amount: Double, base: String, rates: [String: Double]) throws -> [Conversion] {
        guard let baseRate = rates[base], isUsable(baseRate) else {
            throw NetworkError.conversionUnavailable
        }

        return rates.keys.sorted().compactMap { code in
            if code == base { return Conversion(code: code, value: amount) }
            guard let targetRate = rates[code], isUsable(targetRate) else { return nil }
            let value = amount * targetRate / baseRate
            return value.isFinite ? Conversion(code: code, value: value) : nil
        }
    }

    // finite and > 0; feeds do occasionally ship zero or negative rates
    private func isUsable(_ rate: Double) -> Bool {
        rate.isFinite && rate > 0
    }
}
