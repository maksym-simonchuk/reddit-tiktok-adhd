import Foundation
import MLX
import MLXLLM
import MLXLMCommon

/// EN → RU языковой моделью Ruadapt-Qwen3-4B. Apple Translation переводит по предложению
/// и не знает, о чём рассказ: падежи после числительных, род прошедшего времени и
/// сленг у него разъезжаются, а озвучка честно проговаривает получившееся.
/// Модель держит фразу целиком и пишет так, как рассказывают вслух.
///
/// Ruadapt — Qwen3 с переученным под русский токенизатором. На одном и том же тексте
/// ванильная Qwen3 в каждом прогоне писала «почувствовала обманутую» и «моё браковое
/// состояние», а Ruadapt — «почувствовала предательство» и «мой брак на грани».
///
/// Считает Metal, то есть только на устройстве. Нет модели, нет Metal, ответ не
/// прошёл проверку — переводит Apple Translation: пусть коряво, но всегда.
public actor LLMTranslator {

    /// Что модель должна сделать с текстом. Правила короткие и запретительные:
    /// длинные инструкции она начинает пересказывать в ответе.
    ///
    /// Числа модель обязана оставить цифрами. Стоило попросить её писать их словами —
    /// и она начинала их выдумывать: «34-year-old» становился «тридцатилетним»,
    /// «twelve years» — «десятью годами», а брат из «29» — «двадцатинадцатилетним».
    /// Цифры она переносит без ошибок, а прописью их доводит `RussianNormalizer`.
    private static let rules = """
        Ты переводишь посты с Reddit на русский язык для озвучки в коротком видео.

        Правила:
        - переводи весь текст целиком, ничего не добавляя и не выбрасывая;
        - пиши живым разговорным русским, как рассказывают историю вслух, но грамотно: \
        падежи, род, число и вид глагола должны быть согласованы;
        - сленг и идиомы передавай русским аналогом, а не дословно;
        - «Am I the asshole» — это вопрос «Я виноват?» («Я виновата?» от лица женщины): \
        рассказчик спрашивает, виноват ли он, а не утверждает, что был прав;
        - числа, даты и суммы переноси цифрами ровно так, как в оригинале, и никогда \
        не проговаривай их словами: «34 года», «21 доллар из каждых 100», «40%»;
        - имена, бренды и ники пиши русскими буквами так, как их произносят: \
        Google — Гугл, John — Джон, Discord — Дискорд;
        - в ответе только перевод: без пояснений, заголовков и кавычек вокруг текста.
        """

    /// Пол рассказчика дописывается отдельной строкой: в английском его нет ни в одном
    /// глаголе, и без подсказки род в русском переводе плавает от предложения к предложению.
    private static func instructions(narrator: Narrator.Gender?) -> String {
        guard let narrator else { return rules }
        return rules + "\n" + narrator.rule
    }

    /// Температура низкая: нужен перевод, а не пересказ своими словами.
    private static let parameters = GenerateParameters(
        maxTokens: 1024,
        temperature: 0.3,
        topP: 0.9,
        repetitionPenalty: 1.05
    )

    private let fallback = Translator()

    public init() {}

    /// Папка с весами. В симуляторе её нет намеренно: MLX считает на Metal, а в
    /// симуляторе он падает — там перевод идёт через Apple Translation.
    public static var modelURL: URL? {
        #if targetEnvironment(simulator)
        return nil
        #else
        guard let url = Bundle.main.resourceURL?.appending(path: "Models/ruadapt-qwen3-4b"),
              FileManager.default.fileExists(atPath: url.appending(path: "model.safetensors").path)
        else { return nil }

        return url
        #endif
    }

    public static var isAvailable: Bool { modelURL != nil }

    /// Возвращает сегменты с русским текстом, сохраняя порядок и `kind`.
    public func translate(_ segments: [ScriptSegment]) async throws -> [ScriptSegment] {
        guard let directory = Self.modelURL, let container = try? await Self.load(directory) else {
            return try await fallback.translate(segments)
        }

        // Веса занимают 2.3 ГБ, и следом за переводом в память поедут графы
        // озвучки. Держать модель дольше одного сценария нельзя.
        defer { MLX.GPU.clearCache() }

        // Пол ищем по всему черновику, а не по сегменту: пометка «(28F)» стоит один раз,
        // обычно в первом абзаце, а род нужен во всех.
        let narrator = Narrator.gender(of: segments.map(\.text).joined(separator: " "))

        var translated: [ScriptSegment?] = []
        for segment in segments {
            try Task.checkCancellation()
            let russian = try? await Self.answer(for: segment.text, narrator: narrator, in: container)
            translated.append(russian.map { ScriptSegment(kind: segment.kind, text: $0) })
        }

        return try await patch(translated, from: segments)
    }

    /// То, что модель не осилила, дописывает Apple Translation. По одному сегменту:
    /// пакетный вызов вернул бы только удавшиеся, и порядок бы разъехался.
    private func patch(_ translated: [ScriptSegment?], from segments: [ScriptSegment]) async throws -> [ScriptSegment] {
        var result = translated
        var failure: Error?

        for index in translated.indices where translated[index] == nil {
            do {
                result[index] = try await fallback.translate([segments[index]]).first
            } catch {
                failure = error
            }
        }

        let kept = result.compactMap { $0 }
        if kept.isEmpty, let failure { throw failure }

        return kept
    }

    // MARK: - Модель

    private static func load(_ directory: URL) async throws -> ModelContainer {
        // Metal кеширует буферы между вызовами. На телефоне это гигабайты сверх
        // весов, а выигрыш нам не нужен: перевод в ролике идёт один раз.
        MLX.GPU.set(cacheLimit: 32 * 1024 * 1024)

        return try await LLMModelFactory.shared.loadContainer(
            configuration: ModelConfiguration(directory: directory)
        )
    }

    /// Правка по указанию человека: он ткнул в кусок перевода, который врёт, а модель
    /// переписывает предложение целиком, зная, где ошиблась. Запасного пути тут нет —
    /// Apple Translation вернёт ровно то же, что и в первый раз.
    public func retranslate(source: String, previous: String, wrong: String) async throws -> String {
        guard let directory = Self.modelURL, let container = try? await Self.load(directory) else {
            throw Failure.unavailable
        }
        defer { MLX.GPU.clearCache() }

        let task = """
            \(source)

            Прошлый перевод: \(previous)
            В нём неверно переведено: «\(wrong)». Переведи заново, исправив это место.
            """

        return try await Self.answer(
            for: task,
            narrator: Narrator.gender(of: source),
            checkedAgainst: source,
            in: container
        )
    }

    /// Та же модель, но со своей инструкцией: она единственная сильная на устройстве,
    /// а писать текст умеет не хуже, чем переводить. Ответ отдаётся как есть —
    /// проверять его на язык и длину вызывающему виднее.
    public func respond(instructions: String, prompt: String, maxTokens: Int) async throws -> String {
        guard let directory = Self.modelURL, let container = try? await Self.load(directory) else {
            throw Failure.unavailable
        }
        defer { MLX.GPU.clearCache() }

        return try await Self.generate(
            system: instructions,
            user: prompt,
            maxTokens: maxTokens,
            in: container
        )
    }

    /// Один сегмент.
    ///
    /// `checkedAgainst` — текст, с длиной которого сверяется ответ: при правке в запрос
    /// уезжает ещё и прошлый перевод, и сверяться с ним по длине нельзя.
    private static func answer(
        for text: String,
        narrator: Narrator.Gender?,
        checkedAgainst source: String? = nil,
        in container: ModelContainer
    ) async throws -> String {
        let russian = try await generate(
            system: instructions(narrator: narrator),
            user: text,
            maxTokens: parameters.maxTokens ?? 1024,
            in: container
        )
        guard accepts(russian, for: source ?? text) else { throw Failure.rejected }

        return russian
    }

    /// Разметку ChatML пишем руками, а не через `applyChatTemplate`: шаблон Qwen3
    /// разбирает чужие сообщения задом наперёд и на Swift-jinja не заводится,
    /// а сама разметка — четыре маркера.
    private static func generate(
        system: String,
        user: String,
        maxTokens: Int,
        in container: ModelContainer
    ) async throws -> String {
        let prompt = """
            <|im_start|>system
            \(system)<|im_end|>
            <|im_start|>user
            \(user)<|im_end|>
            <|im_start|>assistant

            """

        let parameters = {
            var parameters = Self.parameters
            parameters.maxTokens = maxTokens
            return parameters
        }()

        let output = try await container.perform { context in
            let result = try MLXLMCommon.generate(
                input: LMInput(tokens: MLXArray(context.tokenizer.encode(text: prompt))),
                parameters: parameters,
                context: context
            ) { (_: [Int]) in
                // Единственная точка, где счёт можно прервать: сам `generate` крутит
                // цикл по токенам и на отмену задачи не смотрит.
                Task.isCancelled ? .stop : .more
            }

            return result.output
        }

        try Task.checkCancellation()

        return clean(output)
    }

    private enum Failure: LocalizedError {
        case rejected
        case unavailable

        var errorDescription: String? {
            switch self {
            case .rejected: "Модель ответила не переводом."
            case .unavailable: "Модель перевода не установлена — правка работает только на устройстве."
            }
        }
    }

    // MARK: - Проверка ответа

    /// Модель иногда представляет свою работу или берёт перевод в кавычки —
    /// в озвучке это лишний текст.
    static func clean(_ raw: String) -> String {
        var text = raw
        if let marker = text.range(of: "<|") { text = String(text[..<marker.lowerBound]) }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        for label in ["Перевод:", "Translation:"] where text.hasPrefix(label) {
            text = String(text.dropFirst(label.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if text.count > 1, text.hasPrefix("\""), text.hasSuffix("\"") {
            text = String(text.dropFirst().dropLast())
        }

        return text
    }

    /// Три способа испортить ролик: ответить по-английски, пересказать вдвое короче
    /// и уехать в повтор одного слова до упора. Всё три ловятся по тексту.
    static func accepts(_ text: String, for source: String) -> Bool {
        let letters = text.filter(\.isLetter)
        guard !letters.isEmpty else { return false }

        let cyrillic = letters.count { $0.unicodeScalars.allSatisfy { (0x0400...0x04FF).contains($0.value) } }
        guard Double(cyrillic) / Double(letters.count) >= 0.8 else { return false }

        let words = text.split(whereSeparator: \.isWhitespace).count
        let expected = source.split(whereSeparator: \.isWhitespace).count
        // Запас в пять слов — для заголовков: там «AITA for this?» в три слова
        // разворачивается в русскую фразу вдвое длиннее, и это нормально.
        return words * 2 >= expected && words <= expected * 2 + 5
    }
}
