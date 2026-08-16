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

    /// Открытая вычитка перевода: тред и пары «оригинал — перевод» (пока пусто — модель
    /// ещё считает). Ниже — строка и слова в ней, которые человек отметил как враньё,
    /// и строка, которую модель прямо сейчас переписывает.
    public private(set) var previewPost: RedditPost?
    public private(set) var previewLines: [TranslatedLine] = []
    public private(set) var markedLine: Int?
    public private(set) var markedWords: Set<Int> = []
    public private(set) var fixingLine: Int?
    public private(set) var isRewriting = false

    /// A build that failed, kept for Retry. In memory only: the on-disk job is cleared
    /// so a background wake never loops a failing render.
    public private(set) var failedJob: RenderJob?
    public private(set) var failedReason: String?

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
    @ObservationIgnored private var read: Task<Void, Never>?
    @ObservationIgnored private var edits = ScriptEdits.load()

    public init() {
        let gameplay = GameplayLibrary()

        self.fetcher = RedditFetcher()
        self.gameplay = gameplay
        self.pipeline = ReelPipeline(gameplay: gameplay)
    }

    public var isBuilding: Bool { buildingPostID != nil }

    // MARK: - Лента

    /// `force` — перечитать ленту под новые фильтры, `refresh` — сходить за ней в сеть.
    /// Смена подреддита кеш не выбрасывает: туда-сюда переключаются часто, а Reddit
    /// за частые запросы блокирует.
    public func loadFeed(force: Bool = false, refresh: Bool = false) async {
        guard force || refresh || posts.isEmpty, !isLoadingFeed else { return }
        isLoadingFeed = true
        defer { isLoadingFeed = false }

        do {
            let fetched = try await fetcher.topPosts(
                subreddit: settings.subreddit,
                window: settings.window,
                allowNSFW: !settings.safeContentOnly,
                minimumScore: settings.minimumScore,
                refresh: refresh
            )
            posts = settings.safeContentOnly ? fetched.filter { SafetyFilter.isSafe($0) } : fetched

            // The RSS fallback carries no NSFW flag, so safe mode is down to the
            // text screen alone — say so rather than filter silently at half strength.
            if settings.safeContentOnly, await fetcher.lastFetchUsedRSS, !posts.isEmpty {
                toast = "Reddit sent limited data — NSFW labels can't be verified right now."
            }
        } catch {
            // Ушли с вкладки — SwiftUI снял `.task`, и запрос оборвался на середине.
            // Это не сбой: ни ленту чистить, ни пугать человека алертом не за что.
            guard !Task.isCancelled else { return }
            posts = []
            self.error = error.localizedDescription
        }
    }

    // MARK: - Сборка

    public func generate(_ post: RedditPost) {
        // Вычитка держит ту же модель на 2 ГБ — вдвоём они в память не влезут.
        guard !isBuilding, previewPost == nil else { return }

        let job = RenderJob(
            post: post,
            approved: edits[ScriptEdits.key(post.id, settings.language)]?
                .map { ScriptSegment(kind: $0.kind, text: $0.translation) },
            settings: settings
        )
        job.keep()
        start(job)
    }

    /// Generate straight from the open story editor: the reviewed text becomes the
    /// approved script, so the pipeline narrates exactly what is on screen.
    public func generateFromPreview() {
        guard let post = previewPost else { return }
        if !previewLines.isEmpty { keep(quiet: true) }
        closePreview()
        generate(post)
    }

    /// Rebuild a finished reel with the current settings — new voice, captions or
    /// duration without hunting for the story in the feed again.
    public func regenerate(_ reel: Reel) {
        guard let post = reel.post else {
            error = "This video predates regeneration — its source story wasn't saved."
            return
        }
        generate(post)
    }

    public func retryFailed() {
        guard !isBuilding, let job = failedJob else { return }
        failedJob = nil
        failedReason = nil
        job.keep()
        start(job)
    }

    public func dismissFailed() {
        failedJob = nil
        failedReason = nil
    }

    /// Сборка, начатая до сворачивания или до убийства процесса. Шаги с середины
    /// не подхватываются: ни озвучка, ни монтаж не умеют продолжаться, поэтому
    /// ролик считается заново.
    public func resume() {
        guard !isBuilding, previewPost == nil, let job = RenderJob.saved() else { return }
        start(job)
    }

    /// Точка входа для `BGProcessingTask`: система разбудила процесс и ждёт, пока
    /// сборка закончится или её отменят по истечении времени.
    public func renderInBackground() async {
        resume()
        await build?.value
    }

    public func cancelBuild() {
        // Руками отменённую сборку возобновлять незачем — в отличие от отмены
        // по времени, которую присылает система.
        RenderJob.clear()
        build?.cancel()
    }

    private func start(_ job: RenderJob) {
        // A new build replaces the failure card; keeping the old one around would
        // show "Failed" and "Generating" for the same story at once.
        failedJob = nil
        failedReason = nil
        buildingPostID = job.post.id
        progress = ReelProgress(stage: .reading)

        build = Task {
            defer {
                buildingPostID = nil
                progress = nil
            }

            do {
                let reel = try await pipeline.make(
                    post: job.post,
                    approved: job.approved,
                    settings: job.settings,
                    into: ReelStore.folder,
                    progress: { [weak self] step in
                        Task { @MainActor in self?.progress = step }
                    }
                )
                RenderJob.clear()
                store.add(reel)
                lastCreated = reel
            } catch is CancellationError {
                // Время в фоне вышло. Файл работы не трогаем: доделает следующее
                // пробуждение или открытое приложение.
                return
            } catch Translator.Failure.packMissing {
                RenderJob.clear()
                needsTranslationPack = true
            } catch {
                // Retry restarts the same job from the failure card; the disk copy
                // still goes, so a background wake never replays a failing build.
                RenderJob.clear()
                failedJob = job
                failedReason = error.localizedDescription
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Вычитка перевода

    public func preview(_ post: RedditPost) {
        guard !isBuilding, previewPost == nil else { return }
        previewPost = post
        clearMark()

        // Вычитанный текст показываем как есть: он уже правленый, и второй перевод
        // затёр бы правки.
        if let saved = edits[ScriptEdits.key(post.id, settings.language)] {
            previewLines = saved
            return
        }

        previewLines = []
        read = Task {
            do {
                previewLines = try await pipeline.preview(post: post, settings: settings)
            } catch {
                // Закрыли шторку на середине перевода — это не сбой, а отмена.
                guard !Task.isCancelled else { return }
                previewPost = nil
                self.error = error.localizedDescription
            }
        }
    }

    public func closePreview() {
        read?.cancel()
        previewPost = nil
        previewLines = []
        clearMark()
    }

    /// Мелкая правка руками: буква, окончание, запятая. Такое быстрее написать, чем
    /// объяснять модели.
    public func edit(_ line: TranslatedLine, text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let index = previewLines.firstIndex(where: { $0.id == line.id }) else { return }

        previewLines[index] = TranslatedLine(
            id: line.id,
            kind: line.kind,
            source: line.source,
            translation: text
        )
        keep()
    }

    /// Тычок в слово. Отмечать можно только в одной строке: правится она целиком,
    /// и куски из разных предложений модели не объяснить.
    public func mark(line: TranslatedLine, word: Int) {
        if markedLine != line.id {
            markedLine = line.id
            markedWords = []
        }

        if markedWords.contains(word) {
            markedWords.remove(word)
        } else {
            markedWords.insert(word)
        }

        if markedWords.isEmpty { markedLine = nil }
    }

    public func fixMarked() {
        // `read` is shared with makeEngaging(); two writers over previewLines at
        // once would race, so each waits the other out.
        guard fixingLine == nil, !isRewriting, let marked = markedLine, !markedWords.isEmpty,
              let index = previewLines.firstIndex(where: { $0.id == marked })
        else { return }

        // Правку ведёт та же модель, что переводит на русский, и подсказка у неё
        // русская. Для других языков перевод идёт Apple Translation — переписать
        // отдельное предложение там нечем.
        guard settings.language == .russian else {
            error = "Word-level fixes only work with Russian narration."
            clearMark()
            return
        }

        let line = previewLines[index]

        // Крючок и вопрос зрителю — не перевод, а сочинение по рассказу: сверять их не с чем,
        // и модель на просьбу «переведи заново» вернула бы пересказ вместо правки.
        guard !line.source.isEmpty else {
            error = "This line was written by the model, not translated — edit it with the pencil."
            clearMark()
            return
        }

        let wrong = line.fragment(markedWords)
        fixingLine = marked
        clearMark()

        read?.cancel()
        read = Task {
            defer { fixingLine = nil }

            do {
                let fixed = try await LLMTranslator().retranslate(
                    source: line.source,
                    previous: line.translation,
                    wrong: wrong
                )
                // The array may have shifted while the model worked (sheet closed,
                // story rewritten), so the line is found again by id, not by the
                // index captured above.
                guard !Task.isCancelled,
                      let target = previewLines.firstIndex(where: { $0.id == line.id })
                else { return }

                try TranslationReport.add(line, wrong: wrong, fixed: fixed, thread: previewPost?.title ?? "")
                previewLines[target] = TranslatedLine(
                    id: line.id,
                    kind: line.kind,
                    source: line.source,
                    translation: fixed
                )
                keep()
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
            }
        }
    }

    /// "Make this more engaging for Shorts": the story body is retold tighter by the
    /// on-device model; hook and outro survive as written. The original stays put
    /// when no model is available or the answer fails validation.
    public func makeEngaging() {
        guard !isRewriting, fixingLine == nil, previewPost != nil, !previewLines.isEmpty else { return }

        let rewriter = StoryRewriter()
        guard rewriter.isModelAvailable else {
            error = "AI rewrite needs Apple Intelligence or the bundled model — neither is available here."
            return
        }

        let body = previewLines.filter { $0.kind == .body }.map(\.translation).joined(separator: " ")
        guard !body.isEmpty else { return }

        isRewriting = true
        clearMark()

        read?.cancel()
        read = Task {
            defer { isRewriting = false }

            guard let rewritten = await rewriter.rewrite(body, language: settings.language) else {
                guard !Task.isCancelled else { return }
                error = "The model couldn't improve this story — keeping your text."
                return
            }
            guard !Task.isCancelled, previewPost != nil else { return }

            // The rewrite is authored, not translated, so body lines lose their
            // source captions — same as hook and outro.
            var lines = previewLines.filter { $0.kind == .hook }
            lines += Sentences.of(rewritten).map {
                TranslatedLine(id: 0, kind: .body, source: "", translation: $0)
            }
            lines += previewLines.filter { $0.kind == .outro }
            previewLines = lines.enumerated().map {
                TranslatedLine(id: $0, kind: $1.kind, source: $1.source, translation: $1.translation)
            }
            keep()
        }
    }

    private func clearMark() {
        markedLine = nil
        markedWords = []
    }

    /// Правленый сценарий переживает перезапуск и уходит в сборку вместо перевода.
    private func keep(quiet: Bool = false) {
        guard let id = previewPost?.id else { return }
        edits[ScriptEdits.key(id, settings.language)] = previewLines
        ScriptEdits.save(edits)
        if !quiet { toast = "Script saved" }
    }

    // MARK: - ElevenLabs

    /// Ключ живёт в связке ключей и в состояние модели не попадает: наружу выходит
    /// только факт его наличия и само значение для поля в настройках.
    public func elevenLabsKey() -> String {
        ElevenLabsSpeechEngine.storedKey() ?? ""
    }

    public func saveElevenLabsKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        ElevenLabsSpeechEngine.setStoredKey(trimmed.isEmpty ? nil : trimmed)
        if trimmed.isEmpty { settings.useElevenLabs = false }
    }

    // MARK: - Языковой пакет

    /// Пакет качается под выбранный язык озвучки: именно на него переводит запасной
    /// путь, и именно его отсутствие роняет сборку.
    public func downloadTranslationPack() {
        translationRequest = TranslationSession.Configuration(
            source: Translator.source,
            target: settings.language.locale
        )
    }

    /// Сама сессия сюда не приезжает: она не `Sendable`, а качает её вид.
    public func finishTranslationPack(_ failure: String?) {
        error = failure
        if failure == nil { toast = "Language pack ready" }
        translationRequest = nil
    }

    // MARK: - Готовые ролики

    public func saveToPhotos(_ reel: Reel) async {
        do {
            try await PhotoSaver.save(reel.url, cover: reel.coverURL)
            toast = "Video and cover saved to Photos"
        } catch {
            self.error = error.localizedDescription
        }
    }

    public func copyDescription(_ reel: Reel) {
        UIPasteboard.general.string = reel.description.forClipboard
        toast = "Description copied"
    }

    public func delete(_ reel: Reel) {
        store.delete(reel)
    }

    public func rename(_ reel: Reel, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "A title can't be empty — the video keeps its old name."
            return
        }
        store.rename(reel, to: trimmed)
    }

    public func duplicate(_ reel: Reel) {
        if store.duplicate(reel) != nil {
            toast = "Duplicated"
        } else {
            error = "Could not duplicate — the video file is missing."
        }
    }

    // MARK: - Геймплей

    public func refreshGameplay() async {
        do {
            clips = try await gameplay.refresh()
        } catch {
            guard !Task.isCancelled else { return }
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
