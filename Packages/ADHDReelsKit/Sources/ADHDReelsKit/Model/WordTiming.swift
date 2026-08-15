import Foundation

/// Слово и когда оно звучит. Основа караоке-субтитров.
public struct WordTiming: Codable, Hashable, Sendable {

    public let text: String
    public let start: Double
    public let end: Double

    public init(text: String, start: Double, end: Double) {
        self.text = text
        self.start = start
        self.end = end
    }

    public var duration: Double { end - start }
}

/// Слова, которые показываются на экране вместе.
public struct CaptionGroup: Hashable, Sendable {

    public let words: [WordTiming]

    public init(words: [WordTiming]) {
        self.words = words
    }

    public var start: Double { words.first?.start ?? 0 }
    public var end: Double { words.last?.end ?? 0 }
    public var text: String { words.map(\.text).joined(separator: " ") }
}
