//
//  ConverterView.swift
//  CurrencyConverter
//
//  Created by Kashyap Bhatt on 05/08/26.
//

import SwiftUI

struct ConverterView: View {

    enum FocusedField: Hashable {
        case amount
        case filter
    }

    @Bindable var viewModel: ConverterViewModel

    @AppStorage(Theme.storageKey) private var appearanceRawValue = Theme.system.rawValue
    @State private var isShowingPicker = false
    @FocusState private var focusedField: FocusedField?

    var body: some View {
        NavigationStack {
            ZStack {
                background

                switch viewModel.viewState {
                case .skeleton:
                    SkeletonView()
                case .error(let error):
                    ErrorView(error: error, isRetrying: viewModel.isRetrying) {
                        Task { await viewModel.retry() }
                    }
                case .content:
                    content
                }
            }
            .navigationTitle(Text("Currency Converter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { appearanceMenu }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
        .task { await viewModel.load() }
        .task { await viewModel.observeConnectivity() }
        // changing the id cancels the previous run, which is the debounce
        .task(id: viewModel.amountText) { await viewModel.debouncedRecompute() }
        .sheet(isPresented: $isShowingPicker) {
            CurrencySelectionView(viewModel: viewModel)
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [Color.accentColor.opacity(0.14), Color.clear],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
    }

    // MARK: Content

    private var content: some View {
        VStack(spacing: 12) {
            amountCard
                .padding(.horizontal)

            searchField
                .padding(.horizontal)

            List {
                ForEach(viewModel.rows) { row in
                    CurrencyRow(row: row)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .refreshable { await viewModel.refresh() }
            .overlay {
                if viewModel.rows.isEmpty, !viewModel.filterText.isEmpty {
                    ContentUnavailableView(
                        "No matches",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different code or currency name.")
                    )
                }
            }
        }
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                CurrencyChip(code: viewModel.selectedCode, name: viewModel.selectedCurrencyName) {
                    isShowingPicker = true
                }
                AmountField(
                    text: $viewModel.amountText,
                    currencyName: viewModel.selectedCurrencyName,
                    focus: $focusedField
                )
            }

            Divider()

            HStack {
                Text(viewModel.showsUnitRates
                     ? "Rates for 1 \(viewModel.selectedCode)"
                     : viewModel.selectedCurrencyName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let banner = viewModel.banner {
                    StatusBannerView(state: banner)
                }
            }
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.quaternary, lineWidth: 1)
        )
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.footnote)
            TextField("Filter currencies", text: $viewModel.filterText)
                .font(.subheadline)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focusedField, equals: .filter)
                .accessibilityIdentifier(AccessibilityID.filterField)
            if !viewModel.filterText.isEmpty {
                Button {
                    viewModel.filterText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
                .accessibilityLabel("Clear filter")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.background.secondary, in: Capsule())
        .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 1))
    }

    // MARK: Appearance menu

    private var appearanceMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Appearance", selection: $appearanceRawValue) {
                    ForEach(Theme.allCases, id: \.rawValue) { appearance in
                        Label(appearance.label, systemImage: appearance.iconName)
                            .tag(appearance.rawValue)
                    }
                }
            } label: {
                Image(systemName: currentAppearance.iconName)
            }
            // label tracks the mode so VoiceOver hears the current state
            .accessibilityLabel("Appearance: \(currentAppearance.label)")
        }
    }

    private var currentAppearance: Theme {
        Theme(rawValue: appearanceRawValue) ?? .system
    }
}
