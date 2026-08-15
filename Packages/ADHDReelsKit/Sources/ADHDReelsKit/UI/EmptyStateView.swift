import SwiftUI

/// Пустое состояние: иконка, объяснение и ровно одно действие.
/// Правило приложения — ни один экран не остаётся пустым без призыва к действию.
public struct EmptyStateView: View {

    public struct Action {
        public let title: String
        public let handler: () -> Void

        public init(title: String, handler: @escaping () -> Void) {
            self.title = title
            self.handler = handler
        }
    }

    let icon: String
    let title: String
    let message: String
    let action: Action?

    public init(icon: String, title: String, message: String, action: Action? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Theme.spacing * 2) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)

            VStack(spacing: Theme.spacing) {
                Text(title)
                    .font(Theme.title(20))
                    .foregroundStyle(Theme.primaryText)

                Text(message)
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if let action {
                Button(action.title, action: action.handler)
                    .font(Theme.body(16))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, Theme.spacing * 3)
                    .frame(height: Theme.minimumHitTarget)
                    .background(Theme.accent, in: .capsule)
            }
        }
        .padding(Theme.spacing * 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        icon: "text.bubble",
        title: "Пока пусто",
        message: "Выберите тред — и он превратится в ролик.",
        action: .init(title: "Выбрать тред") {}
    )
    .background(Theme.background)
}
