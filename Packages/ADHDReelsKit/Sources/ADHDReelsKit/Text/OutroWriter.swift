import FoundationModels
import Foundation

/// Последняя фраза ролика: вопрос, на который зритель отвечает в комментариях.
/// Ролик заканчивается там, где у истории нет ответа, — и этот ответ зритель уже
/// придумал, пока смотрел. Вопрос нужен, чтобы он его дописал вслух.
///
/// Пишет его модель по самой истории, как и крючок: дежурное «а что думаете вы?»
/// проматывают, а «кому платить за свадьбу сестры?» спорят. Модели нет (симулятор) —
/// остаётся общий вопрос из таблицы: без него ролик просто обрывается на середине
/// чужой ссоры.
public struct OutroWriter: Sendable {

    public init() {}

    public func write(script: Script, language: ReelLanguage = .russian) async -> String {
        let story = String(script.plainText.prefix(900))
        guard !story.isEmpty else { return Self.fallback(for: language) }

        if case .available = SystemLanguageModel.default.availability {
            if let question = await apple(story, language: language) { return question }
        }

        return await local(story, language: language) ?? Self.fallback(for: language)
    }

    // MARK: - Apple Intelligence

    private func apple(_ story: String, language: ReelLanguage) async -> String? {
        do {
            let session = LanguageModelSession(instructions: Self.instructions(for: language))
            let response = try await session.respond(to: Self.prompt(story), generating: Draft.self)
            return Self.question(response.content.question, language: language)
        } catch {
            return nil
        }
    }

    @Generable
    struct Draft {
        @Guide(description: "Один вопрос зрителю до 60 знаков про спорное место истории, со знаком вопроса")
        var question: String
    }

    // MARK: - Модель из бандла

    private func local(_ story: String, language: ReelLanguage) async -> String? {
        guard LLMTranslator.isAvailable else { return nil }

        let question = try? await LLMTranslator().respond(
            instructions: Self.instructions(for: language),
            prompt: Self.prompt(story),
            maxTokens: 80
        )

        return question.flatMap { Self.question($0, language: language) }
    }

    // MARK: - Запрос

    /// Просьбы подписаться и поставить лайк запрещены прямо: модель дописывает их
    /// сама, а зритель на них уходит — комментарий пишут не по просьбе, а из спора.
    private static func instructions(for language: ReelLanguage) -> String {
        """
        Ты пишешь последнюю фразу короткого вертикального видео.
        Пиши на языке: \(language.title). Весь ответ целиком на этом языке.
        Задача одна: заставить зрителя ответить в комментариях.
        Найди в истории место, где люди разойдутся во мнениях, и спроси зрителя прямо о нём.
        Один короткий вопрос со знаком вопроса, не длиннее шестидесяти знаков, обращайся на «ты».
        Никаких просьб подписаться, поставить лайк и написать комментарий — только сам вопрос.
        Никаких кавычек и эмодзи. В ответе только сама фраза.
        """
    }

    private static func prompt(_ story: String) -> String {
        """
        Рассказ с форума:

        \(story)

        Напиши последнюю фразу видео — вопрос зрителю по этому рассказу.
        """
    }

    // MARK: - Приведение в порядок

    /// Чистка та же, что у крючка, плюс знак вопроса: без него модель отвечает
    /// утверждением, и вместо спора получается вывод, к которому нечего добавить.
    private static func question(_ text: String, language: ReelLanguage) -> String? {
        guard let clean = HookWriter.clean(text, language: language), clean.hasSuffix("?") else { return nil }
        return clean
    }

    private static func fallback(for language: ReelLanguage) -> String {
        switch language {
        case .russian: "А ты на чьей стороне?"
        case .english: "So whose side are you on?"
        case .spanish: "¿Y tú de qué lado estás?"
        case .portuguese: "E você, de que lado está?"
        }
    }
}
