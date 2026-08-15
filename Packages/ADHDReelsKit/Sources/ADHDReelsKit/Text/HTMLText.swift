import Foundation

/// Превращает кусок HTML в чистый текст. Через `NSAttributedString` это делать нельзя:
/// он тянет WebKit и требует главный поток, а нам нужен разбор в фоне.
public enum HTMLText {

    public static func plain(_ html: String) -> String {
        collapse(entities(tags(html)))
    }

    /// Абзацы и переводы строк становятся пробелами — дальше текст всё равно
    /// склеивается в одну реплику для синтезатора.
    private static func tags(_ html: String) -> String {
        var result = ""
        var inside = false

        for character in html {
            switch character {
            case "<": inside = true
            case ">": inside = false; result.append(" ")
            default: if !inside { result.append(character) }
            }
        }

        return result
    }

    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "nbsp": " ", "hellip": "…", "mdash": "—", "ndash": "–", "rsquo": "’", "lsquo": "‘"
    ]

    private static func entities(_ text: String) -> String {
        guard text.contains("&") else { return text }

        var result = ""
        var scanner = text[...]

        while let start = scanner.firstIndex(of: "&") {
            result += scanner[..<start]
            scanner = scanner[scanner.index(after: start)...]

            guard let end = scanner.firstIndex(of: ";"),
                  scanner.distance(from: scanner.startIndex, to: end) <= 8 else {
                result.append("&")
                continue
            }

            let body = String(scanner[..<end])
            scanner = scanner[scanner.index(after: end)...]
            result += decode(body) ?? "&\(body);"
        }

        return result + scanner
    }

    private static func decode(_ body: String) -> String? {
        if let named = named[body] { return named }

        guard body.hasPrefix("#") else { return nil }
        let digits = body.dropFirst()
        let value = digits.hasPrefix("x") || digits.hasPrefix("X")
            ? UInt32(digits.dropFirst(), radix: 16)
            : UInt32(digits)

        return value.flatMap(UnicodeScalar.init).map(String.init)
    }

    private static func collapse(_ text: String) -> String {
        text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
