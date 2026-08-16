import Testing
@testable import ADHDReelsKit

@Suite("Возврат ё")
struct YoficatorTests {

    private let yoficator = Yoficator(forms: [
        "еще": "ещё",
        "нашел": "нашёл",
        "ее": "её",
        "Алены": "Алёны",
    ])

    @Test("Слово из словаря получает ё")
    func replaces() {
        #expect(yoficator.apply(to: "Он нашел ее письмо.") == "Он нашёл её письмо.")
    }

    @Test("Заглавная в начале предложения сохраняется")
    func keepsCase() {
        #expect(yoficator.apply(to: "Еще раз?") == "Ещё раз?")
        #expect(yoficator.apply(to: "письмо Алены") == "письмо Алёны")
    }

    @Test("Слов вне словаря не трогаем: «все» и «всё» пишутся одинаково")
    func leavesAmbiguous() {
        #expect(yoficator.apply(to: "Все ушли, и все.") == "Все ушли, и все.")
    }

    @Test("Пустой словарь ничего не меняет")
    func emptyDictionary() {
        #expect(Yoficator(forms: [:]).apply(to: "Он нашел ее.") == "Он нашел ее.")
    }
}
