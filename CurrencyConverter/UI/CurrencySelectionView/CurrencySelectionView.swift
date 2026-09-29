//
//  CurrencySelectionView.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import SwiftUI

struct CurrencySelectionView: View {
    @Bindable var viewModel: ConverterViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                let items = viewModel.pickerItems(matching: searchText)
                if items.isEmpty {
                    ContentUnavailableView(
                        "No matches",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different code or currency name.")
                    )
                } else {
                    List(items, id: \.code) { item in
                        Button {
                            viewModel.selectedCode = item.code
                            dismiss()
                        } label: {
                            row(code: item.code, name: item.name)
                        }
                        .listRowSeparator(.hidden)
                        .accessibilityIdentifier(AccessibilityID.pickerRow(item.code))
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("Search code or name")
            )
            .navigationTitle(Text("Select Currency"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(code: String, name: String) -> some View {
        let isSelected = code == viewModel.selectedCode

        return HStack(spacing: 14) {
            CurrencyBadge(code: code)

            VStack(alignment: .leading, spacing: 2) {
                Text(code)
                    .font(.subheadline.weight(.semibold))
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 4)
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
    }
}
