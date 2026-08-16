import Foundation

public struct RedditPost: Identifiable, Codable, Hashable, Sendable {

    public let id: String
    public let subreddit: String
    public let title: String
    public let selftext: String
    public let score: Int
    public let isNSFW: Bool
    public let permalink: String

    public init(
        id: String,
        subreddit: String,
        title: String,
        selftext: String,
        score: Int,
        isNSFW: Bool,
        permalink: String
    ) {
        self.id = id
        self.subreddit = subreddit
        self.title = title
        self.selftext = selftext
        self.score = score
        self.isNSFW = isNSFW
        self.permalink = permalink
    }

    /// Reddit иногда отдаёт permalink с символами, ломающими URL, поэтому опционал.
    public var url: URL? { URL(string: "https://www.reddit.com" + permalink) }

    /// Слов в теле поста: по этому числу в ленте видно, хватит ли текста на ролик.
    public var wordCount: Int {
        selftext.split(whereSeparator: \.isWhitespace).count
    }
}
