import SwiftUI

/// Слова переносятся, как в тексте, но каждое остаётся отдельным видом: иначе не ткнуть
/// пальцем в кусок, который модель перевела неверно. У `HStack` переноса нет.
struct FlowLayout: Layout {

    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let limit = proposal.width ?? .infinity
        var x: CGFloat = 0
        var height: CGFloat = 0
        var line: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > limit, x > 0 {
                x = 0
                height += line + spacing
                line = 0
            }
            x += size.width + spacing
            line = max(line, size.height)
        }

        return CGSize(width: limit == .infinity ? x : limit, height: height + line)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var line: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += line + spacing
                line = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            line = max(line, size.height)
        }
    }
}
