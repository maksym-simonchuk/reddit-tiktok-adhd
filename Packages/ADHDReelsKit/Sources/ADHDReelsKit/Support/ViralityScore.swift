import Foundation

/// 0–100 guess at how well a story converts into a Short. A heuristic, not a model:
/// deterministic on the post's own numbers, so the same feed always ranks the same way
/// and the score is explainable when someone asks why a card says 87.
public enum ViralityScore {

    /// Upvotes prove the story hooks readers, comments prove it starts arguments,
    /// length decides whether it survives the cut to ~45 seconds, and the title is
    /// the raw material for the hook.
    public static func score(
        for post: RedditPost,
        targetDuration: Double = 45,
        language: ReelLanguage = .english
    ) -> Int {
        let engagement = engagementPoints(post.score)
        let debate = debatePoints(comments: post.numComments, score: post.score)
        let length = lengthPoints(words: post.wordCount, targetDuration: targetDuration, language: language)
        let title = titlePoints(post.title)

        return min(100, engagement + debate + length + title)
    }

    /// 60 is where the card starts recommending: enough signal in every component,
    /// not just one runaway number.
    public static func isRecommended(_ score: Int) -> Bool { score >= 60 }

    public static func label(_ score: Int) -> String {
        switch score {
        case 75...: "High potential"
        case 60...: "Good pick"
        case 40...: "Average"
        default: "Low signal"
        }
    }

    // MARK: - Components

    /// Log scale, max 40: the jump from 500 to 5k upvotes says more than 50k to 100k.
    static func engagementPoints(_ score: Int) -> Int {
        guard score > 0 else { return 0 }
        return min(40, Int(8 * log10(Double(score) + 1)))
    }

    /// Comments per upvote, max 20: a high ratio marks stories people argue about,
    /// and arguments are what the outro question converts into comments.
    static func debatePoints(comments: Int?, score: Int) -> Int {
        guard let comments, comments > 0 else { return 0 }
        guard score > 0 else { return min(20, comments / 25) }

        let ratio = Double(comments) / Double(score)
        return min(20, Int(ratio * 200))
    }

    /// Max 25 when the story fills the target duration with a sensible trim margin;
    /// tapers on both sides — too short can't fill the video, too long loses its
    /// ending to the cut. The ideal word count follows the narration language:
    /// Russian speaks nearly twice as many words per second as English.
    static func lengthPoints(words: Int, targetDuration: Double, language: ReelLanguage = .english) -> Int {
        let ideal = targetDuration * Script.wordsPerSecond(for: language)
        guard words > 0, ideal > 0 else { return 0 }

        let ratio = Double(words) / ideal
        switch ratio {
        case 0.7...2.5: return 25
        case 0.4..<0.7, 2.5...4: return 15
        case 0.2..<0.4, 4...6: return 8
        default: return 0
        }
    }

    /// Max 15: a title that already reads like a hook — first person, mid-length,
    /// ends on tension rather than a full summary.
    static func titlePoints(_ title: String) -> Int {
        var points = 0

        if (20...110).contains(title.count) { points += 7 }

        let lowered = " " + title.lowercased()
        let firstPerson = ["i ", "my ", "me ", "aita"].contains { lowered.contains(" " + $0) }
        if firstPerson { points += 4 }

        if title.hasSuffix("?") || title.contains("…") { points += 4 }

        return min(15, points)
    }
}
