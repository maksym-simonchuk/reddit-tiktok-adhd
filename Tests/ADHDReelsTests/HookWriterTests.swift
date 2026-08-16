import Testing
@testable import ADHDReelsKit

@Suite("Крючок")
struct HookWriterTests {

    private let story = Script(segments: [
        ScriptSegment(kind: .hook, text: "Виноват ли я, что скрыл от жены кредит отца?"),
        ScriptSegment(kind: .body, text: "Двенадцать лет я выплачивал кредит отца и не сказал жене ни слова: каждый пятый рубль уходил туда. Она узнала случайно, из выписки, и говорит, что это предательство. Брат встал на её сторону, отец со мной не разговаривает."),
    ])

    /// На симуляторе моделей нет и крючка не будет — тогда роль первой фразы играет
    /// заголовок треда, и проверять здесь нечего. На устройстве печатаем написанное:
    /// острота фразы машиной не проверяется, её читают глазами.
    @Test("Крючок пишется по истории и влезает в строку субтитра", .timeLimit(.minutes(5)))
    func writes() async {
        let hook = await HookWriter().write(script: story)
        print("[крючок] \(hook ?? "модели нет — первой строкой останется заголовок")")

        guard let hook else { return }
        #expect(hook.count <= 70)
        #expect(!hook.contains("\""))
    }

    @Test("Кавычки вокруг фразы уходят: диктор читает их паузой")
    func stripsQuotes() {
        #expect(HookWriter.clean("«Она молчала об этом двенадцать лет»", language: .russian)
            == "Она молчала об этом двенадцать лет")
    }

    @Test("Пересказ режется до одной фразы")
    func keepsFirstSentence() {
        let long = "Она молчала об этом двенадцать лет. Потом пришло письмо, и всё вскрылось разом."
        #expect(HookWriter.clean(long, language: .russian) == "Она молчала об этом двенадцать лет.")
    }

    @Test("Длинная фраза обрывается на границе мысли, а не на полуслове")
    func cutsOnClause() {
        let long = "Ты думал, сорок тысяч — это на маму, а на деле это долг брата, который он скрывал"
        #expect(HookWriter.clean(long, language: .russian) == "Ты думал, сорок тысяч — это на маму, а на деле это долг брата")
    }

    @Test("Ответ на чужом языке выбрасывается, а не звучит посреди ролика")
    func rejectsWrongLanguage() {
        #expect(HookWriter.clean("She never said a word for twelve years", language: .russian) == nil)
        #expect(HookWriter.clean("Она молчала двенадцать лет", language: .english) == nil)
        #expect(HookWriter.clean("She never said a word", language: .english) == "She never said a word")
    }
}
