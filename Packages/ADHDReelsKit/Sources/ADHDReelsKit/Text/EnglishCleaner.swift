import Foundation

/// Приводит сырой markdown Reddit к тексту, который переводчик не испортит,
/// а синтезатор не прочитает как «звёздочка звёздочка эйч ти ти пи».
public enum EnglishCleaner {

    public static func clean(_ raw: String) -> String {
        var text = normalizeTypography(raw)

        for (pattern, replacement) in stripPatterns {
            text = text.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }

        // Регистрозависимо: иначе «So» превращается в «significant other».
        for (short, long) in expansions {
            let pattern = "(?<![A-Za-z])\(NSRegularExpression.escapedPattern(for: short))(?![A-Za-z])"
            text = text.replacingOccurrences(of: pattern, with: long, options: .regularExpression)
        }

        text = text.filter { character in
            character.isLetter
                || character.isNumber
                || character.isWhitespace
                || keptPunctuation.contains(character)
        }

        return TextTidy.tidy(text)
    }

    // MARK: - Шаги

    /// Типографику чиним до фильтра символов, иначе «don't» с U+2019 станет «dont».
    private static func normalizeTypography(_ text: String) -> String {
        var text = text
        for (from, to) in typographicReplacements {
            text = text.replacingOccurrences(of: from, with: to)
        }
        return text
    }

    private static let typographicReplacements: [(String, String)] = [
        ("\u{2018}", "'"), ("\u{2019}", "'"), ("\u{201A}", "'"), ("\u{2032}", "'"),
        ("\u{201C}", "\""), ("\u{201D}", "\""), ("\u{201E}", "\""), ("\u{00AB}", "\""), ("\u{00BB}", "\""),
        ("\u{2013}", "-"), ("\u{2014}", "-"), ("\u{2212}", "-"),
        ("\u{2026}", "."),
        ("\u{00A0}", " "),
    ]

    private static let keptPunctuation: Set<Character> = [".", ",", "!", "?", ";", ":", "'", "\"", "-"]

    private static let stripPatterns: [(String, String)] = [
        // Приписки автора после публикации к рассказу не относятся.
        (#"(?is)\n\s*\bedits?\s*\d*\s*:.*$"#, ""),
        // Цитаты чужих сообщений: с raw_json=1 приходит «>», без него «&gt;».
        (#"(?m)^\s*(?:&gt;|>).*$"#, ""),
        // [текст](ссылка) -> текст
        (#"\[([^\]]*)\]\([^)]*\)"#, "$1"),
        (#"https?://\S+"#, ""),
        (#"\bwww\.\S+"#, ""),
        // r/AskReddit и u/someone — слэш не должен цепляться внутри слова («sour/sweet»).
        (#"(?<![A-Za-z0-9])/?([ur])/([A-Za-z0-9_-]+)"#, "$2"),
        // Слэш всё равно не выживет в фильтре символов, но без пробела слова слипнутся.
        (#"/"#, " "),
        // Возраст и пол в скобках: «(28F)», «(32 M)».
        (#"\(\s*\d{1,2}\s*[MmFf]\s*\)"#, ""),
        (#"\(\s*[MmFf]\s*\d{1,2}\s*\)"#, ""),
        // Выделения, надстрочный текст, заголовки.
        (#"[*_`~^]"#, ""),
        (#"(?m)^#{1,6}\s*"#, ""),
        // Абзац читается как конец предложения, одиночный перенос — как пробел.
        (#"\n{2,}"#, ". "),
        (#"\n"#, " "),
    ]

    /// Аббревиатуры раскрываем по-английски: перевод дальше сделает из них нормальный русский.
    /// Порядок важен — длинные формы идут первыми, массив вместо словаря ради детерминизма.
    private static let expansions: [(String, String)] = [
        ("AITAH", "Am I the asshole"),
        ("AITA", "Am I the asshole"),
        ("TIFU", "Today I messed up"),
        ("TL;DR", "In short,"),
        ("TLDR", "In short,"),
        ("AFAIK", "as far as I know"),
        ("IIRC", "if I remember correctly"),
        ("FWIW", "for what it's worth"),
        ("IMHO", "in my honest opinion"),
        ("NTA", "not the asshole"),
        ("YTA", "you are the asshole"),
        ("ESH", "everyone sucks here"),
        ("NAH", "nobody is the asshole"),
        ("IMO", "in my opinion"),
        ("MIL", "mother in law"),
        ("FIL", "father in law"),
        ("OP", "the original poster"),
        ("BF", "boyfriend"),
        ("GF", "girlfriend"),
        ("SO", "significant other"),
    ]
}
