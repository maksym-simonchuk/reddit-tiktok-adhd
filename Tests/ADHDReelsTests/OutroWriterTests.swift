import Testing
@testable import ADHDReelsKit

@Suite("Вопрос зрителю в конце ролика")
struct OutroWriterTests {

    private let story = Script(segments: [
        ScriptSegment(kind: .hook, text: "Я двенадцать лет молчал о чужом долге."),
        ScriptSegment(kind: .body, text: "Я выплачивал кредит отца и не сказал жене ни слова: каждый пятый рубль уходил туда. Она узнала случайно и говорит, что это предательство. Брат встал на её сторону, отец со мной не разговаривает."),
    ])

    /// На симуляторе моделей нет, и проверяется запасной вопрос; на устройстве —
    /// написанный по истории. Требования к обоим одни и те же, поэтому тест один.
    @Test("Вопрос кончается знаком вопроса и влезает в строку субтитра", .timeLimit(.minutes(5)))
    func writes() async {
        let outro = await OutroWriter().write(script: story)

        // Спорность вопроса машиной не проверить — печатаем, чтобы читать глазами.
        print("[вопрос] \(outro)")

        #expect(outro.hasSuffix("?"))
        #expect(outro.count <= 70)
    }

    @Test("Пустой сценарий не оставляет ролик без вопроса")
    func emptyScript() async {
        #expect(await OutroWriter().write(script: Script(segments: [])) == "А ты на чьей стороне?")
    }
}
