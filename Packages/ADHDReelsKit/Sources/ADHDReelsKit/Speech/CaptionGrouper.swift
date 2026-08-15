import Foundation

/// Сколько слов держать на экране разом и когда рвать строку.
public struct CaptionStyle: Hashable, Sendable {

    /// Больше трёх слов на экране в вертикальном ролике уже не успевают прочитать.
    public var maxWords = 3
    public var maxCharacters = 24
    /// Пауза длиннее — это смена мысли, группу закрываем.
    public var pause = 0.35

    public init() {}
}

public enum CaptionGrouper {

    public static func groups(from words: [WordTiming], style: CaptionStyle = CaptionStyle()) -> [CaptionGroup] {
        var groups: [CaptionGroup] = []
        var current: [WordTiming] = []

        for word in words {
            if let last = current.last, shouldBreak(after: last, before: word, current: current, style: style) {
                groups.append(CaptionGroup(words: current))
                current = []
            }
            current.append(word)
        }

        if !current.isEmpty {
            groups.append(CaptionGroup(words: current))
        }

        return groups
    }

    private static func shouldBreak(
        after last: WordTiming,
        before next: WordTiming,
        current: [WordTiming],
        style: CaptionStyle
    ) -> Bool {
        if current.count >= style.maxWords { return true }
        if next.start - last.end >= style.pause { return true }

        let length = current.reduce(0) { $0 + $1.text.count + 1 } - 1
        return length + 1 + next.text.count > style.maxCharacters
    }
}
