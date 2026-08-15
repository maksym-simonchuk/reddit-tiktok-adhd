import SwiftUI

/// Панель: заливка, скругление и внутренний бордер в 1px. Теней в приложении нет.
public struct PanelModifier: ViewModifier {

    public func body(content: Content) -> some View {
        content
            .background(Theme.panel, in: .rect(cornerRadius: Theme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            }
    }
}

public extension View {
    func panel() -> some View { modifier(PanelModifier()) }
}
