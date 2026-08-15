import SwiftUI

struct QueueView: View {

    let onPickThread: () -> Void

    var body: some View {
        NavigationStack {
            EmptyStateView(
                icon: "square.stack.3d.down.right",
                title: "Пока пусто",
                message: "Выберите тред — и он превратится в ролик.",
                action: .init(title: "Выбрать тред", handler: onPickThread)
            )
            .background(Theme.background)
            .navigationTitle("Очередь")
        }
    }
}

#Preview {
    QueueView(onPickThread: {})
}
