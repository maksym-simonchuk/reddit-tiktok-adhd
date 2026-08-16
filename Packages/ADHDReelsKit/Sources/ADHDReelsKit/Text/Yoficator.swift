import Foundation

/// Возвращает в текст букву «ё». Перевод её не ставит, а синтезатору она нужна дважды:
/// без неё слово не находится в словаре ударений («ёжик» и «ежик» — разные ключи),
/// и сама гласная читается как /e/. В русском «ё» всегда ударная, так что одна
/// замена чинит и гласную, и ударение.
///
/// Словарь только однозначных форм. «Всё» и «все» без «ё» пишутся одинаково, и такие
/// пары в него не входят: угадать неверно хуже, чем не трогать.
struct Yoficator: Sendable {

    static let shared = Yoficator()

    /// Ключ — форма без «ё», значение — она же с «ё».
    private let forms: [String: String]

    init(forms: [String: String]) {
        self.forms = forms
    }

    private init() {
        guard
            let url = Bundle.main.resourceURL?.appending(path: "Models/yo.txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            forms = [:]
            return
        }

        var forms: [String: String] = [:]
        forms.reserveCapacity(110_000)
        for word in text.split(separator: "\n") {
            forms[word.replacingOccurrences(of: "ё", with: "е")] = String(word)
        }
        self.forms = forms
    }

    func apply(to text: String) -> String {
        guard !forms.isEmpty, let regex = try? NSRegularExpression(pattern: "[а-яА-ЯёЁ]+") else { return text }

        let source = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else { return text }

        var result = ""
        var cursor = 0

        for match in matches {
            result += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            cursor = match.range.location + match.range.length

            let word = source.substring(with: match.range)
            result += yoficated(word) ?? word
        }

        return result + source.substring(from: cursor)
    }

    /// В начале предложения слово приходит с заглавной, а словарь держит нарицательные
    /// строчными: ищем как есть, потом в нижнем регистре и возвращаем заглавную.
    private func yoficated(_ word: String) -> String? {
        if let exact = forms[word] { return exact }

        guard let lower = forms[word.lowercased()] else { return nil }
        guard word.first?.isUppercase == true else { return lower }

        return lower.prefix(1).uppercased() + lower.dropFirst()
    }
}
