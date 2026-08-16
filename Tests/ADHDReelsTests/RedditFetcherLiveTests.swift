import Testing
@testable import ADHDReelsKit

/// Живой запрос к Reddit. Выключен: сеть в тестах делает их флаки, а Reddit
/// режет анонимный трафик. Включать вручную, когда надо проверить, что
/// ретраи и запасной хост ещё работают.
@Suite("Reddit вживую", .disabled("требует сети"))
struct RedditFetcherLiveTests {

    @Test("Топ r/AskReddit отдаёт посты")
    func topPosts() async throws {
        // `refresh` обязателен: без него ответ приедет из кеша, и сеть проверена не будет.
        let posts = try await RedditFetcher()
            .topPosts(subreddit: "AskReddit", window: "week", minimumScore: 100, refresh: true)
        #expect(posts.count >= 5)
    }
}
