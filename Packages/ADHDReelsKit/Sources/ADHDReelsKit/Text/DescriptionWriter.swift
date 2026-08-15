import FoundationModels
import Foundation

/// Пишет подпись к ролику по мотивам рассказа: заголовок, пара предложений и теги.
///
/// Работает через Apple Intelligence, если она есть на устройстве. Если нет —
/// собирает подпись из самого сценария. Пустого поля «Описание» не бывает никогда:
/// ролик без подписи бесполезен, а модель есть не у всех.
public struct DescriptionWriter: Sendable {

    public init() {}

    public var isModelAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    public func write(script: Script, subreddit: String) async -> ReelDescription {
        guard isModelAvailable else { return Self.fallback(script: script, subreddit: subreddit) }

        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(
                to: Self.prompt(script: script, subreddit: subreddit),
                generating: Draft.self
            )
            return Self.clean(response.content, script: script, subreddit: subreddit)
        } catch {
            return Self.fallback(script: script, subreddit: subreddit)
        }
    }

    // MARK: - Модель

    @Generable
    struct Draft {
        @Guide(description: "Заголовок-крючок на русском, до 70 знаков, без кавычек и хэштегов")
        var title: String

        @Guide(description: "Описание для TikTok на русском: два-три коротких предложения без спойлера концовки")
        var body: String

        @Guide(description: "Хэштеги на русском без решётки, по одному слову", .count(5))
        var tags: [String]
    }

    private static let instructions = """
    Ты пишешь подписи к коротким вертикальным видео на русском языке.
    Пиши живо и просто, как человек, а не как пресс-релиз.
    Не пересказывай концовку — задача подписи в том, чтобы досмотрели.
    Никаких кавычек, эмодзи и английских слов.
    """

    private static func prompt(script: Script, subreddit: String) -> String {
        // Модели хватает начала: дальше идут детали, которые в подпись всё равно не влезут.
        let excerpt = String(script.plainText.prefix(900))

        return """
        Рассказ с форума r/\(subreddit):

        \(excerpt)

        Напиши заголовок, описание и пять хэштегов для этого видео.
        """
    }

    // MARK: - Приведение в порядок

    private static func clean(_ draft: Draft, script: Script, subreddit: String) -> ReelDescription {
        let title = tidy(draft.title)
        let body = tidy(draft.body)
        guard !title.isEmpty, !body.isEmpty else { return fallback(script: script, subreddit: subreddit) }

        let tags = draft.tags
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " #,.")) }
            .filter { !$0.isEmpty }
            .prefix(5)

        return ReelDescription(
            title: title,
            body: body,
            tags: tags.isEmpty ? defaultTags : Array(tags)
        )
    }

    private static func tidy(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "«", with: "")
            .replacingOccurrences(of: "»", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Запасной вариант: первое предложение сценария и есть крючок — сценарий
    /// именно так и собран, поэтому подпись получается осмысленной без модели.
    static func fallback(script: Script, subreddit: String) -> ReelDescription {
        let hook = script.segments.first(where: { $0.kind == .hook })?.text ?? script.plainText
        let title = String(hook.prefix(70)).trimmingCharacters(in: .whitespacesAndNewlines)

        return ReelDescription(
            title: title.isEmpty ? "История с Reddit" : title,
            body: "История с форума r/\(subreddit). Досмотрите до конца — там поворот.",
            tags: defaultTags
        )
    }

    private static let defaultTags = ["истории", "reddit", "рассказ", "жиза", "сюжет"]
}
