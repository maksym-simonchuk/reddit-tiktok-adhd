import Foundation

/// A Discover chip: a human theme mapped onto the story subreddits that carry it.
/// Categories exist because subreddit names mean nothing until you've read a dozen
/// threads — "Revenge" says in one word what r/MaliciousCompliance never will.
public struct StoryCategory: Identifiable, Hashable, Sendable {

    public let id: String
    public let title: String
    /// First-person, selftext-heavy subreddits; the first one is the default feed.
    public let subreddits: [String]

    public var primary: String { subreddits[0] }

    public static let all: [StoryCategory] = [
        StoryCategory(id: "drama", title: "Drama", subreddits: [
            "AmItheAsshole", "TrueOffMyChest", "relationship_advice"
        ]),
        StoryCategory(id: "revenge", title: "Revenge", subreddits: [
            "pettyrevenge", "ProRevenge", "MaliciousCompliance"
        ]),
        StoryCategory(id: "funny", title: "Funny", subreddits: [
            "tifu", "TalesFromRetail"
        ]),
        StoryCategory(id: "scary", title: "Scary", subreddits: [
            "nosleep", "LetsNotMeet"
        ]),
        StoryCategory(id: "wholesome", title: "Wholesome", subreddits: [
            "MadeMeSmile", "happy"
        ]),
    ]

    /// The chip to light up for the current feed; nil means a custom subreddit.
    public static func category(containing subreddit: String) -> StoryCategory? {
        all.first { $0.subreddits.contains { $0.caseInsensitiveCompare(subreddit) == .orderedSame } }
    }
}
