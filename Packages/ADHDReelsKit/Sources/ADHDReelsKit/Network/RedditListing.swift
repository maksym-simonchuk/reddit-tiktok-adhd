import Foundation

/// Разбор публичного JSON Reddit. Вынесено из `RedditFetcher`, чтобы golden-тесты
/// прогоняли зафиксированные ответы без сети.
public enum RedditListing {

    public static func posts(from data: Data, minimumScore: Int = 0, allowNSFW: Bool = false) throws -> [RedditPost] {
        try JSONDecoder().decode(Listing.self, from: data)
            .data.children
            .filter { $0.kind == "t3" }
            .compactMap(\.data.asPost)
            .filter { $0.score >= minimumScore }
            .filter { allowNSFW || !$0.isNSFW }
    }

    public static func comments(from data: Data) throws -> [RedditComment] {
        // Ответ на /comments/<id>.json — массив из двух листингов: пост и ветка.
        try JSONDecoder().decode([Listing].self, from: data)
            .flatMap(\.data.children)
            .filter { $0.kind == "t1" }
            .compactMap(\.data.asComment)
            .filter { !$0.body.isEmpty && $0.body != "[deleted]" && $0.body != "[removed]" }
            .sorted { $0.score > $1.score }
    }

    // MARK: - Формат

    private struct Listing: Decodable {
        let data: ListingData

        struct ListingData: Decodable {
            let children: [Child]
        }

        struct Child: Decodable {
            let kind: String
            let data: Thing
        }
    }

    /// Reddit использует один конверт для постов и комментариев, поэтому всё опционально.
    private struct Thing: Decodable {
        let id: String?
        let subreddit: String?
        let title: String?
        let selftext: String?
        let body: String?
        let score: Int?
        let over_18: Bool?
        let permalink: String?
        let stickied: Bool?

        var asPost: RedditPost? {
            guard let id, let title, stickied != true else { return nil }
            return RedditPost(
                id: id,
                subreddit: subreddit ?? "",
                title: title,
                selftext: selftext ?? "",
                score: score ?? 0,
                isNSFW: over_18 ?? false,
                permalink: permalink ?? "/comments/\(id)/"
            )
        }

        var asComment: RedditComment? {
            guard let id, let body else { return nil }
            return RedditComment(id: id, body: body, score: score ?? 0)
        }
    }
}
