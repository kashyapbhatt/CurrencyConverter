//
//  AccessibilityID.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import Foundation

/// Mirrored by hand in the UI test target, which can't import the app.
enum AccessibilityID {
    static let amountField = "amountField"
    static let currencyChip = "currencyChip"
    static let filterField = "filterField"

    // row ids carry the code: row_JPY, pickerRow_JPY
    static func row(_ code: String) -> String { "row_\(code)" }
    static func pickerRow(_ code: String) -> String { "pickerRow_\(code)" }
}
