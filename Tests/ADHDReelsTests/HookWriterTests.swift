import Testing
@testable import ADHDReelsKit

@Suite("Крючок")
struct HookWriterTests {

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
