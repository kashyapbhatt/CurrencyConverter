//
//  AmountField.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import SwiftUI

struct AmountField: View {
    @Binding var text: String
    let currencyName: String
    let focus: FocusState<ConverterView.FocusedField?>.Binding

    var body: some View {
        TextField("1", text: $text)
            .keyboardType(.decimalPad)
            .font(.system(size: 40, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .focused(focus, equals: .amount)
            .accessibilityLabel("Amount in \(currencyName)")
            .accessibilityIdentifier(AccessibilityID.amountField)
    }
}
