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

        text = spellNumbers(in: text)
        text = transliterateLatin(in: text)

        text = text.filter { character in
            character.isWhitespace
                || character.isNumber
                || Self.keptPunctuation.contains(character)
                || Self.isCyrillic(character)
        }

        return TextTidy.tidy(text)
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

            let word = source.substring(with: match.range)
            result += word.applyingTransform(StringTransform("Latin-Cyrillic"), reverse: false) ?? ""
        }

        return result + source.substring(from: cursor)
    }

    // MARK: - Таблицы

    private static let keptPunctuation: Set<Character> = [".", ",", "!", "?", ";", ":", "'", "\"", "-"]

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
