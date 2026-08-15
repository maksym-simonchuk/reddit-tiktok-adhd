import Foundation

/// Один произносимый кусок. `kind` управляет стилем субтитра: хук крупнее и висит дольше.
public struct ScriptSegment: Hashable, Sendable {

    public enum Kind: String, Codable, Hashable, Sendable, CaseIterable {
        case hook
        case body
        case comment
    }

    public let kind: Kind
    public let text: String

    public init(kind: Kind, text: String) {
        self.kind = kind
        self.text = text
    }
}

/// Готовый русский сценарий. Английский черновик до перевода живёт как `[ScriptSegment]`.
public struct Script: Hashable, Sendable {

    /// Замерено в Фазе 2 на реальном синтезе: русская речь идёт медленнее английской.
    /// Замер: 120 слов русского текста системным голосом на скорости по умолчанию — 2.35 сл/с.
    public static let wordsPerSecond = 2.35

    public let segments: [ScriptSegment]

    public init(segments: [ScriptSegment]) {
        self.segments = segments
    }

    public var plainText: String {
        segments.map(\.text).joined(separator: " ")
    }

    public var wordCount: Int {
        plainText.split(whereSeparator: \.isWhitespace).count
    }

    /// Оценка до синтеза — нужна, чтобы обрезать сценарий под целевую длительность.
    public var estimatedDuration: Double {
        Double(wordCount) / Self.wordsPerSecond
    }
}
