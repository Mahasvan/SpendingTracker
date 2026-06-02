import SwiftUI

/// A masonry layout that arranges its subviews into a fixed number of equal-width
/// columns, placing each subview into whichever column is currently shortest.
/// This keeps the columns balanced in height regardless of individual widget sizes.
struct MasonryHStack: Layout {
    var columns: Int
    var spacing: CGFloat

    init(columns: Int = 2, spacing: CGFloat = 16) {
        self.columns = max(1, columns)
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 0
        let result = computeLayout(width: width, subviews: subviews)
        return CGSize(width: width, height: result.totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let result = computeLayout(width: bounds.width, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private func computeLayout(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], totalHeight: CGFloat) {
        let cols = max(1, columns)
        let totalSpacing = spacing * CGFloat(cols - 1)
        let columnWidth = max(0, (width - totalSpacing) / CGFloat(cols))
        var columnHeights = Array(repeating: CGFloat(0), count: cols)
        var frames: [CGRect] = []

        for subview in subviews {
            let height = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
            let target = columnHeights.indices.min(by: { columnHeights[$0] < columnHeights[$1] }) ?? 0
            let x = CGFloat(target) * (columnWidth + spacing)
            let y = columnHeights[target]
            frames.append(CGRect(x: x, y: y, width: columnWidth, height: height))
            columnHeights[target] += height + spacing
        }

        let tallest = columnHeights.max() ?? 0
        let totalHeight = frames.isEmpty ? 0 : max(0, tallest - spacing)
        return (frames, totalHeight)
    }
}
