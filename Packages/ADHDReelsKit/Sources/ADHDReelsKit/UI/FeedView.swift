import SwiftUI

struct FeedView: View {

    let onOpenSettings: () -> Void

    var body: some View {
        NavigationStack {
            EmptyStateView(
                icon: "text.bubble",
                title: "Лента пока не подключена",
                message: "Здесь появятся треды с Reddit, переведённые на русский.",
                action: .init(title: "Открыть настройку", handler: onOpenSettings)
            )
            .background(Theme.background)
            .navigationTitle("Треды")
        }
    }
}

#Preview {
    FeedView(onOpenSettings: {})
}
