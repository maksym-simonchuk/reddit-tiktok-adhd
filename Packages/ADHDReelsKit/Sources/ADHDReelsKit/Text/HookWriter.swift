import FoundationModels
import Foundation

/// Первая фраза ролика: за неё решают смотреть или листать. Заголовок треда на эту роль
/// не годится — он написан для форума, объясняет обстоятельства и часто выдаёт развязку.
/// Дежурное «досмотри до конца» тоже не годится: оно ничего не обещает.
///
/// Поэтому крючок пишет модель по самой истории — берёт самое острое место и обрывает
/// на нём. Сначала Apple Intelligence: она уже в системе и не тянет память. Если она
/// выключена — Qwen3-4B из бандла, тот же, что переводит. Нет ни одной (симулятор) —
/// `nil`, и ролик начинается с заголовка треда, который тоже написан, чтобы на него нажали.
public struct HookWriter: Sendable {

    public init() {}

    public var isModelAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return LLMTranslator.isAvailable
    }

    public func write(script: Script, language: ReelLanguage = .russian) async -> String? {
        let story = String(script.plainText.prefix(900))
        guard !story.isEmpty else { return nil }

        if case .available = SystemLanguageModel.default.availability {
            if let hook = await apple(story, language: language) { return hook }
        }

        return await local(story, language: language)
    }

    // MARK: - Apple Intelligence

    private func apple(_ story: String, language: ReelLanguage) async -> String? {
        do {
            let session = LanguageModelSession(instructions: Self.instructions(for: language))
            let response = try await session.respond(to: Self.prompt(story), generating: Draft.self)
            return Self.clean(response.content.hook, language: language)
        } catch {
            return nil
        }
    }

    @Generable
    struct Draft {
        @Guide(description: "Одна фраза до 70 знаков: самая острая деталь истории, обрыв на ней, развязки нет")
        var hook: String
    }

    // MARK: - Модель из бандла

    /// 80 токенов: длиннее крючка не бывает, а обрывать генерацию по счётчику дешевле,
    /// чем ждать, пока модель допишет второй абзац и мы его выбросим.
    private func local(_ story: String, language: ReelLanguage) async -> String? {
        guard LLMTranslator.isAvailable else { return nil }

        let hook = try? await LLMTranslator().respond(
            instructions: Self.instructions(for: language),
            prompt: Self.prompt(story),
            maxTokens: 80
        )

        return hook.flatMap { Self.clean($0, language: language) }
    }

    // MARK: - Запрос

    /// Правила жёсткие, потому что модель по умолчанию пересказывает начало рассказа —
    /// а начало почти всегда про обстоятельства, и на нём листают.
    private static func instructions(for language: ReelLanguage) -> String {
        """
        Ты пишешь первую фразу короткого вертикального видео.
        Пиши на языке: \(language.title). Весь ответ целиком на этом языке.
        Задача одна: за две секунды остановить палец и заставить досмотреть до конца.
        Возьми самое острое место истории — обман, цифру, обвинение, поворот — и оборви на нём.
        Развязку не называй: за ней зритель и должен досмотреть.
        Одно короткое разговорное предложение, не длиннее шестидесяти знаков, обращайся на «ты».
        Никаких кавычек, эмодзи, слова «шок» и обещаний вроде «досмотри до конца».
        В ответе только сама фраза.
        """
    }

    private static func prompt(_ story: String) -> String {
        // Модели хватает начала: дальше идут детали, которые в одну фразу всё равно не влезут.
        """
        Рассказ с форума:

        \(story)

        Напиши первую фразу видео по этому рассказу.
        """
    }

    // MARK: - Приведение в порядок

    /// Кавычки модель ставит охотно, а диктор читает их паузой. Ответ не на том языке
    /// отбрасываем целиком: он бы прозвучал чужим голосом посреди ролика.
    static func clean(_ hook: String, language: ReelLanguage) -> String? {
        let tidy = hook
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "«", with: "")
            .replacingOccurrences(of: "»", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let short = shorten(tidy)
        guard !short.isEmpty, isCyrillic(short) == (language == .russian) else { return nil }

        return short
    }

    /// Фраза на два вдоха — уже не крючок, а пересказ. Длинную режем по границе куска
    /// мысли: обрыв на запятой или тире звучит как задержанное дыхание, а обрыв по
    /// слову — как сбой синтезатора («…это долг брата, который»).
    private static func shorten(_ text: String) -> String {
        guard text.count > limit else { return text }

        let head = Sentences.of(text).first ?? text
        guard head.count > limit else { return head }

        let start = head.prefix(limit)
        if let boundary = start.lastIndex(where: { breaks.contains($0) }) {
            let clause = String(start[..<boundary]).trimmingCharacters(in: .whitespaces)
            if clause.count > limit / 3 { return clause }
        }

        return DescriptionWriter.shorten(head, limit: limit)
    }

    private static let limit = 70
    private static let breaks: Set<Character> = [",", ";", ":", "—", "–", "-"]

    private static func isCyrillic(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) }
    }
}
