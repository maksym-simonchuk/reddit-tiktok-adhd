import SwiftUI

struct ReelsView: View {

    @Environment(AppModel.self) private var model
    @State private var path: [Reel] = []

    var body: some View {
        NavigationStack(path: $path) {
            content
                .background(Theme.background)
                .navigationTitle("Ролики")
                .navigationDestination(for: Reel.self) { ReelDetailView(reel: $0) }
        }
        .onAppear {
            // Свежесобранный ролик открывается сам: пользователь нажал «Смотреть»,
            // и лишний тап по списку тут ничего не добавляет.
            guard let reel = model.lastCreated else { return }
            model.lastCreated = nil
            path = [reel]
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.store.reels.isEmpty {
            EmptyStateView(
                icon: "play.rectangle",
                title: "Роликов пока нет",
                message: "Откройте «Треды» и нажмите «Сделать ролик» — готовое видео появится здесь."
            )
        } else {
            List {
                ForEach(model.store.reels) { reel in
                    NavigationLink(value: reel) {
                        ReelRow(reel: reel)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions {
                        Button("Удалить", role: .destructive) { model.delete(reel) }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

#Preview {
    ReelsView().environment(AppModel())
}
