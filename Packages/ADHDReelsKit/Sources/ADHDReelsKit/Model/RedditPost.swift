import Foundation

public struct RedditPost: Identifiable, Codable, Hashable, Sendable {

    public let id: String
    public let subreddit: String
    public let title: String
    public let selftext: String
    public let score: Int
    public let isNSFW: Bool
    public let permalink: String
    public var comments: [RedditComment]

    public init(
        id: String,
        subreddit: String,
        title: String,
        selftext: String,
        score: Int,
        isNSFW: Bool,
        permalink: String,
        comments: [RedditComment] = []
    ) {
        self.id = id
        self.subreddit = subreddit
        self.title = title
        self.selftext = selftext
        self.score = score
        self.isNSFW = isNSFW
        self.permalink = permalink
        self.comments = comments
    }

    /// Reddit иногда отдаёт permalink с символами, ломающими URL, поэтому опционал.
    public var url: URL? { URL(string: "https://www.reddit.com" + permalink) }

    /// Слов в теле поста: по этому числу в ленте видно, хватит ли текста на ролик.
    public var wordCount: Int {
        selftext.split(whereSeparator: \.isWhitespace).count
    }
}

public struct RedditComment: Identifiable, Codable, Hashable, Sendable {

    public let id: String
    public let body: String
    public let score: Int

    public init(id: String, body: String, score: Int) {
        self.id = id
        self.body = body
        self.score = score
    }
}
