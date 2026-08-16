import Testing
@testable import ADHDReelsKit

@Suite("Подача: темп, разброс и паузы")
struct SpeechDeliveryTests {

    private func phrase(_ text: String, kind: ScriptSegment.Kind = .body) -> SpeechDelivery.Phrase {
        SpeechDelivery.Phrase(kind: kind, text: text)
    }

    @Test("Сценарий режется на предложения, и каждое помнит свой вид")
    func phrasesKeepKind() {
        let script = Script(segments: [
            ScriptSegment(kind: .hook, text: "Хук. Второе предложение."),
            ScriptSegment(kind: .body, text: "Тело рассказа."),
        ])

        let phrases = SpeechDelivery.phrases(of: script)
        #expect(phrases.map(\.kind) == [.hook, .hook, .body])
    }

    @Test("Разброс темпа держится в пределах слышимого и повторяется")
    func jitterIsStableAndBounded() {
        let texts = ["Первое предложение.", "Совсем другое предложение тут.", "И третье."]
        let values = texts.map { SpeechDelivery.jitter(of: phrase($0)) }

        #expect(values.allSatisfy { $0 >= 0.94 && $0 <= 1.06 })
        #expect(Set(values).count > 1)
        #expect(values == texts.map { SpeechDelivery.jitter(of: phrase($0)) })
    }

    @Test("Хук держит паузу дольше обычной фразы")
    func hookHoldsLongerPause() {
        // Абсолютные значения едут вместе с темпом читки, поэтому сверяем порядок.
        let next = phrase("Дальше.")
        let hook = SpeechDelivery.pause(after: phrase("Хук.", kind: .hook), before: next)
        let question = SpeechDelivery.pause(after: phrase("Вопрос?"), before: next)
        let period = SpeechDelivery.pause(after: phrase("Точка."), before: next)

        #expect(hook > question)
        #expect(question > period)
        #expect(period > 0)
        #expect(SpeechDelivery.pause(after: phrase("Конец."), before: nil) == 0)
    }

    @Test("Перед вопросом зрителю пауза такая же, как после хука")
    func outroGetsRoom() {
        let outro = phrase("А ты на чьей стороне?", kind: .outro)
        let before = SpeechDelivery.pause(after: phrase("Конец истории."), before: outro)
        let hook = SpeechDelivery.pause(after: phrase("Хук.", kind: .hook), before: phrase("Дальше."))

        #expect(before == hook)
    }
}
