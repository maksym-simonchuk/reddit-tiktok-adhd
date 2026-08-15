import Testing
@testable import ADHDReelsKit

@Suite("Нормализация русского текста")
struct RussianNormalizerTests {

    private let normalizer = RussianNormalizer()

    @Test("Целые числа читаются словами")
    func integers() {
        #expect(normalizer.normalize("мне 21 год") == "мне двадцать один год")
        #expect(normalizer.normalize("в 2024 всё изменилось") == "в две тысячи двадцать четыре всё изменилось")
    }

    @Test("Дробное число не разваливается на два")
    func decimals() {
        #expect(normalizer.normalize("вес 3,5 кг") == "вес три целых пять десятых кг")
    }

    @Test("Число не слипается со следующим словом")
    func numberSpacing() {
        #expect(normalizer.normalize("5 яблок") == "пять яблок")
    }

    @Test("Процент склоняется по числу")
    func percentAgreement() {
        #expect(normalizer.normalize("1%") == "один процент")
        #expect(normalizer.normalize("2%") == "два процента")
        #expect(normalizer.normalize("5%") == "пять процентов")
        #expect(normalizer.normalize("11%") == "одиннадцать процентов")
        #expect(normalizer.normalize("21%") == "двадцать один процент")
    }

    @Test("Процент через пробел тоже склеивается")
    func percentWithSpace() {
        #expect(normalizer.normalize("рост 3 %") == "рост три процента")
    }

    @Test("Сокращения раскрываются")
    func abbreviations() {
        #expect(normalizer.normalize("яблоки, груши и т.д.") == "яблоки, груши и так далее")
        #expect(normalizer.normalize("т.к. было поздно") == "так как было поздно")
        #expect(normalizer.normalize("т. е. никак") == "то есть никак")
    }

    @Test("Латиница транслитерируется, а не выбрасывается")
    func latin() {
        let result = normalizer.normalize("купил iPhone вчера")
        #expect(result.hasPrefix("купил "))
        #expect(result.hasSuffix(" вчера"))
        #expect(!result.contains("iPhone"))
        #expect(result != "купил  вчера")
    }

    @Test("Эмодзи и спецсимволы вырезаются")
    func specialCharacters() {
        #expect(normalizer.normalize("это дичь 🔥 #хайп @ник") == "это дичь хайп ник")
    }

    @Test("Повторная пунктуация схлопывается")
    func punctuation() {
        #expect(normalizer.normalize("серьёзно?!?! ага...") == "серьёзно? ага.")
    }

    @Test("В результате нет символов вне разрешённого набора")
    func charset() {
        let raw = "Он сказал: «нет!» — 50% людей ушли 😤 (see u/bob) ~2,5 часа спустя..."
        let result = normalizer.normalize(raw)
        let allowed = Set(".,!?;:'\"- ")

        for character in result {
            let isCyrillic = character.unicodeScalars.allSatisfy { (0x0400...0x04FF).contains($0.value) }
            #expect(
                isCyrillic || character.isNumber || allowed.contains(character),
                "недопустимый символ \(character) в «\(result)»"
            )
        }
    }

    @Test("Пустой и мусорный ввод дают пустую строку")
    func empty() {
        #expect(normalizer.normalize("") == "")
        #expect(normalizer.normalize("🔥🔥🔥") == "")
    }
}
