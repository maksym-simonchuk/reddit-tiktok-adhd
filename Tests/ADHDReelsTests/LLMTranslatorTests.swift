import Testing
@testable import ADHDReelsKit

@Suite("Проверка перевода моделью")
struct LLMTranslatorChecksTests {

    private let source = "I paid my father's debt for twelve years and he never said thank you."

    @Test("Обёртки вокруг перевода снимаются")
    func cleaning() {
        #expect(LLMTranslator.clean("  Я платил долг.  ") == "Я платил долг.")
        #expect(LLMTranslator.clean("Перевод: Я платил долг.") == "Я платил долг.")
        #expect(LLMTranslator.clean("\"Я платил долг.\"") == "Я платил долг.")
        #expect(LLMTranslator.clean("Я платил долг.<|im_end|>") == "Я платил долг.")
    }

    @Test("Годный перевод проходит")
    func passes() {
        let russian = "Я двенадцать лет платил долг отца, а он ни разу не сказал спасибо."
        #expect(LLMTranslator.accepts(russian, for: source))
    }

    @Test("Английский ответ не проходит")
    func english() {
        #expect(!LLMTranslator.accepts("I paid the debt for twelve years.", for: source))
        #expect(!LLMTranslator.accepts("", for: source))
    }

    @Test("Пересказ вдвое короче не проходит")
    func shortened() {
        #expect(!LLMTranslator.accepts("Платил долг.", for: source))
    }

    @Test("Уехавший в повтор ответ не проходит")
    func loop() {
        let repeated = Array(repeating: "долг", count: 60).joined(separator: " ")
        #expect(!LLMTranslator.accepts(repeated, for: source))
    }

    /// Заголовки короткие, и русский перевод у них закономерно длиннее.
    @Test("Короткий заголовок не отбраковывается за длину")
    func hook() {
        #expect(LLMTranslator.accepts("Я виноват, что съел торт?", for: "AITA for eating the cake?"))
    }
}

@Suite("Перевод моделью", .enabled(if: LLMTranslator.isAvailable, "нет модели — Scripts/fetch_llm.sh, и только на устройстве"))
struct LLMTranslatorLiveTests {

    @Test("Сегменты переводятся по порядку", .timeLimit(.minutes(5)))
    func translates() async throws {
        let draft = [
            ScriptSegment(kind: .hook, text: "Am I the asshole for telling my sister the truth at her wedding?"),
            ScriptSegment(kind: .body, text: "I, a 34-year-old man, finally told my wife about the debt. For twelve years I paid off my father's loan without telling anyone, roughly 21 dollars out of every 100 I earned. She said she felt betrayed, and my brother, a 29-year-old man, took her side. My dad still has not spoken to me. In short, I kept a secret for over a decade and now my marriage is on the edge."),
        ]

        let translated = try await LLMTranslator().translate(draft)

        #expect(translated.count == draft.count)
        #expect(translated.map(\.kind) == draft.map(\.kind))

        for segment in translated {
            // Качество перевода машиной не проверить — печатаем в лог прогона,
            // чтобы читать глазами: падежи, род и живость фразы.
            print("[\(segment.kind)] \(segment.text)")
            print("[\(segment.kind)→озвучка] \(RussianNormalizer().normalize(segment.text))")

            let letters = segment.text.filter(\.isLetter)
            let cyrillic = letters.count { $0.unicodeScalars.allSatisfy { (0x0400...0x04FF).contains($0.value) } }
            #expect(!letters.isEmpty)
            #expect(Double(cyrillic) / Double(letters.count) >= 0.8, "\(segment.text)")
        }
    }
}
