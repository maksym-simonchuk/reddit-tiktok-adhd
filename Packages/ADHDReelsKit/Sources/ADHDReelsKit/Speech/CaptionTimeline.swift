import Foundation

/// Решает, откуда взять тайминги. Слова всегда берутся из сценария — мы его знаем
/// точно, поэтому в субтитрах не может появиться то, чего не было в тексте.
public enum CaptionTimeline {

    public static func words(for take: SpeechTake, script: Script) -> [WordTiming] {
        if let words = take.words, !words.isEmpty { return words }
        return distribute(script.plainText, over: take.duration)
    }

    /// Запасной путь для движков без таймингов: раскладываем слова по длительности
    /// пропорционально числу слогов. Гласные предсказывают длину слова заметно
    /// лучше, чем количество букв.
    static func distribute(_ text: String, over duration: Double) -> [WordTiming] {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty, duration > 0 else { return [] }

        let weights = words.map { Double(syllables(in: $0)) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return [] }

        var result: [WordTiming] = []
        var start = 0.0

        for (word, weight) in zip(words, weights) {
            let end = start + duration * weight / total
            result.append(WordTiming(text: word, start: start, end: end))
            start = end
        }

        return result
    }

    private static let vowels = Set("аеёиоуыэюяaeiouy")

    private static func syllables(in word: String) -> Int {
        max(1, word.lowercased().count { vowels.contains($0) })
    }
}
