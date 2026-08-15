import Foundation

/// Весь путь от треда до готового mp4 в одном месте: тред → перевод → озвучка →
/// геймплей → монтаж → описание. Больше нигде эти шаги не встречаются.
public actor ReelPipeline {

    public enum Failure: LocalizedError {
        case emptyScript

        public var errorDescription: String? {
            switch self {
            case .emptyScript: "После перевода не осталось текста — выберите другой тред."
            }
        }
    }

    private let fetcher: RedditFetcher
    private let gameplay: GameplayLibrary
    private let renderer = VideoRenderer()
    private let describer = DescriptionWriter()

    public init(fetcher: RedditFetcher, gameplay: GameplayLibrary) {
        self.fetcher = fetcher
        self.gameplay = gameplay
    }

    public func make(
        post: RedditPost,
        settings: ReelSettings,
        into folder: URL,
        progress: @escaping @Sendable (ReelProgress) -> Void
    ) async throws -> Reel {
        var post = post
        progress(ReelProgress(stage: .reading))

        // Комментарии часто и есть история: в постах вроде AITA развязка лежит в них.
        if post.comments.isEmpty {
            post.comments = (try? await fetcher.comments(for: post)) ?? []
        }

        let writer = ScriptWriter(options: settings.scriptOptions)
        let draft = writer.draft(from: post)
        guard !draft.isEmpty else { throw Failure.emptyScript }

        progress(ReelProgress(stage: .translating))
        let translated = try await Translator().translate(draft)
        let script = writer.finish(translated)
        guard !script.plainText.isEmpty else { throw Failure.emptyScript }

        progress(ReelProgress(stage: .voicing))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let identifier = UUID()
        // Расширение не косметика: AVAudioFile выбирает контейнер по нему, а пишем мы PCM.
        let audio = folder.appending(path: "\(identifier.uuidString).wav")
        let take = try await SystemSpeechEngine(voiceIdentifier: settings.voiceIdentifier)
            .synthesize(script, to: audio)
        defer { try? FileManager.default.removeItem(at: audio) }

        let words = CaptionTimeline.words(for: take, script: script)
        let groups = CaptionGrouper.groups(from: words)

        progress(ReelProgress(stage: .mounting))
        if await gameplay.clips().isEmpty { _ = try await gameplay.refresh() }
        let segments = try await gameplay.segments(for: take.duration)

        progress(ReelProgress(stage: .rendering))
        let video = folder.appending(path: "\(identifier.uuidString).mp4")
        let duration = try await renderer.render(
            segments: segments,
            audio: audio,
            groups: groups,
            theme: settings.caption,
            to: video,
            progress: { progress(ReelProgress(stage: .rendering, within: $0)) }
        )

        progress(ReelProgress(stage: .describing))
        let description = await describer.write(script: script, subreddit: post.subreddit)

        return Reel(
            id: identifier,
            title: description.title,
            subreddit: post.subreddit,
            permalink: post.permalink,
            fileName: video.lastPathComponent,
            duration: duration,
            description: description
        )
    }
}
