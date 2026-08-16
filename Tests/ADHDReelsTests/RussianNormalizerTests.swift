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

    @Test("Бренды и имена читаются как их произносят")
    func brands() {
        #expect(RussianNormalizer.transcribe("Google") == "Гугл")
        #expect(RussianNormalizer.transcribe("Discord") == "Дискорд")
        #expect(RussianNormalizer.transcribe("John") == "Джон")
        #expect(RussianNormalizer.transcribe("iPhone") == "ифон")
        #expect(RussianNormalizer.transcribe("Netflix") == "Нетфликс")
        #expect(RussianNormalizer.transcribe("YouTube") == "Ютуб")
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
        let allowed = Set(".,!?;:'\"-—– ")

        for character in result {
            let isCyrillic = character.unicodeScalars.allSatisfy { (0x0400...0x04FF).contains($0.value) }
            #expect(
                isCyrillic || character.isNumber || allowed.contains(character),
                "недопустимый символ \(character) в «\(result)»"
            )
        }
    }

    @Test("Тире доживает до синтезатора: на нём он делает паузу")
    func keepsDash() {
        #expect(normalizer.normalize("Он — мой отец.") == "Он — мой отец.")
    }

    @Test("Пустой и мусорный ввод дают пустую строку")
    func empty() {
        #expect(normalizer.normalize("") == "")
        #expect(normalizer.normalize("🔥🔥🔥") == "")
    }
}

@Suite("Числа в косвенных падежах")
struct RussianNumeralsTests {

    private let normalizer = RussianNormalizer()

    @Test("Возраст сливается в одно слово")
    func age() {
        #expect(normalizer.normalize("34-летний мужчина") == "тридцатичетырёхлетний мужчина")
        #expect(normalizer.normalize("28-летняя женщина") == "двадцативосьмилетняя женщина")
        #expect(normalizer.normalize("41-летнему брату") == "сорокаоднолетнему брату")
        #expect(normalizer.normalize("90-летний дед") == "девяностолетний дед")
    }

    @Test("Год читается порядковым в предложном")
    func year() {
        #expect(normalizer.normalize("в 2020 году") == "в две тысячи двадцатом году")
        #expect(normalizer.normalize("в 1998 году") == "в тысяча девятьсот девяносто восьмом году")
        #expect(normalizer.normalize("в 2007 году") == "в две тысячи седьмом году")
        #expect(normalizer.normalize("в 2000 году") == "в двухтысячном году")
    }

    @Test("После «каждых» и «около» — родительный")
    func genitive() {
        #expect(normalizer.normalize("из каждых 100") == "из каждых ста")
        #expect(normalizer.normalize("около 30 человек") == "около тридцати человек")
        #expect(normalizer.normalize("более 21 доллара") == "более двадцати одного доллара")
    }

    @Test("Возраст приложением — в родительном")
    func apposition() {
        #expect(normalizer.normalize("женщина 28 лет") == "женщина двадцати восьми лет")
        #expect(normalizer.normalize("мой муж, 31 года") == "мой муж тридцати одного года")
        #expect(normalizer.normalize("мужчина 34 года") == "мужчина тридцати четырёх лет")
        #expect(normalizer.normalize("прошло 28 лет") == "прошло двадцать восемь лет")
    }

    @Test("Остальные числа остаются в именительном")
    func untouched() {
        #expect(normalizer.normalize("21 доллар") == "двадцать один доллар")
        #expect(normalizer.normalize("три года подряд") == "три года подряд")
    }
}
