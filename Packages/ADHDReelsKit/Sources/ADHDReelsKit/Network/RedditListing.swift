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

    /// Reddit отдаёт посты в общем конверте, где заполнено не всё, поэтому всё опционально.
    private struct Thing: Decodable {
        let id: String?
        let subreddit: String?
        let title: String?
        let selftext: String?
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
    }
}
