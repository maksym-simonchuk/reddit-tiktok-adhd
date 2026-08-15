import SwiftUI

struct FeedView: View {

    let onShowReel: () -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            content
                .background(Theme.background)
                .navigationTitle(model.settings.subreddit)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Подреддит", selection: $model.settings.subreddit) {
                                ForEach(ReelSettings.suggestedSubreddits, id: \.self) { Text($0) }
                            }
                            Picker("Период", selection: $model.settings.window) {
                                ForEach(ReelSettings.windows, id: \.self) {
                                    Text(ReelSettings.windowTitle($0))
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) { footer }
        }
        .task { await model.loadFeed() }
        .onChange(of: model.settings.subreddit) { Task { await model.loadFeed(force: true) } }
        .onChange(of: model.settings.window) { Task { await model.loadFeed(force: true) } }
    }

    @ViewBuilder
    private var content: some View {
        if model.posts.isEmpty {
            if model.isLoadingFeed {
                ProgressView().tint(Theme.accent).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyStateView(
                    icon: "text.bubble",
                    title: "Тредов нет",
                    message: "Reddit ничего не отдал по этим фильтрам. Смените подреддит или период.",
                    action: .init(title: "Обновить") { Task { await model.loadFeed(force: true) } }
                )
            }
        } else {
            List(model.posts) { post in
                PostRow(
                    post: post,
                    isBuilding: model.buildingPostID == post.id,
                    isBlocked: model.isBuilding,
                    onGenerate: { model.generate(post) }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: Theme.spacing / 2, leading: Theme.spacing * 2, bottom: Theme.spacing / 2, trailing: Theme.spacing * 2))
            }
            .listStyle(.plain)
            .refreshable { await model.loadFeed(force: true) }
        }
    }

    /// Полоска сборки и карточка «готово» живут в одном месте внизу: пользователь
    /// нажал кнопку в списке и смотрит туда же, куда нажал.
    @ViewBuilder
    private var footer: some View {
        if let progress = model.progress {
            BuildBanner(progress: progress, onCancel: model.cancelBuild)
                .padding(Theme.spacing * 2)
        } else if let reel = model.lastCreated {
            ReadyBanner(reel: reel, onOpen: onShowReel)
                .padding(Theme.spacing * 2)
        }
    }
}

#Preview {
    FeedView(onShowReel: {})
        .environment(AppModel())
}
