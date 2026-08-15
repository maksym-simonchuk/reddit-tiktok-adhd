import Foundation

/// Схлопывает мусор, который остаётся после любой чистки: висящие пробелы перед
/// запятой, «!!!», двойные точки на месте вырезанных кусков.
enum TextTidy {

    static func tidy(_ text: String) -> String {
        var text = text
        for (pattern, replacement) in patterns {
            text = text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }
        let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n-,;:"))
        // От вырезанного куска может остаться одинокая точка — это не текст.
        return trimmed.contains(where: { $0.isLetter || $0.isNumber }) ? trimmed : ""
    }

    private static let patterns: [(String, String)] = [
        (#"\s+"#, " "),
        (#"\s+([.,!?;:])"#, "$1"),
        // Из «?!» и «...» оставляем первый знак — он и несёт интонацию.
        (#"([.,!?;:])[.,!?;:\s]*[.,!?;:]"#, "$1"),
        (#"\s+"#, " "),
    ]
}
