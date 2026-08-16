import Testing
@testable import ADHDReelsKit

@Suite("Язык озвучки")
struct ReelLanguageTests {

    @Test("Английский сценарий не проходит русскую нормализацию")
    func keepsLatin() {
        var options = ScriptWriter.Options()
        options.language = .english

        let script = ScriptWriter(options: options).finish(
            [ScriptSegment(kind: .body, text: "I paid the debt for 12 years.")],
            hook: "She never said a word for 12 years"
        )

        #expect(script.segments.map(\.text) == [
            "She never said a word for 12 years",
            "I paid the debt for 12 years.",
        ])
    }

    @Test("Русский сценарий по-прежнему разворачивает цифры словами")
    func spellsRussianNumbers() {
        let script = ScriptWriter().finish([ScriptSegment(kind: .body, text: "Я платил долг 12 лет.")])
        #expect(script.segments.last?.text.contains("двенадцать") == true)
    }

    @Test("Перевод нужен всем, кроме английского")
    func translationNeed() {
        #expect(!ReelLanguage.english.needsTranslation)
        #expect(ReelLanguage.allCases.filter(\.needsTranslation).count == 3)
    }
}

private extension Character {
    var isCyrillic: Bool {
        unicodeScalars.allSatisfy { (0x0400...0x04FF).contains($0.value) }
    }
}
