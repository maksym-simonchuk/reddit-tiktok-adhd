import Testing
@testable import ADHDReelsKit

@Suite("Незаконченная сборка")
struct RenderJobTests {

    @Test("Работа переживает перезапуск и снимается после сборки")
    func roundTrip() {
        RenderJob(post: post, approved: nil, settings: ReelSettings()).keep()

        #expect(RenderJob.saved()?.post.id == "abc")

        RenderJob.clear()
        #expect(RenderJob.saved() == nil)
    }

    @Test("Вычитанный текст и настройки едут вместе с работой")
    func carriesEdits() {
        var settings = ReelSettings()
        settings.language = .english

        let approved = [ScriptSegment(kind: .hook, text: "She found out at the wedding")]
        RenderJob(post: post, approved: approved, settings: settings).keep()
        defer { RenderJob.clear() }

        let saved = RenderJob.saved()
        #expect(saved?.approved == approved)
        #expect(saved?.settings.language == .english)
    }

    private var post: RedditPost {
        RedditPost(
            id: "abc",
            subreddit: "tifu",
            title: "Заголовок",
            selftext: "Текст",
            score: 900,
            isNSFW: false,
            permalink: "/r/tifu/comments/abc/"
        )
    }
}
