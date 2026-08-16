import Foundation

/// Правила «буквы → фонемы» из vosk-tts (`g2p.py`). Запасной путь для слов, которых
/// нет в `StressDictionary`: ударение здесь не ставится вовсе (все гласные с нулём),
/// зато читается хоть что-то — незнакомое слово иначе выпало бы из фразы целиком.
enum RussianG2P {

    /// Гласная после них берёт йот: «съел» → `s j e0 l`. «#» — край слова.
    private static let syllableStarts: Set<String> = ["#", "ъ", "ь", "а", "я", "о", "ё", "у", "ю", "э", "е", "и", "ы", "-"]
    private static let softening: Set<String> = ["я", "ё", "ю", "и", "ь", "е"]
    private static let iotated: Set<String> = ["я", "ю", "е", "ё"]
    /// Служебные знаки: до фонем не доживают.
    private static let dropped: Set<String> = ["#", "+", "-", "ь", "ъ"]

    private static let pairedConsonants: [String: String] = [
        "б": "b", "в": "v", "г": "g", "Г": "g", "д": "d", "з": "z", "к": "k", "л": "l",
        "м": "m", "н": "n", "п": "p", "р": "r", "с": "s", "т": "t", "ф": "f", "х": "h",
    ]

    private static let unpairedConsonants: [String: String] = [
        "ж": "zh", "ц": "c", "ч": "ch", "ш": "sh", "щ": "sch", "й": "j",
    ]

    private static let vowels: [String: String] = [
        "а": "a", "я": "a", "у": "u", "ю": "u", "о": "o", "ё": "o",
        "э": "e", "е": "e", "и": "i", "ы": "y",
    ]

    static func phonemes(of word: String) -> [String] {
        // Границы слова — часть правил: по «#» узнаётся начало слога.
        var letters: [(text: String, stressed: Bool)] = [("#", false)]
        var stressed = false

        for character in word {
            // Формат словаря с ударениями: плюс стоит перед ударной гласной.
            if character == "+" {
                stressed = true
            } else {
                letters.append((String(character), stressed))
                stressed = false
            }
        }
        letters.append(("#", false))

        return withoutService(vocalized(palatalized(letters)))
    }

    /// Парная согласная перед мягкой гласной становится мягкой, непарная — просто латиницей.
    /// Последнюю букву не трогаем: там всегда «#».
    private static func palatalized(_ letters: [(text: String, stressed: Bool)]) -> [(text: String, stressed: Bool)] {
        var letters = letters

        for index in letters.indices.dropLast() {
            let letter = letters[index].text
            if let consonant = pairedConsonants[letter] {
                letters[index] = (softening.contains(letters[index + 1].text) ? consonant + "j" : consonant, false)
            }
            if let consonant = unpairedConsonants[letter] {
                letters[index] = (consonant, false)
            }
        }

        return letters
    }

    /// Гласная получает номер ударения, а в начале слога перед «я/ю/е/ё» вырастает йот.
    private static func vocalized(_ letters: [(text: String, stressed: Bool)]) -> [String] {
        var phonemes: [String] = []
        var previous = ""

        for letter in letters {
            if syllableStarts.contains(previous), iotated.contains(letter.text) {
                phonemes.append("j")
            }
            phonemes.append(vowels[letter.text].map { $0 + (letter.stressed ? "1" : "0") } ?? letter.text)
            previous = letter.text
        }

        return phonemes
    }

    private static func withoutService(_ phonemes: [String]) -> [String] {
        phonemes.filter { !dropped.contains($0) }
    }
}
