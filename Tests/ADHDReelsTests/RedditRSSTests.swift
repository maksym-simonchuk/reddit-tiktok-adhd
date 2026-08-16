import Foundation
import Testing
@testable import ADHDReelsKit

@Suite("Запасной путь через RSS")
struct RedditRSSTests {

    /// Ровно та же форма, что отдаёт Reddit: HTML внутри `content` экранирован дважды.
    private static let feed = """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <id>/r/TrueOffMyChest/top/.rss?t=week</id>
      <title>top scoring links : TrueOffMyChest</title>
      <entry>
        <category term="TrueOffMyChest"/>
        <content type="html">&lt;!-- SC_OFF --&gt;&lt;div class="md"&gt;&lt;p&gt;I didn&amp;#39;t say a word for years.&lt;/p&gt;&lt;p&gt;Then I did.&lt;/p&gt;&lt;/div&gt;&lt;!-- SC_ON --&gt; &amp;#32; submitted by &amp;#32; &lt;a href="https://www.reddit.com/user/thrown"&gt; /u/thrown &lt;/a&gt; &lt;span&gt;&lt;a href="https://example.com"&gt;[link]&lt;/a&gt;&lt;/span&gt; &lt;span&gt;&lt;a href="https://example.com"&gt;[comments]&lt;/a&gt;&lt;/span&gt;</content>
        <id>t3_1vjiumj</id>
        <link href="https://www.reddit.com/r/TrueOffMyChest/comments/1vjiumj/i_stayed_silent/" />
        <title>I stayed silent &amp;amp; it cost me</title>
      </entry>
      <entry>
        <content type="html">submitted by &lt;a href="https://www.reddit.com/user/thrown"&gt; /u/thrown &lt;/a&gt; &lt;span&gt;[link]&lt;/span&gt; &lt;span&gt;[comments]&lt;/span&gt;</content>
        <id>t3_photo</id>
        <link href="https://www.reddit.com/r/TrueOffMyChest/comments/photo/x/" />
        <title>Just a photo</title>
      </entry>
    </feed>
    """

    private static var data: Data { Data(feed.utf8) }

    @Test("Из ленты вынимаются посты с текстом и путём")
    func parsesPosts() {
        let posts = RedditRSS.posts(from: Self.data, subreddit: "TrueOffMyChest")

        #expect(posts.count == 1)
        #expect(posts[0].id == "1vjiumj")
        #expect(posts[0].title == "I stayed silent & it cost me")
        #expect(posts[0].selftext == "I didn't say a word for years. Then I did.")
        #expect(posts[0].permalink == "/r/TrueOffMyChest/comments/1vjiumj/i_stayed_silent/")
        #expect(posts[0].subreddit == "TrueOffMyChest")
    }

    @Test("Подпись submitted by не попадает в историю, пост без текста — в ленту")
    func stripsBoilerplate() {
        let posts = RedditRSS.posts(from: Self.data, subreddit: "TrueOffMyChest")

        #expect(!posts.contains { $0.id == "photo" })
        #expect(!posts[0].selftext.contains("submitted by"))
        #expect(!posts[0].selftext.contains("[link]"))
    }

    @Test("Тело поста режется по маркерам SC_OFF/SC_ON")
    func cutsBodyByMarkers() {
        #expect(RedditRSS.selftext(in: "<!-- SC_OFF -->kept<!-- SC_ON --> tail") == "kept")
        // Подпись локализуется под язык устройства — без маркеров текста нет.
        #expect(RedditRSS.selftext(in: "submitted by /u/x [link] [коментарі]") == "")
        #expect(RedditRSS.selftext(in: "<!-- SC_OFF -->no closing marker") == "")
    }

    @Test("Шапка ленты не превращается в пост")
    func skipsFeedHeader() {
        let posts = RedditRSS.posts(from: Self.data, subreddit: "TrueOffMyChest")
        #expect(!posts.contains { $0.title.contains("top scoring links") })
    }

    @Test("Посты берутся только с префиксом t3_")
    func skipsComments() {
        let body = "&lt;!-- SC_OFF --&gt;&lt;p&gt;Длинная история ровно на пять слов&lt;/p&gt;&lt;!-- SC_ON --&gt;"
        let feed = """
        <feed xmlns="http://www.w3.org/2005/Atom">
          <entry><id>t3_post</id><title>Пост</title><content type="html">\(body)</content></entry>
          <entry><id>t1_abc</id><title>Ответ</title><content type="html">\(body)</content></entry>
        </feed>
        """

        #expect(RedditRSS.posts(from: Data(feed.utf8), subreddit: "x").map(\.id) == ["post"])
    }

    @Test("Мусор вместо XML не роняет разбор")
    func survivesGarbage() {
        #expect(RedditRSS.posts(from: Data("не xml".utf8), subreddit: "x").isEmpty)
    }
}

@Suite("HTML в текст")
struct HTMLTextTests {

    @Test("Теги убираются, слова не слипаются")
    func stripsTags() {
        #expect(HTMLText.plain("<p>Первый</p><p>Второй</p>") == "Первый Второй")
        #expect(HTMLText.plain("один<br/>два") == "один два")
    }

    @Test("Сущности раскрываются, включая числовые")
    func decodesEntities() {
        #expect(HTMLText.plain("a &amp; b") == "a & b")
        #expect(HTMLText.plain("don&#39;t") == "don't")
        #expect(HTMLText.plain("&#x41;&#x42;") == "AB")
        #expect(HTMLText.plain("100&nbsp;%") == "100 %")
    }

    @Test("Неизвестная сущность остаётся как есть")
    func keepsUnknownEntity() {
        #expect(HTMLText.plain("&unknownthing; и &amp;") == "&unknownthing; и &")
        #expect(HTMLText.plain("5 & 6") == "5 & 6")
    }

    @Test("Пустой вход даёт пустой выход")
    func handlesEmpty() {
        #expect(HTMLText.plain("").isEmpty)
        #expect(HTMLText.plain("   \n  ").isEmpty)
    }
}
