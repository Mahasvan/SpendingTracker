import SwiftUI

struct SearchView: View {
    @State var viewModel: SearchViewModel
    @State private var hasDateFrom = false
    @State private var hasDateTo = false
    @State private var minAmountStr = ""
    @State private var maxAmountStr = ""

    var body: some View {
        VStack(spacing: 0) {
            filterPanel
            Divider()
            if viewModel.results.isEmpty {
                ContentUnavailableView(
                    "No matches",
                    systemImage: "magnifyingglass",
                    description: Text("Adjust filters and try again.")
                )
            } else {
                List(viewModel.results, id: \.id) { tx in
                    TransactionRowView(transaction: tx)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Search")
        .onAppear {
            viewModel.loadFilters()
            viewModel.search()
        }
        .onChange(of: viewModel.query) { _, _ in viewModel.search() }
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Search notes, categories, payment methods…", text: $viewModel.query)
                    .textFieldStyle(.roundedBorder)
                Button("Reset") { viewModel.reset(); hasDateFrom = false; hasDateTo = false; minAmountStr = ""; maxAmountStr = "" }
            }
            HStack(spacing: 12) {
                Picker("Type", selection: $viewModel.type) {
                    Text("Any").tag(TxType?.none)
                    ForEach(TxType.allCases) { Text($0.displayName).tag(Optional($0)) }
                }
                .frame(width: 200)

                Toggle("From", isOn: $hasDateFrom)
                if hasDateFrom {
                    DatePicker("", selection: Binding(
                        get: { viewModel.dateFrom ?? .now },
                        set: { viewModel.dateFrom = $0 }
                    ), displayedComponents: .date).labelsHidden()
                }
                Toggle("To", isOn: $hasDateTo)
                if hasDateTo {
                    DatePicker("", selection: Binding(
                        get: { viewModel.dateTo ?? .now },
                        set: { viewModel.dateTo = $0 }
                    ), displayedComponents: .date).labelsHidden()
                }
            }
            .onChange(of: hasDateFrom) { _, v in if !v { viewModel.dateFrom = nil }; viewModel.search() }
            .onChange(of: hasDateTo) { _, v in if !v { viewModel.dateTo = nil }; viewModel.search() }
            .onChange(of: viewModel.type) { _, _ in viewModel.search() }
            .onChange(of: viewModel.dateFrom) { _, _ in viewModel.search() }
            .onChange(of: viewModel.dateTo) { _, _ in viewModel.search() }

            HStack {
                TextField("Min amount", text: $minAmountStr)
                    .frame(width: 140)
                TextField("Max amount", text: $maxAmountStr)
                    .frame(width: 140)
            }
            .onChange(of: minAmountStr) { _, v in
                viewModel.minAmount = CurrencyFormatter.parse(v)
                viewModel.search()
            }
            .onChange(of: maxAmountStr) { _, v in
                viewModel.maxAmount = CurrencyFormatter.parse(v)
                viewModel.search()
            }

            categoriesChips
            paymentMethodsChips
        }
        .padding()
    }

    private var categoriesChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(viewModel.categories, id: \.id) { c in
                    let selected = viewModel.selectedCategoryIds.contains(c.id)
                    Button {
                        if selected { viewModel.selectedCategoryIds.remove(c.id) }
                        else { viewModel.selectedCategoryIds.insert(c.id) }
                        viewModel.search()
                    } label: {
                        Label(c.name, systemImage: c.systemImage)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(selected ? Color(hex: c.colorHex).opacity(0.3) : Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var paymentMethodsChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(viewModel.paymentMethods, id: \.id) { pm in
                    let selected = viewModel.selectedPMIds.contains(pm.id)
                    Button {
                        if selected { viewModel.selectedPMIds.remove(pm.id) }
                        else { viewModel.selectedPMIds.insert(pm.id) }
                        viewModel.search()
                    } label: {
                        Label(pm.name, systemImage: pm.kind.systemImage)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(selected ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
