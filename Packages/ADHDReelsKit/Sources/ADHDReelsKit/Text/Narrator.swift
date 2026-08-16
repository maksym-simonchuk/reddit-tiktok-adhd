import Foundation

/// Пол рассказчика. В английском его в тексте не слышно — «I paid», «I was tired»
/// одинаковы для всех, — а в русском он есть в каждом глаголе прошедшего времени.
/// Модель без подсказки выбирает род наугад и меняет его посреди рассказа: «я сказал»
/// в одном предложении и «я поняла» в следующем.
enum Narrator {

    enum Gender: String {
        case male
        case female

        /// Дописывается к инструкции перевода отдельным правилом: коротким и с примером,
        /// иначе модель принимает его за часть истории.
        var rule: String {
            switch self {
            case .male:
                "- рассказ ведётся от лица мужчины: о себе пиши в мужском роде — «я сказал», «я был прав»."
            case .female:
                "- рассказ ведётся от лица женщины: о себе пиши в женском роде — «я сказала», «я была права»."
            }
        }
    }

    /// Ищем только явное «я, тридцати двух лет, мужчина»: `EnglishCleaner` разворачивает
    /// в такой оборот пометки «32M» и «(28F)». Догадываться по «моей жене» нельзя —
    /// у женщины тоже бывает жена, и ошибка тут хуже незнания.
    private static let patterns: [(String, Gender)] = [
        (#"\b(?:I|Me)\s*,\s*an?\s+\d{2}-year-old\s+man\b"#, .male),
        (#"\b(?:I|Me)\s*,\s*an?\s+\d{2}-year-old\s+woman\b"#, .female),
        (#"\bI(?:'m| am)\s+an?\s+\d{2}[ -]?(?:year[ -]old\s+)?(?:man|male)\b"#, .male),
        (#"\bI(?:'m| am)\s+an?\s+\d{2}[ -]?(?:year[ -]old\s+)?(?:woman|female)\b"#, .female),
    ]

    static func gender(of text: String) -> Gender? {
        for (pattern, gender) in patterns
        where text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
            return gender
        }

        return nil
    }
}
