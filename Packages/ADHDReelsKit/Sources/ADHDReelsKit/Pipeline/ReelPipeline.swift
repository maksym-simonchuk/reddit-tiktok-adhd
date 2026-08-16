import Foundation

/// Весь путь от треда до готового mp4 в одном месте: тред → перевод → озвучка →
/// геймплей → монтаж → описание. Больше нигде эти шаги не встречаются.
public actor ReelPipeline {

    public enum Failure: LocalizedError {
        case emptyScript

        public var errorDescription: String? {
            switch self {
            case .emptyScript: "No text left after processing — pick another story."
            }
        }
    }

    private let gameplay: GameplayLibrary
    private let renderer = VideoRenderer()
    private let describer = DescriptionWriter()

    public init(gameplay: GameplayLibrary) {
        self.gameplay = gameplay
    }

    /// Тот же текст, что поедет в ролик, но до озвучки: показать человеку на вычитку.
    /// Шаги повторяют начало `make` — вычитывать что-то другое смысла нет.
    public func preview(post: RedditPost, settings: ReelSettings) async throws -> [TranslatedLine] {
        let draft = ScriptWriter(options: settings.scriptOptions).draft(from: post)
        guard !draft.isEmpty else { throw Failure.emptyScript }

        let translated = try await Self.translate(draft, to: settings.language)

        // Крючок вычитывается вместе с остальным текстом: он звучит первым, и править
        // его человеку важнее всего. Оригинала у него нет — он не перевод, а сочинение
        // по рассказу.
        let hook = await HookWriter().write(script: Script(segments: translated), language: settings.language)
        let outro = await OutroWriter().write(script: Script(segments: translated), language: settings.language)
        var lines = zip(draft, translated).enumerated().map { index, pair in
            TranslatedLine(id: index + 1, kind: pair.1.kind, source: pair.0.text, translation: pair.1.text)
        }

        if let hook { lines.insert(TranslatedLine(id: 0, kind: .hook, source: "", translation: hook), at: 0) }
        lines.append(TranslatedLine(id: lines.count + 1, kind: .outro, source: "", translation: outro))

        return lines
    }

    /// `approved` — текст, вычитанный человеком в предпросмотре. Есть он — переводить
    /// нечего: заново переведённое затёрло бы правки.
    public func make(
        post: RedditPost,
        approved: [ScriptSegment]? = nil,
        settings: ReelSettings,
        into folder: URL,
        progress: @escaping @Sendable (ReelProgress) -> Void
    ) async throws -> Reel {
        progress(ReelProgress(stage: .reading))

        let writer = ScriptWriter(options: settings.scriptOptions)
        let script: Script

        if let approved, !approved.isEmpty {
            // Вычитанный текст уже идёт с крючком первой строкой — он был виден
            // в предпросмотре. Написать новый значит выбросить правку человека.
            script = writer.finish(approved)
        } else {
            let draft = writer.draft(from: post)
            guard !draft.isEmpty else { throw Failure.emptyScript }

            if settings.language.needsTranslation { progress(ReelProgress(stage: .translating)) }
            let translated = try await Self.translate(draft, to: settings.language)

            // Крючок и вопрос в конце пишутся по уже переведённому тексту: оба звучат
            // голосом ролика и обязаны быть на его языке.
            let hook = await HookWriter().write(
                script: Script(segments: translated),
                language: settings.language
            )
            let outro = await OutroWriter().write(
                script: Script(segments: translated),
                language: settings.language
            )
            script = writer.finish(translated, hook: hook, outro: outro)
        }

        guard !script.plainText.isEmpty else { throw Failure.emptyScript }

        progress(ReelProgress(stage: .voicing))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let identifier = UUID()
        // Расширение не косметика: AVAudioFile выбирает контейнер по нему, а пишем мы PCM.
        let audio = folder.appending(path: "\(identifier.uuidString).wav")
        let take = try await SpeechEngines
            .make(settings: settings)
            .synthesize(script, to: audio)
        // Движок вправе положить дорожку рядом под своим контейнером (ElevenLabs
        // пишет mp3), поэтому дальше живёт только `take.audioURL` — а подчищаются оба.
        defer {
            try? FileManager.default.removeItem(at: audio)
            try? FileManager.default.removeItem(at: take.audioURL)
        }

        let words = CaptionTimeline.words(for: take, script: script)
        let groups = CaptionGrouper.groups(from: words)

        progress(ReelProgress(stage: .mounting))
        if await gameplay.clips().isEmpty { _ = try await gameplay.refresh() }
        let segments = try await gameplay.segments(for: take.duration)

        progress(ReelProgress(stage: .rendering))
        let video = folder.appending(path: "\(identifier.uuidString).mp4")
        let duration = try await renderer.render(
            segments: segments,
            audio: take.audioURL,
            groups: groups,
            theme: settings.caption,
            to: video,
            progress: { progress(ReelProgress(stage: .rendering, within: $0)) }
        )

        progress(ReelProgress(stage: .describing))
        let description = await describer.write(
            script: script,
            subreddit: post.subreddit,
            language: settings.language
        )
        await CoverMaker.make(
            from: video,
            title: description.title,
            to: folder.appending(path: "\(identifier.uuidString).jpg")
        )

        return Reel(
            id: identifier,
            title: description.title,
            subreddit: post.subreddit,
            permalink: post.permalink,
            fileName: video.lastPathComponent,
            duration: duration,
            description: description,
            post: post
        )
    }

    /// Английский оставляем как есть: тред уже на нём, и перевод только испортил бы
    /// живой текст. Русский ведёт языковая модель — она держит фразу целиком; остальным
    /// языкам её подсказка написана не под них, там переводит Apple Translation.
    private static func translate(_ draft: [ScriptSegment], to language: ReelLanguage) async throws -> [ScriptSegment] {
        switch language {
        case .english: draft
        case .russian: try await LLMTranslator().translate(draft)
        default: try await Translator(target: language).translate(draft)
        }
    }
}
