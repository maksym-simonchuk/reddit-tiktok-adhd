import Testing
@testable import ADHDReelsKit

@Suite("Строки вычитки")
struct PreviewLinesTests {

    /// Английский тред без перевода и без сети: модели в симуляторе нет —
    /// проверяем саму раскладку строк.
    @Test("Оригинал стоит рядом со своей строкой, а не съезжает на соседнюю")
    func keepsSourcesAligned() async throws {
        var settings = ReelSettings()
        settings.language = .english

        let pipeline = ReelPipeline(gameplay: GameplayLibrary())
        let lines = try await pipeline.preview(post: post, settings: settings)

        let translated = lines.filter { !$0.source.isEmpty }
        #expect(translated.allSatisfy { $0.source == $0.translation })
        #expect(Set(lines.map(\.id)).count == lines.count)
    }

    /// Крючок — единственная строка без оригинала: он сочинён по рассказу.
    /// Модель переписать его не может, поэтому «Исправить» должно отказать.
    @Test("Крючок помечен пустым оригиналом")
    func hookHasNoSource() {
        let hook = TranslatedLine(id: 0, kind: .hook, source: "", translation: "Ты думал, это на маму")
        #expect(hook.source.isEmpty)
        #expect(hook.words.count == 5)
    }

    private var post: RedditPost {
        RedditPost(
            id: "abc",
            subreddit: "tifu",
            title: "I found out my wife paid my brother's debt",
            selftext: String(repeating: "We were saving for a flat and the money went somewhere else. ", count: 4),
            score: 900,
            isNSFW: false,
            permalink: "/r/tifu/comments/abc/"
        )
    }
}
