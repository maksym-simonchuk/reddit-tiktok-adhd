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

    public func write(
        script: Script,
        subreddit: String,
        language: ReelLanguage = .russian
    ) async -> ReelDescription {
        guard isModelAvailable else { return Self.fallback(script: script, subreddit: subreddit, language: language) }

        do {
            let session = LanguageModelSession(instructions: Self.instructions(for: language))
            let response = try await session.respond(
                to: Self.prompt(script: script, subreddit: subreddit),
                generating: Draft.self
            )
            return Self.clean(response.content, script: script, subreddit: subreddit, language: language)
        } catch {
            return Self.fallback(script: script, subreddit: subreddit, language: language)
        }
    }

    // MARK: - Модель

    @Generable
    struct Draft {
        @Guide(description: "Заголовок-крючок, до 60 знаков: конфликт или цифра, обрыв на самом интересном")
        var title: String

        @Guide(description: "Два коротких предложения: завязка и прямой вопрос зрителю. Развязки нет")
        var body: String

        @Guide(description: "Хэштеги без решётки, по одному слову", .count(5))
        var tags: [String]
    }

    /// Подпись решает, остановят ли палец: её читают раньше, чем услышат первое слово.
    /// Поэтому правила жёсткие — обрыв на конфликте и ни намёка на развязку.
    private static func instructions(for language: ReelLanguage) -> String {
        """
        Ты пишешь подписи к коротким вертикальным видео.
        Пиши на языке: \(language.title). Весь ответ целиком на этом языке.
        Задача одна: остановить палец и заставить досмотреть до конца.
        Заголовок обрывай на самом остром месте — конфликт, цифра, обвинение.
        Развязку не называй ни в заголовке, ни в описании.
        Обращайся к зрителю на «ты», пиши как человек в переписке.
        Никаких кавычек, эмодзи и слова «шок».
        """
    }

    private static func prompt(script: Script, subreddit: String) -> String {
        // Модели хватает начала: дальше идут детали, которые в подпись всё равно не влезут.
        let excerpt = String(script.plainText.prefix(900))

        return """
        Рассказ с форума r/\(subreddit):

        \(excerpt)

        Напиши заголовок, описание и пять хэштегов для этого видео.
        Заголовок пойдёт на обложку крупными буквами — он должен читаться за секунду.
        """
    }

    // MARK: - Приведение в порядок

    private static func clean(
        _ draft: Draft,
        script: Script,
        subreddit: String,
        language: ReelLanguage
    ) -> ReelDescription {
        let title = shorten(tidy(draft.title))
        let body = tidy(draft.body)
        guard !title.isEmpty, !body.isEmpty else {
            return fallback(script: script, subreddit: subreddit, language: language)
        }

        let tags = draft.tags
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " #,.")) }
            .filter { !$0.isEmpty }
            .prefix(5)

        return ReelDescription(
            title: title,
            body: body,
            tags: tags.isEmpty ? spare(language, subreddit: subreddit).tags : Array(tags)
        )
    }

    private static func tidy(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "«", with: "")
            .replacingOccurrences(of: "»", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Тот же заголовок печатается на обложке: длинная строка ужимается там до нечитаемого
    /// кегля, поэтому режем по слову, а не по букве, и без многоточия — оно съедает место.
    static func shorten(_ title: String, limit: Int = 60) -> String {
        guard title.count > limit else { return title }

        var result = ""
        for word in title.split(separator: " ") {
            let next = result.isEmpty ? String(word) : result + " " + word
            if next.count > limit { break }
            result = next
        }

        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:—-"))
        return trimmed.isEmpty ? String(title.prefix(limit)) : trimmed
    }

    /// Запасной вариант: первое предложение сценария и есть крючок — сценарий
    /// именно так и собран, поэтому подпись получается осмысленной без модели.
    static func fallback(script: Script, subreddit: String, language: ReelLanguage = .russian) -> ReelDescription {
        let hook = script.segments.first(where: { $0.kind == .hook })?.text ?? script.plainText
        let title = shorten(hook.trimmingCharacters(in: .whitespacesAndNewlines))
        let spare = spare(language, subreddit: subreddit)

        return ReelDescription(
            title: title.isEmpty ? spare.title : title,
            body: spare.body,
            tags: spare.tags
        )
    }

    /// Подпись обязана быть на языке ролика даже без модели: русский текст под испанской
    /// озвучкой выглядит как чужой ролик, залитый по ошибке.
    private static func spare(
        _ language: ReelLanguage,
        subreddit: String
    ) -> (title: String, body: String, tags: [String]) {
        switch language {
        case .russian: (
            "История, которую он никому не рассказывал",
            "История с форума r/\(subreddit). Досмотри до конца — а ты бы так смог?",
            ["истории", "reddit", "рассказ", "жиза", "сюжет"]
        )
        case .english: (
            "The story he never told anyone",
            "A story from r/\(subreddit). Watch to the end — would you have done that?",
            ["stories", "reddit", "storytime", "reallife", "plottwist"]
        )
        case .spanish: (
            "La historia que nunca contó",
            "Una historia de r/\(subreddit). Míralo hasta el final: ¿tú lo habrías hecho?",
            ["historias", "reddit", "relatos", "vidareal", "giro"]
        )
        case .portuguese: (
            "A história que ele nunca contou",
            "Uma história do r/\(subreddit). Assista até o fim — você faria isso?",
            ["historias", "reddit", "relatos", "vidareal", "reviravolta"]
        )
        }
    }
}
