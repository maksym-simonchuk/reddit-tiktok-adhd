import Observation
import SwiftUI
import Translation

/// Состояние всего приложения. Экраны его читают и дёргают методы — своего состояния,
/// кроме выделенной вкладки и открытого ролика, у них нет.
@MainActor
@Observable
public final class AppModel {

    public var settings = ReelSettings.load() {
        didSet { settings.save() }
    }

    public private(set) var posts: [RedditPost] = []
    public private(set) var isLoadingFeed = false

    /// Пока идёт сборка, здесь лежит пост и шаг. Обе величины нужны сразу: по посту
    /// подсвечивается строка в ленте, по шагу рисуется полоска.
    public private(set) var buildingPostID: String?
    public private(set) var progress: ReelProgress?

    public private(set) var clips: [GameplayClip] = []
    public let store = ReelStore()

    /// Свежий ролик: по нему лента предлагает перейти на вкладку с превью.
    public var lastCreated: Reel?
    public var error: String?
    public var toast: String?

    /// Пакет перевода не имеет отношения к языку системы и клавиатуры — он качается
    /// отдельно и только из вида: конфигурацию подхватывает `.translationTask`.
    public var needsTranslationPack = false
    public private(set) var translationRequest: TranslationSession.Configuration?

    @ObservationIgnored private let fetcher: RedditFetcher
    @ObservationIgnored private let gameplay: GameplayLibrary
    @ObservationIgnored private let pipeline: ReelPipeline
    @ObservationIgnored private var build: Task<Void, Never>?

    public init() {
        let fetcher = RedditFetcher()
        let gameplay = GameplayLibrary()

        self.fetcher = fetcher
        self.gameplay = gameplay
        self.pipeline = ReelPipeline(fetcher: fetcher, gameplay: gameplay)
    }

    public var isBuilding: Bool { buildingPostID != nil }

    // MARK: - Лента

    public func loadFeed(force: Bool = false) async {
        guard force || posts.isEmpty, !isLoadingFeed else { return }
        isLoadingFeed = true
        defer { isLoadingFeed = false }

        do {
            posts = try await fetcher.topPosts(
                subreddit: settings.subreddit,
                window: settings.window,
                minimumScore: settings.minimumScore
            )
        } catch {
            posts = []
            self.error = error.localizedDescription
        }
    }

    // MARK: - Сборка

    public func generate(_ post: RedditPost) {
        guard !isBuilding else { return }
        buildingPostID = post.id
        progress = ReelProgress(stage: .reading)

        build = Task {
            defer {
                buildingPostID = nil
                progress = nil
            }

            do {
                let reel = try await pipeline.make(
                    post: post,
                    settings: settings,
                    into: ReelStore.folder,
                    progress: { [weak self] step in
                        Task { @MainActor in self?.progress = step }
                    }
                )
                store.add(reel)
                lastCreated = reel
            } catch is CancellationError {
                return
            } catch Translator.Failure.packMissing {
                needsTranslationPack = true
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    public func cancelBuild() {
        build?.cancel()
    }

    // MARK: - Языковой пакет

    public func downloadTranslationPack() {
        translationRequest = TranslationSession.Configuration(
            source: Translator.source,
            target: Translator.target
        )
    }

    /// Сама сессия сюда не приезжает: она не `Sendable`, а качает её вид.
    public func finishTranslationPack(_ failure: String?) {
        error = failure
        if failure == nil { toast = "Языковой пакет готов" }
        translationRequest = nil
    }

    // MARK: - Готовые ролики

    public func saveToPhotos(_ reel: Reel) async {
        do {
            try await PhotoSaver.save(reel.url)
            toast = "Сохранено в «Фото»"
        } catch {
            self.error = error.localizedDescription
        }
    }

    public func copyDescription(_ reel: Reel) {
        UIPasteboard.general.string = reel.description.forClipboard
        toast = "Описание скопировано"
    }

    public func delete(_ reel: Reel) {
        store.delete(reel)
    }

    // MARK: - Геймплей

    public func refreshGameplay() async {
        do {
            clips = try await gameplay.refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    public func importGameplay(_ urls: [URL]) async {
        do {
            for url in urls { try await gameplay.import(url) }
        } catch {
            self.error = error.localizedDescription
        }
        await refreshGameplay()
    }

    public func deleteGameplay(_ clip: GameplayClip) async {
        do {
            try await gameplay.delete(clip)
            clips = await gameplay.clips()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
