import SwiftUI

struct ReelsView: View {

    @Environment(AppModel.self) private var model
    @State private var path: [Reel] = []
    @State private var renaming: Reel?
    @State private var renameDraft = ""

    var body: some View {
        NavigationStack(path: $path) {
            content
                .background(Theme.background)
                .navigationTitle("Projects")
                .navigationDestination(for: Reel.self) { ReelDetailView(reel: $0) }
        }
        .onAppear {
            // Свежесобранный ролик открывается сам: пользователь нажал «Смотреть»,
            // и лишний тап по списку тут ничего не добавляет.
            guard let reel = model.lastCreated else { return }
            model.lastCreated = nil
            path = [reel]
        }
        .alert("Rename", isPresented: isRenaming) {
            TextField("Title", text: $renameDraft)
            Button("Save") {
                if let reel = renaming { model.rename(reel, to: renameDraft) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    private var isRenaming: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    @ViewBuilder
    private var content: some View {
        if model.store.reels.isEmpty && !model.isBuilding && model.failedJob == nil {
            EmptyStateView(
                icon: "play.rectangle",
                title: "No videos yet",
                message: "Open Discover and tap Generate Video — the finished Short lands here."
            )
        } else {
            List {
                // Live statuses on top: the library shows what is in flight,
                // not only what already exists on disk.
                if let progress = model.progress {
                    statusRow(
                        icon: "gearshape.2.fill",
                        tint: Theme.accent,
                        title: "Generating…",
                        subtitle: progress.title
                    ) { ProgressView().controlSize(.small).tint(Theme.accent) }
                }

                if let job = model.failedJob {
                    statusRow(
                        icon: "exclamationmark.triangle.fill",
                        tint: Theme.danger,
                        title: "Failed: \(job.post.title)",
                        subtitle: model.failedReason ?? ""
                    ) {
                        Button("Retry") { model.retryFailed() }
                            .font(Theme.body(14))
                            .foregroundStyle(Theme.accent)
                            .buttonStyle(.plain)
                    }
                }

                ForEach(model.store.reels) { reel in
                    NavigationLink(value: reel) {
                        ReelRow(reel: reel)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) { model.delete(reel) }
                        Button("Rename") {
                            renameDraft = reel.title
                            renaming = reel
                        }
                        .tint(.indigo)
                    }
                    .swipeActions(edge: .leading) {
                        Button("Duplicate", systemImage: "plus.square.on.square") {
                            model.duplicate(reel)
                        }
                        .tint(Theme.success)
                        Button("Export", systemImage: "square.and.arrow.down") {
                            Task { await model.saveToPhotos(reel) }
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func statusRow(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        HStack(spacing: Theme.spacing * 1.5) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Theme.numeric(13))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            trailing()
        }
        .padding(Theme.spacing * 1.5)
        .panel()
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

#Preview {
    ReelsView().environment(AppModel())
}
