import Foundation

/// Screens stories that platforms demonetize or take down: explicit sex, graphic
/// violence, self-harm. Reddit's NSFW flag catches most of it upstream; this catches
/// what posters didn't flag. A short list on purpose — it filters a feed of story
/// candidates, it does not moderate; a borderline story costs nothing to skip.
public enum SafetyFilter {

    /// True when the story is safe to turn into a publishable Short.
    public static func isSafe(_ post: RedditPost) -> Bool {
        guard !post.isNSFW else { return false }
        return flaggedTerms(in: post.title + " " + post.selftext).isEmpty
    }

    /// The specific matches, so a card can say why a story was held back.
    public static func flaggedTerms(in text: String) -> [String] {
        let lowered = text.lowercased()
        let words = Set(
            lowered
                .components(separatedBy: boundaries)
                .filter { !$0.isEmpty }
        )

        return blockedWords.filter { words.contains($0) }
            + blockedPhrases.filter { lowered.contains($0) }
    }

    /// Whole-word matches only: "gore" must not trip on "category".
    private static let boundaries = CharacterSet.alphanumerics.inverted

    private static let blockedWords: [String] = [
        // Sexual content platforms reject outright.
        "porn", "nsfw", "fetish", "incest", "bestiality",
        // Graphic violence and death.
        "gore", "beheading", "dismembered", "necrophilia",
        // Self-harm; these stories need care a 45-second Short cannot give.
        "suicide", "overdose",
    ]

    /// Multi-word terms the word split would break apart.
    private static let blockedPhrases: [String] = [
        "self-harm", "self harm", "kill myself", "killed himself", "killed herself",
    ]
}
