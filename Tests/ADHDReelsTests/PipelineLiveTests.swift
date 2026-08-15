import AVFoundation
import Foundation
import Testing
import Translation
@testable import ADHDReelsKit

/// Весь путь от треда до mp4 плюс отчёт по каждому шагу: где текст теряется,
/// без промежуточных длин не увидеть. Отчёт уезжает в tmp и забирается наружу.
@Suite(
    "Ролик из треда",
    .enabled(if: RenderLiveReadiness.isReady, "нет русского голоса или геймплея")
)
struct PipelineLiveTests {

    /// Reddit режет анонимные запросы, и упереться в 429 — не дефект монтажа.
    /// Тогда берём заведомо длинный тред: проверяем всё, кроме сети.
    private static let fallback = RedditPost(
        id: "local",
        subreddit: "TrueOffMyChest",
        title: "I finally told my family the truth about the money",
        selftext: """
            For twelve years I paid off my father's debt without telling anyone. \
            Every month a third of my salary went to a bank in another city, and every \
            month I told my wife it went to savings. I was nineteen when he asked me, \
            and he made me promise never to mention it to my mother.

            Last Sunday my sister announced she was buying a house. She said she had been \
            careful with money, unlike me, and everyone at the table agreed. My father \
            looked at his plate and said nothing at all.

            So I told them. I put the statements on the table and I read out the numbers, \
            year by year, until my mother started crying and my sister left the room. \
            My father still has not spoken to me. I do not regret it, but I keep waking \
            up at four in the morning and I cannot fall back asleep.
            """,
        score: 9000,
        isNSFW: false,
        permalink: "/r/TrueOffMyChest/comments/local/x/",
        comments: [
            RedditComment(id: "c1", body: "You carried that alone for twelve years. The silence was never yours to keep.", score: 4200),
            RedditComment(id: "c2", body: "Your sister owes you an apology, and your father owes you twelve years of them.", score: 3100),
        ]
    )

    // Субтитры кладёт CoreAnimation, а она в симуляторе роняет QuartzCore.
    #if !targetEnvironment(simulator)
    @Test("Тред превращается в готовый ролик", .timeLimit(.minutes(10)))
    func buildsReel() async throws {
        var report = ""
        func note(_ line: String) { report += line + "\n" }
        defer { try? Data(report.utf8).write(to: URL.temporaryDirectory.appending(path: "pipeline-report.txt")) }

        for voice in PiperSpeechEngine.voices() {
            note("нейроголос: \(voice.title) [\(voice.id)]")
        }
        note("espeak-ng-data: \(PiperSpeechEngine.espeakData?.path(percentEncoded: false) ?? "нет")")
        for voice in SystemSpeechEngine.russianVoices() {
            note("голос: \(voice.name) [\(voice.identifier)] качество=\(voice.quality.rawValue)")
        }

        let availability = LanguageAvailability()
        for source in ["en", "en-US"] {
            for target in ["ru", "ru-RU"] {
                let status = await availability.status(
                    from: Locale.Language(identifier: source),
                    to: Locale.Language(identifier: target)
                )
                note("перевод \(source)→\(target): \(status)")
            }
        }
        let supported = await availability.supportedLanguages.map(\.maximalIdentifier)
        note("языки перевода: \(supported.filter { $0.hasPrefix("ru") || $0.hasPrefix("en") })")

        let folder = URL.temporaryDirectory.appending(path: "pipeline-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let fetcher = RedditFetcher()
        let settings = ReelSettings()

        var post = Self.fallback
        var source = "запасной тред"
        do {
            let posts = try await fetcher.topPosts(
                subreddit: settings.subreddit,
                window: settings.window,
                minimumScore: settings.minimumScore
            )
            if let first = posts.first {
                post = first
                source = "Reddit, \(posts.count) тредов"
            }
        } catch {
            source = "запасной тред: \(error.localizedDescription)"
        }

        if post.comments.isEmpty {
            post.comments = (try? await fetcher.comments(for: post)) ?? []
        }

        note("\nисточник: \(source)")
        note("тред: \(post.title)")
        note("тело: \(post.selftext.count) символов, комментариев \(post.comments.count)")

        let writer = ScriptWriter(options: settings.scriptOptions)
        let draft = writer.draft(from: post)
        note("\nчерновик: \(draft.count) сегментов, оценка \(Script(segments: draft).estimatedDuration) с")
        for segment in draft {
            note("  \(segment.kind): \(segment.text.count) символов — \(segment.text.prefix(60))…")
        }

        var translated = draft
        do {
            translated = try await Translator(cacheURL: folder.appending(path: "cache.json")).translate(draft)
            note("\nперевод: \(translated.count) сегментов")
        } catch {
            // Дальше идём с английским: отчёт про длину нужен и без перевода.
            note("\nперевод упал: \(error.localizedDescription)")
        }
        for segment in translated {
            note("  \(segment.kind): \(segment.text.count) символов — \(segment.text.prefix(60))…")
        }

        let script = writer.finish(translated)
        note("\nсценарий: \(script.wordCount) слов, оценка \(script.estimatedDuration) с")
        note(script.plainText)

        let engine = SpeechEngines.make(voiceIdentifier: settings.voiceIdentifier)
        let take = try await engine.synthesize(script, to: folder.appending(path: "voice.wav"))
        note("\nдвижок: \(type(of: engine))")
        note("озвучка: \(take.duration) с, меток \(take.words?.count ?? -1)")
        note("темп: \(Double(script.wordCount) / max(take.duration, 0.01)) слов/с")

        #expect(translated.count == draft.count, "перевод потерял сегменты")
        #expect(take.duration > 25, "озвучка короче двадцати пяти секунд")
        #expect(abs(take.duration - settings.targetDuration) < 20)
    }
    #endif
}
