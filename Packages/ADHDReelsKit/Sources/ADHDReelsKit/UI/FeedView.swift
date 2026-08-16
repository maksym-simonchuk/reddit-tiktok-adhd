import SwiftUI

struct FeedView: View {

    let onShowReel: () -> Void

    @Environment(AppModel.self) private var model
    @State private var isAskingCustom = false
    @State private var customDraft = ""

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            content
                .background(Theme.background)
                .navigationTitle(ReelSettings.subredditTitle(model.settings.subreddit))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Лента живёт из кеша, пока не нажали сюда: Reddit блокирует
                    // устройство за частые анонимные запросы.
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await model.loadFeed(force: true, refresh: true) }
                        } label: {
                            if model.isLoadingFeed {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(model.isLoadingFeed)
                        .accessibilityLabel("Refresh feed")
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Subreddit", selection: $model.settings.subreddit) {
                                ForEach(menuSubreddits, id: \.self) {
                                    Text(ReelSettings.subredditTitle($0))
                                }
                            }
                            Picker("Period", selection: $model.settings.window) {
                                ForEach(ReelSettings.windows, id: \.self) {
                                    Text(ReelSettings.windowTitle($0))
                                }
                            }
                            Button("Custom subreddit…", systemImage: "plus") {
                                customDraft = ""
                                isAskingCustom = true
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
                .safeAreaInset(edge: .top) { chips }
                .safeAreaInset(edge: .bottom) { footer }
                .sheet(isPresented: isPreviewing) {
                    ScriptPreviewView(
                        thread: model.previewPost?.title ?? "",
                        lines: model.previewLines,
                        markedLine: model.markedLine,
                        markedWords: model.markedWords,
                        fixingLine: model.fixingLine,
                        isRewriting: model.isRewriting,
                        onMark: { model.mark(line: $0, word: $1) },
                        onFix: model.fixMarked,
                        onEdit: { model.edit($0, text: $1) },
                        onEngage: model.makeEngaging,
                        onGenerate: model.generateFromPreview,
                        onClose: model.closePreview
                    )
                }
                .alert("Custom subreddit", isPresented: $isAskingCustom) {
                    TextField("subreddit name", text: $customDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Show") {
                        if let name = Self.subredditName(from: customDraft) {
                            model.settings.subreddit = name
                        } else if !customDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            model.error = "That doesn't look like a subreddit name. Try \"tifu\" or paste a reddit.com link."
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Story-driven subreddits work best — the post body becomes the narration.")
                }
        }
        .task { await model.loadFeed() }
        .onChange(of: model.settings.subreddit) { Task { await model.loadFeed(force: true) } }
        .onChange(of: model.settings.window) { Task { await model.loadFeed(force: true) } }
        .onChange(of: model.settings.safeContentOnly) { Task { await model.loadFeed(force: true) } }
    }

    /// Свайп по шторке — тот же выход, что и кнопка: снять перевод с полпути и забыть.
    private var isPreviewing: Binding<Bool> {
        Binding(get: { model.previewPost != nil }, set: { if !$0 { model.closePreview() } })
    }

    /// People paste anything here: "tifu", "r/tifu", a full reddit.com link. A blind
    /// `replacingOccurrences(of: "r/")` mangled names and URLs alike, so the name is
    /// extracted properly — from the "/r/…" path segment or a bare word.
    // nonisolated: pure string parsing — the View conformance would otherwise drag
    // it onto the main actor and trap any off-main caller.
    nonisolated static func subredditName(from input: String) -> String? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if let match = text.firstMatch(of: #/(?:^|/)r/([A-Za-z0-9_]+)/#.ignoresCase()) {
            return String(match.1)
        }

        let bare = text.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !bare.isEmpty, bare.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else { return nil }
        return bare
    }

    /// The menu lists the classic suggestions plus every category subreddit, deduped;
    /// the current one stays listed even when it came from the custom field.
    private var menuSubreddits: [String] {
        var names = ReelSettings.suggestedSubreddits
        for category in StoryCategory.all {
            names += category.subreddits.filter { !names.contains($0) }
        }
        if !names.contains(model.settings.subreddit) {
            names.insert(model.settings.subreddit, at: 0)
        }
        return names
    }

    /// One-tap themes above the feed: a chip swaps the subreddit, the feed follows.
    private var chips: some View {
        @Bindable var model = model

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.spacing) {
                ForEach(StoryCategory.all) { category in
                    let isActive = StoryCategory.category(containing: model.settings.subreddit)?.id == category.id
                    Button {
                        model.settings.subreddit = category.primary
                    } label: {
                        Text(category.title)
                            .font(Theme.body(14))
                            .foregroundStyle(isActive ? Theme.background : Theme.primaryText)
                            .padding(.horizontal, Theme.spacing * 2)
                            .frame(height: 36)
                            .background(isActive ? Theme.accent : Theme.panel, in: .capsule)
                            .overlay {
                                if !isActive { Capsule().strokeBorder(Theme.separator, lineWidth: 1) }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.spacing * 2)
            .padding(.vertical, Theme.spacing)
        }
        .background(Theme.background)
    }

    @ViewBuilder
    private var content: some View {
        if model.posts.isEmpty {
            if model.isLoadingFeed {
                ProgressView().tint(Theme.accent).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyStateView(
                    icon: "text.bubble",
                    title: "No stories",
                    message: "Reddit returned nothing for these filters. Try another subreddit or period.",
                    action: .init(title: "Refresh") { Task { await model.loadFeed(force: true, refresh: true) } }
                )
            }
        } else {
            List(model.posts) { post in
                PostRow(
                    post: post,
                    targetDuration: model.settings.targetDuration,
                    language: model.settings.language,
                    isBuilding: model.buildingPostID == post.id,
                    isBlocked: model.isBuilding,
                    onGenerate: { model.generate(post) },
                    onPreview: { model.preview(post) }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: Theme.spacing / 2, leading: Theme.spacing * 2, bottom: Theme.spacing / 2, trailing: Theme.spacing * 2))
            }
            .listStyle(.plain)
            .refreshable { await model.loadFeed(force: true, refresh: true) }
        }
    }

    /// Полоска сборки и карточка «готово» живут в одном месте внизу: пользователь
    /// нажал кнопку в списке и смотрит туда же, куда нажал.
    @ViewBuilder
    private var footer: some View {
        if let progress = model.progress {
            BuildBanner(progress: progress, language: model.settings.language, onCancel: model.cancelBuild)
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
