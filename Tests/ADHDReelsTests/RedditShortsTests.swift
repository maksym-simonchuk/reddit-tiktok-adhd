import Foundation
import Testing
@testable import ADHDReelsKit

@Suite("Feed card metadata")
struct FeedMetadataTests {

    @Test("Listing carries comments and age; missing fields stay nil")
    func parsesCommentsAndAge() throws {
        let posts = try RedditListing.posts(from: Data(RedditFixtures.listing.utf8), minimumScore: 500, allowNSFW: true)

        let rich = try #require(posts.first { $0.id == "a1" })
        #expect(rich.numComments == 1830)
        #expect(rich.createdAt == Date(timeIntervalSince1970: 1_755_300_000))

        let bare = try #require(posts.first { $0.id == "a4" })
        #expect(bare.numComments == nil)
        #expect(bare.createdAt == nil)
    }

    @Test("A post saved before the new fields still decodes")
    func decodesLegacyPost() throws {
        let legacy = #"{"id":"x","subreddit":"tifu","title":"t","selftext":"s","score":1,"isNSFW":false,"permalink":"/p/"}"#
        let post = try JSONDecoder().decode(RedditPost.self, from: Data(legacy.utf8))
        #expect(post.numComments == nil)
        #expect(post.createdAt == nil)
    }
}

@Suite("Virality score")
struct ViralityScoreTests {

    private func post(score: Int, comments: Int?, words: Int, title: String = "AITA for a normal-length title here?") -> RedditPost {
        RedditPost(
            id: "v1",
            subreddit: "AmItheAsshole",
            title: title,
            selftext: Array(repeating: "word", count: words).joined(separator: " "),
            score: score,
            isNSFW: false,
            permalink: "/p/",
            numComments: comments
        )
    }

    @Test("A hot debated story of the right length scores as recommended")
    func recommendsStrongStory() {
        let score = ViralityScore.score(for: post(score: 12_000, comments: 3_000, words: 150))
        #expect(ViralityScore.isRecommended(score))
        #expect(score <= 100)
    }

    @Test("A weak short story scores low")
    func lowSignalStory() {
        let score = ViralityScore.score(for: post(score: 40, comments: 2, words: 15, title: "hm"))
        #expect(!ViralityScore.isRecommended(score))
        #expect(score < 40)
    }

    @Test("Deterministic: the same post always gets the same score")
    func deterministic() {
        let sample = post(score: 8_400, comments: 1_830, words: 120)
        #expect(ViralityScore.score(for: sample) == ViralityScore.score(for: sample))
    }

    @Test("Missing comments cost points but never crash")
    func toleratesMissingComments() {
        let with = ViralityScore.score(for: post(score: 8_400, comments: 1_830, words: 120))
        let without = ViralityScore.score(for: post(score: 8_400, comments: nil, words: 120))
        #expect(without <= with)
    }

    @Test("The length component follows the narration language")
    func lengthFollowsLanguage() {
        // 150 words fill 45s of English narration but only ~70% of the Russian
        // word budget — the same story must not score the same in both.
        let sample = post(score: 8_400, comments: 1_830, words: 150)
        let english = ViralityScore.score(for: sample, language: .english)
        let russian = ViralityScore.score(for: sample, language: .russian)
        #expect(english > russian)
    }
}

@Suite("Custom subreddit input")
struct SubredditInputTests {

    @Test("Bare names, r/ prefixes and full links all resolve")
    func parsesCommonShapes() {
        #expect(FeedView.subredditName(from: "tifu") == "tifu")
        #expect(FeedView.subredditName(from: " r/AskHistorians ") == "AskHistorians")
        #expect(FeedView.subredditName(from: "R/tifu") == "tifu")
        #expect(FeedView.subredditName(from: "https://www.reddit.com/r/nosleep/comments/abc/story/") == "nosleep")
        #expect(FeedView.subredditName(from: "/r/tifu/") == "tifu")
        #expect(FeedView.subredditName(from: "relationship_advice") == "relationship_advice")
    }

    @Test("Garbage is rejected instead of mangled")
    func rejectsGarbage() {
        #expect(FeedView.subredditName(from: "") == nil)
        #expect(FeedView.subredditName(from: "not a name") == nil)
        #expect(FeedView.subredditName(from: "https://example.com/") == nil)
    }
}

@Suite("Safety filter")
struct SafetyFilterTests {

    private func post(title: String, body: String = "", nsfw: Bool = false) -> RedditPost {
        RedditPost(id: "s1", subreddit: "tifu", title: title, selftext: body,
                   score: 100, isNSFW: nsfw, permalink: "/p/")
    }

    @Test("Ordinary drama passes")
    func passesCleanStory() {
        #expect(SafetyFilter.isSafe(post(title: "AITA for skipping my sister's wedding?", body: "Family drama.")))
    }

    @Test("The NSFW flag alone blocks the story")
    func blocksNSFW() {
        #expect(!SafetyFilter.isSafe(post(title: "Harmless title", nsfw: true)))
    }

    @Test("Blocked terms match whole words, not substrings")
    func matchesWholeWordsOnly() {
        #expect(SafetyFilter.flaggedTerms(in: "He put it in the category of jokes").isEmpty)
        #expect(SafetyFilter.flaggedTerms(in: "Graphic gore everywhere") == ["gore"])
    }

    @Test("Hyphenated phrases are caught despite word splitting")
    func catchesPhrases() {
        #expect(SafetyFilter.flaggedTerms(in: "a story about self-harm").contains("self-harm"))
    }
}

@Suite("Story categories")
struct StoryCategoryTests {

    @Test("Every category has at least one subreddit and a primary")
    func categoriesAreWellFormed() {
        for category in StoryCategory.all {
            #expect(!category.subreddits.isEmpty)
            #expect(category.primary == category.subreddits[0])
        }
    }

    @Test("A chip lights up for its own subreddit, case-insensitively")
    func findsCategoryBySubreddit() {
        #expect(StoryCategory.category(containing: "pettyrevenge")?.id == "revenge")
        #expect(StoryCategory.category(containing: "AMITHEASSHOLE")?.id == "drama")
        #expect(StoryCategory.category(containing: "somethingcustom") == nil)
    }
}

@Suite("Settings migration")
struct SettingsMigrationTests {

    @Test("A blob saved before voiceSpeed and presets decodes with defaults")
    func decodesLegacySettings() throws {
        let legacy = #"""
        {"subreddit":"tifu","window":"day","targetDuration":60,"minimumScore":750,
         "language":"ru","caption":{"fontSize":96,"highlight":"green","verticalPosition":0.5,"uppercase":false}}
        """#
        let settings = try JSONDecoder().decode(ReelSettings.self, from: Data(legacy.utf8))

        #expect(settings.subreddit == "tifu")
        #expect(settings.language == .russian)
        #expect(settings.voiceSpeed == 1)
        #expect(settings.safeContentOnly)
        #expect(settings.caption.preset == .viral)
        #expect(settings.caption.highlight == .green)
        #expect(settings.caption.fontSize == 96)
        #expect(!settings.useElevenLabs)
        #expect(settings.elevenLabsVoiceID == nil)
    }

    @Test("Fresh install defaults to English narration")
    func defaultsToEnglish() {
        #expect(ReelSettings().language == .english)
    }

    @Test("Language switch drops the voice, same language keeps it")
    func languageResetsVoice() {
        var settings = ReelSettings()
        settings.voiceIdentifier = "some-voice"
        settings.language = .english
        #expect(settings.voiceIdentifier == "some-voice")

        settings.language = .russian
        #expect(settings.voiceIdentifier == nil)
    }
}

@Suite("Narration pace")
struct NarrationPaceTests {

    @Test("English trims to a natural word budget, Russian keeps its calibration")
    func paceByLanguage() {
        #expect(Script.wordsPerSecond(for: .russian) == Script.wordsPerSecond)
        let english = Script.wordsPerSecond(for: .english)
        // 130–170 wpm is the natural narration band for Shorts.
        #expect(english * 60 >= 130 && english * 60 <= 170)
    }

    @Test("System voice rate: English natural, Russian 1.5×, speed shifts both")
    func systemRateMapping() {
        #expect(SystemSpeechEngine.rate(for: .english) == 0.5)
        #expect(abs(SystemSpeechEngine.rate(for: .russian) - 0.57) < 0.001)
        #expect(SystemSpeechEngine.rate(for: .english, speed: 1.25) > 0.5)
        #expect(SystemSpeechEngine.rate(for: .english, speed: 0.9) < 0.5)
        // Extreme speeds stay clamped inside usable AVSpeech territory.
        #expect(SystemSpeechEngine.rate(for: .russian, speed: 10) <= 0.68)
        #expect(SystemSpeechEngine.rate(for: .english, speed: 0) >= 0.35)
    }

    @Test("Progress checklist hides translation for English")
    func checklistHidesTranslation() {
        #expect(!ReelStage.visibleStages(for: .english).contains(.translating))
        #expect(ReelStage.visibleStages(for: .russian).contains(.translating))
        #expect(ReelStage.visibleStages(for: .english).first == .reading)
        #expect(ReelStage.visibleStages(for: .english).last == .describing)
    }
}

@Suite("Story rewriter validation")
struct StoryRewriterTests {

    @Test("A sane rewrite survives cleaning")
    func acceptsSaneRewrite() {
        let original = String(repeating: "the story goes on and on ", count: 10)
        let rewritten = String(repeating: "tighter now ", count: 12)
        #expect(StoryRewriter.clean(rewritten, original: original) != nil)
    }

    @Test("A stub or a runaway answer is rejected")
    func rejectsBadAnswers() {
        let original = String(repeating: "word ", count: 100)
        #expect(StoryRewriter.clean("Too short.", original: original) == nil)
        #expect(StoryRewriter.clean(String(repeating: "ramble ", count: 400), original: original) == nil)
    }
}

@Suite("ElevenLabs alignment")
struct ElevenLabsAlignmentTests {

    @Test("Characters fold into words with first-to-last timing")
    func foldsCharactersIntoWords() {
        let words = ElevenLabsSpeechEngine.words(
            characters: ["H", "i", " ", "y", "o", "u"],
            starts: [0.0, 0.1, 0.2, 0.3, 0.4, 0.5],
            ends: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6]
        )
        #expect(words.map(\.text) == ["Hi", "you"])
        #expect(words[0].start == 0.0 && words[0].end == 0.2)
        #expect(words[1].start == 0.3 && words[1].end == 0.6)
    }

    @Test("Degenerate alignments produce no words and never crash")
    func toleratesDegenerateAlignment() {
        #expect(ElevenLabsSpeechEngine.words(characters: [" ", "\n"], starts: [0, 0.1], ends: [0.1, 0.2]).isEmpty)

        // Mismatched array lengths stop at the shortest instead of trapping.
        let truncated = ElevenLabsSpeechEngine.words(characters: ["a", "b", "c"], starts: [0], ends: [0.1])
        #expect(truncated.map(\.text) == ["a"])
    }
}

@Suite("Keychain store")
struct KeychainTests {

    @Test("Set, overwrite and delete roundtrip")
    func roundtrip() {
        let account = "test-keychain-roundtrip"
        defer { Keychain.set(nil, for: account) }

        Keychain.set("secret-123", for: account)
        #expect(Keychain.string(for: account) == "secret-123")

        Keychain.set("rotated", for: account)
        #expect(Keychain.string(for: account) == "rotated")

        Keychain.set(nil, for: account)
        #expect(Keychain.string(for: account) == nil)
    }
}

@Suite("Caption presets")
struct CaptionPresetTests {

    @Test("Viral pops color, Classic stays white, Minimal drops the stroke, Bold pulses")
    func presetStyles() {
        var theme = CaptionTheme()

        theme.preset = .viral
        var style = CaptionLayerBuilder.Style(of: theme)
        #expect(style.strokes && !style.pulses)

        theme.preset = .classic
        style = CaptionLayerBuilder.Style(of: theme)
        #expect(style.strokes && !style.pulses)

        theme.preset = .minimal
        style = CaptionLayerBuilder.Style(of: theme)
        #expect(!style.strokes && style.fontScale < 1)

        theme.preset = .bold
        style = CaptionLayerBuilder.Style(of: theme)
        #expect(style.pulses && style.fontScale > 1)
    }
}
