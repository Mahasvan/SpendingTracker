import SwiftUI

struct ChatSuggestion: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let prompt: String

    static let defaults: [ChatSuggestion] = [
        ChatSuggestion(
            id: "log_expense",
            title: "Log an expense",
            systemImage: "plus.circle",
            prompt: "Add expense for today - Rs. "
        ),
        ChatSuggestion(
            id: "month_overview",
            title: "This month at a glance",
            systemImage: "chart.pie",
            prompt: "How much have I spent this month, broken down by category?"
        ),
        ChatSuggestion(
            id: "budget_check",
            title: "Budget check",
            systemImage: "gauge.with.dots.needle.50percent",
            prompt: "Am I on track with my budgets this month? Flag any I'm close to or over."
        ),
        ChatSuggestion(
            id: "top_spends",
            title: "Top spends",
            systemImage: "chart.bar",
            prompt: "Show my 5 biggest expenses this month."
        ),
        ChatSuggestion(
            id: "compare_months",
            title: "Compare months",
            systemImage: "arrow.left.arrow.right",
            prompt: "Compare this month's spending to last month, by category."
        ),
        ChatSuggestion(
            id: "find_tx",
            title: "Find a transaction",
            systemImage: "magnifyingglass",
            prompt: "Find my last grocery transaction."
        )
    ]
}

struct ChatSuggestionsView: View {
    let suggestions: [ChatSuggestion]
    let onSelect: (ChatSuggestion) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            header
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(suggestions) { s in
                    SuggestionCard(suggestion: s) { onSelect(s) }
                }
            }
            .frame(maxWidth: 560)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.title)
                .foregroundStyle(.tint)
            Text("How can I help with your spending?")
                .font(.title3.weight(.semibold))
            Text("Pick a starter prompt or type your own.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }
}

private struct SuggestionCard: View {
    let suggestion: ChatSuggestion
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: suggestion.systemImage)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8).fill(.tint.opacity(0.12))
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(suggestion.prompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(hovering ? Color.secondary.opacity(0.18) : Color.secondary.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.separator, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(suggestion.prompt)
    }
}
