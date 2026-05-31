import SwiftUI
import AppKit

enum SymbolLibrary {
    static func isValid(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return NSImage(systemSymbolName: trimmed, accessibilityDescription: nil) != nil
    }

    static let curated: [String] = [
        // Money & finance
        "indianrupeesign", "indianrupeesign.circle", "indianrupeesign.square",
        "dollarsign", "dollarsign.circle", "eurosign", "yensign", "sterlingsign",
        "creditcard", "creditcard.fill", "banknote", "banknote.fill",
        "wallet.pass", "wallet.pass.fill", "wallet.bifold", "wallet.bifold.fill",
        "building.columns", "building.columns.fill",
        "chart.pie", "chart.pie.fill", "chart.bar", "chart.line.uptrend.xyaxis",
        "percent", "tag", "tag.fill", "tag.circle", "tag.circle.fill",
        "gift", "gift.fill",
        // Food & drink
        "fork.knife", "fork.knife.circle", "fork.knife.circle.fill",
        "cup.and.saucer", "cup.and.saucer.fill",
        "wineglass", "wineglass.fill", "mug", "mug.fill",
        "carrot", "carrot.fill", "birthday.cake", "birthday.cake.fill",
        "takeoutbag.and.cup.and.straw", "takeoutbag.and.cup.and.straw.fill",
        // Transport
        "car", "car.fill", "bus", "bus.fill", "tram", "tram.fill",
        "airplane", "airplane.departure", "airplane.arrival",
        "bicycle", "fuelpump", "fuelpump.fill",
        "ferry", "ferry.fill", "train.side.front.car",
        // Home & utilities
        "house", "house.fill", "house.circle", "lightbulb", "lightbulb.fill",
        "drop", "drop.fill", "flame", "flame.fill",
        "wifi", "antenna.radiowaves.left.and.right",
        "wrench.and.screwdriver", "wrench.and.screwdriver.fill",
        "hammer", "hammer.fill", "paintbrush", "paintbrush.fill",
        // Shopping
        "cart", "cart.fill", "bag", "bag.fill", "basket", "basket.fill",
        "shippingbox", "shippingbox.fill", "gift.circle", "gift.circle.fill",
        // Health
        "cross.case", "cross.case.fill", "pills", "pills.fill",
        "heart", "heart.fill", "stethoscope", "stethoscope.circle",
        "dumbbell", "dumbbell.fill",
        // Education
        "book", "book.fill", "books.vertical", "books.vertical.fill",
        "graduationcap", "graduationcap.fill", "pencil", "pencil.tip",
        // Entertainment
        "tv", "tv.fill", "gamecontroller", "gamecontroller.fill",
        "headphones", "music.note", "film", "film.fill",
        "popcorn", "popcorn.fill", "ticket", "ticket.fill",
        // Tech / work
        "laptopcomputer", "desktopcomputer", "iphone", "ipad",
        "printer", "printer.fill", "keyboard", "mouse", "mouse.fill",
        "briefcase", "briefcase.fill", "person.crop.rectangle.stack",
        // Travel
        "suitcase", "suitcase.fill", "bed.double", "bed.double.fill",
        "map", "map.fill", "tent", "tent.fill",
        // Pet & misc
        "pawprint", "pawprint.fill", "leaf", "leaf.fill", "tree", "tree.fill",
        "scissors", "comb", "comb.fill",
        // Generic
        "star", "star.fill", "circle", "circle.fill", "square", "square.fill",
        "questionmark", "questionmark.circle", "questionmark.circle.fill",
        "exclamationmark", "exclamationmark.circle",
        "person", "person.fill", "person.2", "person.2.fill",
        "calendar", "calendar.circle", "clock", "clock.fill",
        "bell", "bell.fill", "envelope", "envelope.fill",
        "phone", "phone.fill", "message", "message.fill",
        "folder", "folder.fill", "doc", "doc.fill", "tray", "tray.fill",
        "bookmark", "bookmark.fill", "flag", "flag.fill"
    ]

    static func filtered(_ query: String) -> [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return curated }
        return curated.filter { $0.lowercased().contains(q) }
    }
}

struct SymbolPicker: View {
    @Binding var symbolName: String
    var tintColor: Color = .secondary

    @State private var showGrid = true

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                symbolPreview
                TextField("SF Symbol name", text: $symbolName)
                    .textFieldStyle(.roundedBorder)
                validityBadge
                Button {
                    showGrid.toggle()
                } label: {
                    Image(systemName: showGrid ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.borderless)
                .help(showGrid ? "Hide symbol grid" : "Show symbol grid")
            }

            if showGrid {
                grid
            }
        }
    }

    @ViewBuilder
    private var grid: some View {
        let matches = SymbolLibrary.filtered(symbolName)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(matches.isEmpty ? "No matches in library" : "\(matches.count) symbols")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !symbolName.isEmpty,
                   SymbolLibrary.isValid(symbolName),
                   !matches.contains(symbolName) {
                    Button("Use \"\(symbolName)\"") { /* already typed */ }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .disabled(true)
                        .help("This name is valid even though it's not in the curated list. You can just keep typing.")
                }
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(matches, id: \.self) { name in
                        symbolCell(name: name)
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: 160)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func symbolCell(name: String) -> some View {
        let selected = (name == symbolName)
        Button {
            symbolName = name
        } label: {
            Image(systemName: name)
                .font(.title3)
                .foregroundStyle(selected ? Color.white : tintColor)
                .frame(width: 44, height: 32)
                .background(cellBackground(selected: selected))
        }
        .buttonStyle(.plain)
        .help(name)
    }

    @ViewBuilder
    private func cellBackground(selected: Bool) -> some View {
        if selected {
            RoundedRectangle(cornerRadius: 6).fill(tintColor)
        } else {
            RoundedRectangle(cornerRadius: 6).fill(.background.tertiary)
        }
    }

    @ViewBuilder
    private var symbolPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(.background.secondary)
                .frame(width: 36, height: 28)
            if SymbolLibrary.isValid(symbolName) {
                Image(systemName: symbolName)
                    .foregroundStyle(tintColor)
            } else {
                Image(systemName: "questionmark")
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var validityBadge: some View {
        if symbolName.trimmingCharacters(in: .whitespaces).isEmpty {
            EmptyView()
        } else if SymbolLibrary.isValid(symbolName) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .help("Valid SF Symbol")
        } else {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .help("Not a recognized SF Symbol")
        }
    }
}
