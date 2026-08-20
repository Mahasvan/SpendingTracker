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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.results, id: \.id) { tx in
                    TransactionRowView(transaction: tx)
                }
                .listStyle(.inset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

            VStack(alignment: .leading, spacing: 4) {
                Text("Categories")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                categoriesChips
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Payment Methods")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                paymentMethodsChips
            }
        }
        .padding()
    }

    private var categoriesChips: some View {
        ScrollableChipStrip {
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

    private var paymentMethodsChips: some View {
        ScrollableChipStrip {
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

/// A horizontally scrolling strip of chips that shows leading/trailing chevron
/// affordances only when there is more content to scroll in that direction.
private struct ScrollableChipStrip<Content: View>: View {
    @ViewBuilder var content: Content

    @State private var contentWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0

    private let space = "chipStrip"

    var body: some View {
        HStack(spacing: 4) {
            edgeArrow("chevron.left", active: canScrollLeading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) { content }
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: ChipWidthKey.self, value: geo.size.width)
                                .preference(key: ChipOffsetKey.self, value: geo.frame(in: .named(space)).minX)
                        }
                    )
            }
            .coordinateSpace(.named(space))
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: ChipContainerWidthKey.self, value: geo.size.width)
                }
            )
            edgeArrow("chevron.right", active: canScrollTrailing)
        }
        .onPreferenceChange(ChipWidthKey.self) { contentWidth = $0 }
        .onPreferenceChange(ChipContainerWidthKey.self) { containerWidth = $0 }
        .onPreferenceChange(ChipOffsetKey.self) { scrollOffset = $0 }
        .frame(height: 32)
        .animation(.easeInOut(duration: 0.15), value: canScrollLeading)
        .animation(.easeInOut(duration: 0.15), value: canScrollTrailing)
    }

    private var canScrollLeading: Bool { scrollOffset < -1 }

    private var canScrollTrailing: Bool {
        contentWidth - containerWidth + scrollOffset > 1
    }

    private func edgeArrow(_ systemName: String, active: Bool) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(active ? Color.accentColor : Color.secondary.opacity(0.25))
            .frame(width: 12)
            .allowsHitTesting(false)
    }
}

private struct ChipWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct ChipContainerWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct ChipOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

#if DEBUG
@MainActor
private struct SearchViewPreview: View {
    let vm: SearchViewModel
    init() {
        let container = PreviewSupport.makeContainer()
        _ = PreviewSupport.seedSampleTransactions(in: container.modelContainer)
        vm = SearchViewModel(
            repo: container.transactionRepo,
            categoryRepo: container.categoryRepo,
            pmRepo: container.paymentMethodRepo
        )
    }
    var body: some View {
        NavigationStack { SearchView(viewModel: vm) }
            .frame(width: 600, height: 500)
    }
}

#Preview { SearchViewPreview() }
#endif
