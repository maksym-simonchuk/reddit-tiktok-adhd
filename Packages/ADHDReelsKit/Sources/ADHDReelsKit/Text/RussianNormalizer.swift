import Foundation

/// Готовит русский текст к синтезу: цифры прописью, проценты словом, сокращения
/// развёрнуты, латиница транслитерирована. На выходе — только те символы,
/// которые синтезатор точно произнесёт.
public struct RussianNormalizer: Sendable {

    public init() {}

    public func normalize(_ raw: String) -> String {
        var text = raw

        for (pattern, replacement) in abbreviations {
            text = text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }

        text = spellIdioms(in: text)
        text = spellNumbers(in: text)
        text = transliterateLatin(in: text)
        text = Yoficator.shared.apply(to: text)

        text = text.filter { character in
            character.isWhitespace
                || character.isNumber
                || Self.keptPunctuation.contains(character)
                || Self.isCyrillic(character)
        }

        return TextTidy.tidy(text)
    }

    // MARK: - Числа в косвенных падежах

    /// Обороты, где именительный падеж слышен как ошибка: «в две тысячи двадцать году»,
    /// «тридцать четыре-летний», «из каждых сто». Перевод приносит их цифрами, потому
    /// что словами модель их путает, — а падеж здесь считается по таблице.
    private func spellIdioms(in text: String) -> String {
        var text = text

        // «34-летний» — одно слово: «тридцатичетырёхлетний».
        text = rewrite(#"(\d+)-(лет\p{L}*)"#, in: text) { groups in
            Int(groups[0]).flatMap(RussianNumerals.compound).map { $0 + groups[1] }
        }

        // «в 2020 году» и «в 2020-м году» — порядковое в предложном.
        text = rewrite(#"(?i)\bв\s+(\d{3,4})(?:-м)?\s+году\b"#, in: text) { groups in
            Int(groups[0]).flatMap(RussianNumerals.yearPrepositional).map { "в \($0) году" }
        }

        // «женщина 28 лет» — приложение к человеку, а не «прошло 28 лет». Различить их
        // без разбора падежей нельзя, поэтому по списку тех, кому в треде бывает столько-то
        // лет: модель ставит возраст этим оборотом, сколько её ни проси писать «28-летняя».
        // Единицу берём из числа, а не из текста: в родительном «года» остаётся только
        // у тех, что оканчиваются на один, — «мужчина тридцати четырёх лет».
        text = rewrite(#"\b(\#(Self.people))\s*,?\s+(\d+)\s+(?:лет|года)\b"#, in: text) { groups in
            guard let value = Int(groups[1]), let spelled = RussianNumerals.genitive(value) else { return nil }
            let unit = value % 10 == 1 && value % 100 != 11 ? "года" : "лет"
            return "\(groups[0]) \(spelled) \(unit)"
        }

        // Слова, после которых число всегда в родительном.
        text = rewrite(#"(?i)\b(около|более|менее|свыше|больше|меньше|каждых|каждого)\s+(\d+)\b"#, in: text) { groups in
            Int(groups[1]).flatMap(RussianNumerals.genitive).map { "\(groups[0]) \($0)" }
        }

        return text
    }

    /// Замена по регулярному выражению с доступом к группам. Не нашлось формы —
    /// возвращаем `nil`, и кусок остаётся цифрами: их разберёт общий проход.
    private func rewrite(_ pattern: String, in text: String, _ build: ([String]) -> String?) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }

        let source = text as NSString
        var result = ""
        var cursor = 0

        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            let groups = (1..<match.numberOfRanges).map { index in
                match.range(at: index).location == NSNotFound
                    ? ""
                    : source.substring(with: match.range(at: index))
            }
            guard let replacement = build(groups) else { continue }

            result += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            result += replacement
            cursor = match.range.location + match.range.length
        }

        return result + source.substring(from: cursor)
    }

    // MARK: - Числа и проценты

    /// Один проход: цифры превращаем в слова, а прилипший «%» — в «процент»
    /// в нужной форме. Формы важны: «два процента», но «пять процентов».
    private func spellNumbers(in text: String) -> String {
        // Пробел перед «%» съедаем только вместе с самим знаком, иначе «5 яблок»
        // склеится в «пятьяблок».
        guard let regex = try? NSRegularExpression(pattern: #"(\d+)(?:[.,](\d+))?(?:\s*(%))?"#) else { return text }

        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = Locale(identifier: "ru_RU")

        let source = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else { return text }

        var result = ""
        var cursor = 0

        for match in matches {
            result += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            cursor = match.range.location + match.range.length

            let whole = source.substring(with: match.range(at: 1))
            let fraction = match.range(at: 2).location == NSNotFound
                ? nil
                : source.substring(with: match.range(at: 2))
            let hasPercent = match.range(at: 3).location != NSNotFound

            let literal = fraction.map { "\(whole).\($0)" } ?? whole
            guard let value = Double(literal),
                  let spelled = formatter.string(from: NSNumber(value: value))
            else {
                result += source.substring(with: match.range)
                continue
            }

            result += spelled
            if hasPercent {
                result += " " + Self.percentWord(whole: whole, isFractional: fraction != nil)
            }
        }

        return result + source.substring(from: cursor)
    }

    private static func percentWord(whole: String, isFractional: Bool) -> String {
        guard !isFractional, let value = Int(whole) else { return "процента" }
        if (11...14).contains(value % 100) { return "процентов" }
        switch value % 10 {
        case 1: return "процент"
        case 2...4: return "процента"
        default: return "процентов"
        }
    }

    // MARK: - Латиница

    /// Перевод оставляет бренды и ники латиницей. Выбрасывать их нельзя — в субтитрах
    /// появится дыра, и слова разъедутся со звуком, поэтому транслитерируем.
    private func transliterateLatin(in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"[A-Za-z]+"#) else { return text }

        let source = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else { return text }

        var result = ""
        var cursor = 0

        for match in matches {
            result += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            cursor = match.range.location + match.range.length

            result += Self.transcribe(source.substring(with: match.range))
        }

        return result + source.substring(from: cursor)
    }

    /// Побуквенно английское слово не читается: ICU даёт «Гоогле», «Дисцорд» и «Йохн»,
    /// и синтезатор это произносит. Таблица покрывает буквосочетания, из-за которых
    /// слово перестаёт быть узнаваемым; остальное идёт буква в букву.
    static func transcribe(_ word: String) -> String {
        var source = word.lowercased()

        // Немая «e» на конце: Google → гугл, iPhone → ифон.
        if source.count > 2, source.hasSuffix("e"), let previous = source.dropLast().last,
           !"aeiouy".contains(previous) {
            source.removeLast()
        }

        var result = ""
        var index = source.startIndex

        while index < source.endIndex {
            if let pair = groups.first(where: { source[index...].hasPrefix($0.0) }) {
                result += pair.1
                index = source.index(index, offsetBy: pair.0.count)
                continue
            }

            result += letters[source[index]] ?? ""
            index = source.index(after: index)
        }

        guard word.first?.isUppercase == true else { return result }
        return result.prefix(1).uppercased() + result.dropFirst()
    }

    // MARK: - Таблицы

    /// Те, чей возраст называют в треде. Список закрытый: расширять его стоит только
    /// тогда, когда в переводе действительно встретилось «кто-то 30 лет».
    private static let people = [
        "мужчина", "женщина", "парень", "девушка", "муж", "жена", "брат", "сестра",
        "сын", "дочь", "мать", "мама", "отец", "папа", "друг", "подруга",
        "сосед", "соседка", "коллега", "начальник", "бабушка", "дедушка",
    ].joined(separator: "|")

    /// Сначала сочетания, потом буквы: «ch» — это «ч», а не «цх».
    private static let groups: [(String, String)] = [
        ("tch", "ч"), ("sch", "ш"), ("you", "ю"), ("sh", "ш"), ("ch", "ч"), ("ph", "ф"),
        ("th", "т"), ("ck", "к"), ("gh", "г"), ("qu", "кв"), ("wh", "в"), ("oh", "о"),
        ("ee", "и"), ("ea", "и"), ("oo", "у"), ("ou", "ау"), ("oa", "о"),
        ("ai", "эй"), ("ay", "эй"), ("ey", "ей"), ("ie", "и"),
        ("ce", "се"), ("ci", "си"), ("cy", "си"),
    ]

    private static let letters: [Character: String] = [
        "a": "а", "b": "б", "c": "к", "d": "д", "e": "е", "f": "ф", "g": "г", "h": "х",
        "i": "и", "j": "дж", "k": "к", "l": "л", "m": "м", "n": "н", "o": "о", "p": "п",
        "q": "к", "r": "р", "s": "с", "t": "т", "u": "у", "v": "в", "w": "в", "x": "кс",
        "y": "и", "z": "з",
    ]

    /// Тире — не украшение: модель ведёт по нему отдельный поток пунктуации, и «Он — мой
    /// отец» звучит с паузой там, где её делает человек. Выбросишь — фраза читается ровной
    /// строкой. В русском переводе тире стоит на каждом втором предложении.
    private static let keptPunctuation: Set<Character> = [".", ",", "!", "?", ";", ":", "'", "\"", "-", "—", "–"]

    private static func isCyrillic(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { (0x0400...0x04FF).contains($0.value) }
    }

    /// Раскрываем до подстановки чисел: внутри сокращений есть точки,
    /// которые иначе схлопнет `TextTidy`.
    private let abbreviations: [(String, String)] = [
        (#"(?i)\bи\s*т\.\s*д\."#, "и так далее"),
        (#"(?i)\bи\s*т\.\s*п\."#, "и тому подобное"),
        (#"(?i)\bи\s*др\."#, "и другие"),
        (#"(?i)\bт\.\s*к\."#, "так как"),
        (#"(?i)\bт\.\s*е\."#, "то есть"),
        (#"(?i)\bт\.\s*н\."#, "так называемый"),
        (#"(?i)\bруб\."#, "рублей"),
        (#"(?i)\bтыс\."#, "тысяч"),
        (#"\bн\.\s*э\."#, "нашей эры"),
    ]
}
