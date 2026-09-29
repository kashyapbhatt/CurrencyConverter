//
//  DateProviding.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation

/// Abstraction over the system clock. The refresh throttle and the staleness
/// banner both depend on "now", so tests need to be able to control it.
protocol DateProviding: Sendable {
    func now() -> Date
}

struct SystemDateProvider: DateProviding {
    func now() -> Date { Date() }
}
