import FoundationModels
import Foundation

/// "Make this more engaging for Shorts": retells the story tighter and punchier while
/// keeping the events and the ending intact. Apple Intelligence first — it is already
/// on the device; otherwise the bundled Qwen3-4B; neither available (simulator) → nil,
/// and the button that offered the rewrite explains itself instead of failing silently.
public struct StoryRewriter: Sendable {

    public init() {}

    public var isModelAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return LLMTranslator.isAvailable
    }

    /// Returns the retold story, or nil when no model is available or the answer
    /// didn't survive validation. The caller keeps the original in both cases.
    public func rewrite(_ story: String, language: ReelLanguage = .english) async -> String? {
        let text = String(story.prefix(2400)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if case .available = SystemLanguageModel.default.availability {
            if let rewritten = await apple(text, language: language) { return rewritten }
        }

        return await local(text, language: language)
    }

    // MARK: - Apple Intelligence

    private func apple(_ story: String, language: ReelLanguage) async -> String? {
        do {
            let session = LanguageModelSession(instructions: Self.instructions(for: language))
            let response = try await session.respond(to: Self.prompt(story), generating: Draft.self)
            return Self.clean(response.content.story, original: story)
        } catch {
            return nil
        }
    }

    @Generable
    struct Draft {
        @Guide(description: "The retold story: same events and same ending, spoken-word style, no meta commentary")
        var story: String
    }

    // MARK: - Bundled model

    private func local(_ story: String, language: ReelLanguage) async -> String? {
        guard LLMTranslator.isAvailable else { return nil }

        let rewritten = try? await LLMTranslator().respond(
            instructions: Self.instructions(for: language),
            prompt: Self.prompt(story),
            maxTokens: 700
        )

        return rewritten.flatMap { Self.clean($0, original: story) }
    }

    // MARK: - Prompt

    /// The rules ban invention explicitly: a "more engaging" rewrite that adds drama
    /// the poster never wrote is a fabricated story published under a real permalink.
    private static func instructions(for language: ReelLanguage) -> String {
        """
        You rewrite forum stories into narration scripts for short vertical videos.
        Write in \(language.title). The entire answer must be in that language.
        Keep every event, every person and the ending exactly as told — invent nothing.
        Cut the throat-clearing: background that doesn't pay off, disclaimers, edits.
        Short spoken sentences, first person, present tension early.
        No emojis, no hashtags, no addressing the viewer, no meta commentary.
        Answer with the retold story only.
        """
    }

    private static func prompt(_ story: String) -> String {
        """
        Forum story:

        \(story)

        Retell this story for a short vertical video.
        """
    }

    // MARK: - Validation

    /// A rewrite that balloons past the original or collapses to a stub is the model
    /// summarizing or rambling, not retelling — the original is the safer script.
    static func clean(_ rewritten: String, original: String) -> String? {
        let tidy = rewritten
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard tidy.count >= 80 else { return nil }
        guard tidy.count <= max(400, original.count * 3 / 2) else { return nil }

        return tidy
    }
}
